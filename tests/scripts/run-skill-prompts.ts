/**
 * Standalone script to run multiple prompts against a skill via the Copilot SDK.
 *
 * Usage:
 *   npx tsx scripts/run-skill-prompts.ts                          # Run all prompts against default skill
 *   npx tsx scripts/run-skill-prompts.ts --skill azure-workload-planner
 *   npx tsx scripts/run-skill-prompts.ts --prompt "Plan infra for a chat app"
 *   npx tsx scripts/run-skill-prompts.ts --file prompts.txt       # One prompt per line
 *   npx tsx scripts/run-skill-prompts.ts --yolo                   # Auto-approve tool calls
 *
 * Prerequisites:
 *   - @github/copilot-sdk installed (npm install in tests/)
 *   - Copilot CLI authenticated (run `copilot` once to log in)
 */

import * as fs from "fs";
import * as path from "path";
import { fileURLToPath } from "url";
import {
  useAgentRunner,
  isSkillInvoked,
  getAllAssistantMessages,
  getToolCalls,
  type AgentMetadata,
  type AgentRunConfig,
} from "../utils/agent-runner.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ── CLI argument parsing ────────────────────────────────────────────────────

interface CliArgs {
  skill: string;
  prompts: string[];
  yolo: boolean;
  verbose: boolean;
  outputDir: string | null;
}

function parseArgs(): CliArgs {
  const args = process.argv.slice(2);
  const parsed: CliArgs = {
    skill: "azure-workload-planner",
    prompts: [],
    yolo: false,
    verbose: false,
    outputDir: null,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--skill":
      case "-s":
        parsed.skill = args[++i];
        break;
      case "--prompt":
      case "-p":
        parsed.prompts.push(args[++i]);
        break;
      case "--file":
      case "-f": {
        const filePath = path.resolve(args[++i]);
        const lines = fs.readFileSync(filePath, "utf-8")
          .split("\n")
          .map(l => l.trim())
          .filter(l => l.length > 0 && !l.startsWith("#"));
        parsed.prompts.push(...lines);
        break;
      }
      case "--yolo":
        parsed.yolo = true;
        break;
      case "--verbose":
      case "-v":
        parsed.verbose = true;
        break;
      case "--output":
      case "-o":
        parsed.outputDir = args[++i];
        break;
      case "--help":
      case "-h":
        printUsage();
        process.exit(0);
      default:
        // Treat bare argument as a prompt
        if (!args[i].startsWith("-")) {
          parsed.prompts.push(args[i]);
        }
    }
  }

  // Default prompts if none provided
  if (parsed.prompts.length === 0) {
    parsed.prompts = [
      "Plan infrastructure for a real-time IoT analytics dashboard",
      "What Azure resources do I need for a serverless e-commerce backend?",
      "Create an infrastructure plan for a multi-tenant SaaS application",
    ];
  }

  return parsed;
}

function printUsage(): void {
  console.log(`
Usage: npx tsx scripts/run-skill-prompts.ts [options]

Options:
  --skill, -s <name>     Skill name to test (default: azure-workload-planner)
  --prompt, -p <text>    Add a prompt to run (repeatable)
  --file, -f <path>      Load prompts from a file (one per line, # for comments)
  --yolo                 Auto-approve all tool calls (non-interactive)
  --verbose, -v          Print full assistant responses
  --output, -o <dir>     Write results to output directory
  --help, -h             Show this help message

Examples:
  npx tsx scripts/run-skill-prompts.ts
  npx tsx scripts/run-skill-prompts.ts --prompt "Plan infra for a chat app"
  npx tsx scripts/run-skill-prompts.ts --file my-prompts.txt --yolo --verbose
  npx tsx scripts/run-skill-prompts.ts -s azure-workload-planner -v
`);
}

// ── Result formatting ───────────────────────────────────────────────────────

interface PromptResult {
  prompt: string;
  skillInvoked: boolean;
  toolCallCount: number;
  toolNames: string[];
  responsePreview: string;
  fullResponse: string;
  durationMs: number;
  error?: string;
}

