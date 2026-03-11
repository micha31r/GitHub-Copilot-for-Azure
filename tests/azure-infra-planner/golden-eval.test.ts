/**
 * Golden Eval Integration Test for azure-infra-planner + plan-eval
 *
 * Runs the first 3 golden prompts through a two-phase pipeline:
 *  1. azure-infra-planner → generates infrastructure-plan.json
 *  2. plan-eval (new Copilot session) → evaluates the plan → plan-evaluation.json
 *
 * Artifacts are stored at <repo-root>/artifacts/<row-number>/<model-slug>/.
 *
 * Prerequisites:
 * 1. npm install -g @github/copilot-cli
 * 2. Run `copilot` and authenticate
 */

import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import {
  useAgentRunner,
  shouldSkipIntegrationTests,
  getIntegrationSkipReason
} from "../utils/agent-runner";
import { softCheckSkill, getAllAssistantMessages } from "../utils/evaluate";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const SKILL_NAME = "azure-infra-planner";
const GOLDEN_DATASET_PATH = path.join(__dirname, "evals", "golden_dataset.txt");
const REPO_ROOT = path.resolve(__dirname, "../..");
const ARTIFACTS_DIR = path.join(REPO_ROOT, process.env.EVAL_ARTIFACT_DIR || "artifacts");
const PLAN_EVAL_SKILL_DIR = path.join(REPO_ROOT, ".github", "skills", "plan-eval");
const FOLLOW_UP_PROMPT = ["Go with recommended options. Assume all defaults to make the plan."];
const GOLDEN_PROMPT_COUNT = 3;

/** Models to evaluate. Override with EVAL_MODELS env var (comma-separated). */
const EVAL_MODELS: string[] = process.env.EVAL_MODELS
  ? process.env.EVAL_MODELS.split(",").map((m) => m.trim()).filter(Boolean)
  : ["claude-opus-4.6"];

/** Model used for plan-eval (Phase 2). Fixed for consistent scoring across runs. */
const EVAL_JUDGE_MODEL = "claude-opus-4.6";

interface GoldenEvalResult {
  rowId: number;
  prompt: string;
  model: string;
  hasPlan: boolean;
  hasEval: boolean;
  overallScore: number | null;
  planPath: string | null;
  evalPath: string | null;
}

const skipTests = shouldSkipIntegrationTests();
const skipReason = getIntegrationSkipReason();

if (skipTests && skipReason) {
  console.log(`⏭️  Skipping golden eval tests: ${skipReason}`);
}

const wafExcluded = (process.env.EXCLUDED_TOOLS || "").includes("azure-wellarchitectedframework");
console.log(`\n🔧 WAF tool: ${wafExcluded ? "❌ EXCLUDED (Phase 1 only)" : "✅ ENABLED"}`);
console.log(`📂 Artifacts: ${process.env.EVAL_ARTIFACT_DIR || "artifacts"}\n`);

const describeIntegration = skipTests ? describe.skip : describe;

describeIntegration(`${SKILL_NAME} - Golden Eval`, () => {
  const agent = useAgentRunner();
  const goldenPrompts = loadGoldenPrompts(GOLDEN_PROMPT_COUNT);

  /**
   * End-to-end evaluation of a single golden prompt:
   * Phase 1 → infra-planner generates a plan
   * Phase 2 → plan-eval scores the plan in a fresh session
   */
  async function evaluateGoldenPrompt(
    rowId: number,
    prompt: string,
    model: string
  ): Promise<GoldenEvalResult> {
    const result: GoldenEvalResult = {
      rowId,
      prompt,
      model,
      hasPlan: false,
      hasEval: false,
      overallScore: null,
      planPath: null,
      evalPath: null
    };

    const artifactDir = path.join(ARTIFACTS_DIR, String(rowId), modelSlug(model));
    fs.mkdirSync(artifactDir, { recursive: true });

    console.log(`\n🚀 [Prompt ${rowId}] [${model}] Starting: ${prompt.substring(0, 80)}...`);

    // Phase 1: azure-infra-planner
    let plannerWorkspace: string | undefined;
    let planContent: string | undefined;

    try {
      const plannerMetadata = await agent.run({
        prompt: `Plan Azure infrastructure: ${prompt} Assume all defaults to make the plan.`,
        nonInteractive: true,
        model,
        followUp: FOLLOW_UP_PROMPT,
        preserveWorkspace: true,
        includeSkills: [SKILL_NAME],
        shouldEarlyTerminate: () => {
          if (!plannerWorkspace) return false;
          return fs.existsSync(path.join(plannerWorkspace, ".azure", "infrastructure-plan.json"));
        },
        setup: async (workspace: string) => {
          plannerWorkspace = workspace;
        }
      });

      softCheckSkill(plannerMetadata, SKILL_NAME);

      if (plannerWorkspace) {
        const planPath = path.join(plannerWorkspace, ".azure", "infrastructure-plan.json");
        if (fs.existsSync(planPath)) {
          planContent = fs.readFileSync(planPath, "utf-8");
          JSON.parse(planContent); // validate JSON
          result.hasPlan = true;

          const artifactPlanPath = path.join(artifactDir, "infrastructure-plan.json");
          fs.copyFileSync(planPath, artifactPlanPath);
          result.planPath = artifactPlanPath;
          console.log(`✅ [Prompt ${rowId}] [${model}] Plan generated → ${artifactPlanPath}`);
        } else {
          console.warn(`⚠️  [Prompt ${rowId}] [${model}] infrastructure-plan.json not found in workspace`);
        }
      }
    } catch (e: unknown) {
      if (
        e instanceof Error &&
        (e.message?.includes("Failed to load @github/copilot-sdk") ||
          e.message?.includes("CLI server exited"))
      ) {
        console.log(`⏭️  [Prompt ${rowId}] [${model}] SDK/CLI not available, skipping`);
        return result;
      }
      console.error(`❌ [Prompt ${rowId}] [${model}] Planner phase failed:`, e);
      return result;
    }

    if (!planContent) {
      console.warn(`⚠️  [Prompt ${rowId}] [${model}] No plan generated, skipping evaluation phase`);
      return result;
    }

    // Phase 2: plan-eval in a new Copilot session
    let evalWorkspace: string | undefined;

    try {
      const evalMetadata = await agent.run({
        prompt:
          "Evaluate the infrastructure plan at .azure/infrastructure-plan.json using the plan-eval skill. " +
          "Write the complete evaluation result JSON to .azure/plan-evaluation.json. " +
          "The JSON must include: overallScore, dimensions (goalAlignment, wafConformance, " +
          "dependencyCompleteness, deploymentViability), risks, correctionsRecommended, " +
          "hardDependencies, and deployable.",
        nonInteractive: true,
        model: EVAL_JUDGE_MODEL,
        excludedTools: [], // plan-eval always needs full tool access (esp. WAF tool)
        preserveWorkspace: true,
        setup: async (workspace: string) => {
          evalWorkspace = workspace;

          // Seed the plan into the new workspace
          fs.mkdirSync(path.join(workspace, ".azure"), { recursive: true });
          fs.writeFileSync(
            path.join(workspace, ".azure", "infrastructure-plan.json"),
            planContent!
          );

          // Copy plan-eval skill so the Copilot CLI discovers it
          if (fs.existsSync(PLAN_EVAL_SKILL_DIR)) {
            copyDirSync(
              PLAN_EVAL_SKILL_DIR,
              path.join(workspace, ".github", "skills", "plan-eval")
            );
          }
        }
      });

      // Try reading evaluation from workspace file first
      if (evalWorkspace) {
        const evalPath = path.join(evalWorkspace, ".azure", "plan-evaluation.json");
        if (fs.existsSync(evalPath)) {
          const evaluation = JSON.parse(fs.readFileSync(evalPath, "utf-8"));
          result.hasEval = true;
          result.overallScore = evaluation.overallScore ?? null;

          const artifactEvalPath = path.join(artifactDir, "plan-evaluation.json");
          fs.writeFileSync(artifactEvalPath, JSON.stringify(evaluation, null, 2));
          result.evalPath = artifactEvalPath;
        }
      }

      // Fallback: extract evaluation JSON from assistant messages
      if (!result.hasEval) {
        const messages = getAllAssistantMessages(evalMetadata);
        const evaluation = extractEvalJson(messages);
        if (evaluation && typeof evaluation.overallScore === "number") {
          result.hasEval = true;
          result.overallScore = evaluation.overallScore;

          const artifactEvalPath = path.join(artifactDir, "plan-evaluation.json");
          fs.writeFileSync(artifactEvalPath, JSON.stringify(evaluation, null, 2));
          result.evalPath = artifactEvalPath;
          console.log(`✅ [Prompt ${rowId}] [${model}] Evaluation extracted from assistant messages`);
        } else {
          console.warn(`⚠️  [Prompt ${rowId}] [${model}] plan-evaluation.json not found in workspace or messages`);
        }
      }

      if (result.hasEval) {
        console.log(`✅ [Prompt ${rowId}] [${model}] Evaluation complete: score=${result.overallScore} → ${result.evalPath}`);
        if (result.evalPath) {
          const dims = JSON.parse(fs.readFileSync(result.evalPath, "utf-8")).dimensions;
          if (dims) {
            console.log(
              `   📐 goal=${dims.goalAlignment ?? "?"} waf=${dims.wafConformance ?? "?"} ` +
              `deps=${dims.dependencyCompleteness ?? "?"} deploy=${dims.deploymentViability ?? "?"}`
            );
          }
        }
      }
    } catch (e: unknown) {
      if (
        e instanceof Error &&
        (e.message?.includes("Failed to load @github/copilot-sdk") ||
          e.message?.includes("CLI server exited"))
      ) {
        console.log(`⏭️  [Prompt ${rowId}] [${model}] SDK/CLI not available for eval phase`);
        return result;
      }
      console.error(`❌ [Prompt ${rowId}] [${model}] Eval phase failed:`, e);
    }

    return result;
  }

  // Run all golden prompts in parallel, per model
  describe.each(EVAL_MODELS)("model: %s", (model) => {
    test("evaluates golden prompts through planner + plan-eval pipeline", async () => {
      const results = await Promise.all(
        goldenPrompts.map(({ rowId, prompt }) =>
          evaluateGoldenPrompt(rowId, prompt, model)
        )
      );

      // Summary
      console.log(`\n📊 Golden Eval Summary [${model}]:`);
      console.log("─".repeat(80));
      for (const r of results) {
        const score = r.overallScore !== null ? r.overallScore.toFixed(2) : "N/A";
        const icon =
          r.overallScore !== null && r.overallScore >= 0.7
            ? "✅"
            : r.overallScore !== null
              ? "⚠️"
              : "❌";
        console.log(
          `${icon} Prompt ${r.rowId}: score=${score} | ` +
          `plan=${r.hasPlan ? "✅" : "❌"} eval=${r.hasEval ? "✅" : "❌"} | ` +
          `${r.prompt.substring(0, 60)}...`
        );
      }
      console.log("─".repeat(80));

      // Soft checks — warn but don't fail
      const lowScores = results.filter(
        (r) => r.overallScore !== null && r.overallScore < 0.7
      );
      if (lowScores.length > 0) {
        console.warn(
          `⚠️  ${lowScores.length}/${results.length} prompt(s) scored below 0.7 pass threshold`
        );
      }

      const missingPlans = results.filter((r) => !r.hasPlan);
      if (missingPlans.length > 0) {
        console.warn(
          `⚠️  ${missingPlans.length}/${results.length} prompt(s) did not produce an infrastructure plan`
        );
      }

      const missingEvals = results.filter((r) => !r.hasEval);
      if (missingEvals.length > 0) {
        console.warn(
          `⚠️  ${missingEvals.length}/${results.length} prompt(s) did not produce a plan evaluation`
        );
      }
    }, 30 * 60 * 1000); // 30 minutes per model
  });
});