function formatResult(result: PromptResult, index: number, verbose: boolean): string {
  const lines: string[] = [];
  const status = result.error ? "FAIL" : result.skillInvoked ? "PASS" : "WARN";
  const icon = result.error ? "X" : result.skillInvoked ? "OK" : "??";

  lines.push(`[${icon}] Prompt ${index + 1}: "${result.prompt}"`);
  lines.push(`     Status: ${status} | Skill invoked: ${result.skillInvoked} | Tools: ${result.toolCallCount} | Duration: ${(result.durationMs / 1000).toFixed(1)}s`);

  if (result.toolNames.length > 0) {
    lines.push(`     Tool calls: ${[...new Set(result.toolNames)].join(", ")}`);
  }

  if (result.error) {
    lines.push(`     Error: ${result.error}`);
  }

  if (verbose) {
    lines.push(`     Response:`);
    lines.push(result.fullResponse.split("\n").map(l => `       ${l}`).join("\n"));
  } else {
    lines.push(`     Response preview: ${result.responsePreview}`);
  }

  lines.push("");
  return lines.join("\n");
}

function formatSummary(results: PromptResult[]): string {
  const total = results.length;
  const passed = results.filter(r => r.skillInvoked && !r.error).length;
  const warned = results.filter(r => !r.skillInvoked && !r.error).length;
  const failed = results.filter(r => r.error).length;
  const avgDuration = results.reduce((sum, r) => sum + r.durationMs, 0) / total;

  const lines = [
    "═".repeat(60),
    `Summary: ${passed} passed, ${warned} warned (skill not invoked), ${failed} failed out of ${total} prompts`,
    `Average duration: ${(avgDuration / 1000).toFixed(1)}s`,
    "═".repeat(60),
  ];

  return lines.join("\n");
}

// ── Main ────────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  const cli = parseArgs();

  console.log(`\nSkill: ${cli.skill}`);
  console.log(`Prompts: ${cli.prompts.length}`);
  console.log(`Mode: ${cli.yolo ? "non-interactive (yolo)" : "interactive"}`);
  console.log("═".repeat(60));
  console.log("");

  const agent = useAgentRunner();
  const results: PromptResult[] = [];

  for (let i = 0; i < cli.prompts.length; i++) {
    const prompt = cli.prompts[i];
    console.log(`[${i + 1}/${cli.prompts.length}] Running: "${prompt.substring(0, 80)}${prompt.length > 80 ? "..." : ""}"`);

    const start = Date.now();
    let result: PromptResult;

    try {
      const config: AgentRunConfig = {
        prompt,
        nonInteractive: cli.yolo,
      };

      const metadata: AgentMetadata = await agent.run(config);
      const durationMs = Date.now() - start;

      const fullResponse = getAllAssistantMessages(metadata);
      const toolCalls = getToolCalls(metadata);
      const toolNames = toolCalls.map(tc => tc.data.toolName as string);

      result = {
        prompt,
        skillInvoked: isSkillInvoked(metadata, cli.skill),
        toolCallCount: toolCalls.length,
        toolNames,
        responsePreview: fullResponse.substring(0, 200).replace(/\n/g, " ") + (fullResponse.length > 200 ? "..." : ""),
        fullResponse,
        durationMs,
      };
    } catch (error) {
      result = {
        prompt,
        skillInvoked: false,
        toolCallCount: 0,
        toolNames: [],
        responsePreview: "",
        fullResponse: "",
        durationMs: Date.now() - start,
        error: error instanceof Error ? error.message : String(error),
      };
    }

    results.push(result);
    console.log(formatResult(result, i, cli.verbose));
  }

  console.log(formatSummary(results));

  // Write results to file if output dir specified
  if (cli.outputDir) {
    const outDir = path.resolve(cli.outputDir);
    if (!fs.existsSync(outDir)) {
      fs.mkdirSync(outDir, { recursive: true });
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
    const outFile = path.join(outDir, `skill-prompts-${timestamp}.json`);
    fs.writeFileSync(outFile, JSON.stringify({ skill: cli.skill, results }, null, 2));
    console.log(`\nResults written to: ${outFile}`);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