// Helpers

/** Parse the golden dataset TSV and return the first N data rows. */
function loadGoldenPrompts(count: number): { rowId: number; prompt: string }[] {
  const content = fs.readFileSync(GOLDEN_DATASET_PATH, "utf-8");
  const lines = content.split("\n").filter((line) => line.trim());
  // Row 0 is the header ("prompt\tcompleted"); data starts at row 1
  return lines.slice(1, 1 + count).map((line, index) => ({
    rowId: index + 1,
    prompt: line.split("\t")[0].trim()
  }));
}

/** Convert model name to filesystem-safe slug. */
function modelSlug(model: string): string {
  return model.replace(/[^a-zA-Z0-9-]/g, "-").replace(/-+/g, "-");
}

/** Recursively copy a directory tree. */
function copyDirSync(src: string, dest: string): void {
  fs.mkdirSync(dest, { recursive: true });
  for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDirSync(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

/** Try to extract a JSON object containing "overallScore" from free-text. */
function extractEvalJson(text: string): Record<string, unknown> | null {
  const match = text.match(/\{[\s\S]*?"overallScore"[\s\S]*?\}(?=\s|$)/);
  if (!match) return null;
  try {
    return JSON.parse(match[0]);
  } catch {
    // The naive regex may grab too little; try the largest balanced braces
    let depth = 0;
    let start = text.indexOf("{");
    while (start !== -1) {
      for (let i = start; i < text.length; i++) {
        if (text[i] === "{") depth++;
        if (text[i] === "}") depth--;
        if (depth === 0) {
          const candidate = text.substring(start, i + 1);
          if (candidate.includes("overallScore")) {
            try {
              return JSON.parse(candidate);
            } catch { /* try next */ }
          }
          break;
        }
      }
      start = text.indexOf("{", start + 1);
      depth = 0;
    }
  }
  return null;
}
