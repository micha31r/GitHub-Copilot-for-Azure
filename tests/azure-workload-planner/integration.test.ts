/**
 * Integration Tests for azure-workload-planner
 * 
 * Tests skill behavior with a real Copilot agent session.
 * Runs prompts multiple times to measure skill invocation rate.
 * 
 * Prerequisites:
 * 1. npm install -g @github/copilot-cli
 * 2. Run `copilot` and authenticate
 */

import * as fs from "fs";
import * as path from "path";
import {
  useAgentRunner,
  isSkillInvoked,
  // areToolCallsSuccess,
  doesAssistantMessageIncludeKeyword,
  shouldSkipIntegrationTests,
  getIntegrationSkipReason
} from "../utils/agent-runner";

const SKILL_NAME = "azure-workload-planner";
const RUNS_PER_PROMPT = 5;
const EXPECTED_INVOCATION_RATE = 0.6; // 60% minimum invocation rate

const skipTests = shouldSkipIntegrationTests();
const skipReason = getIntegrationSkipReason();

if (skipTests && skipReason) {
  console.log(`⏭️  Skipping integration tests: ${skipReason}`);
}

const describeIntegration = skipTests ? describe.skip : describe;

/** Helper to run a prompt N times and return invocation rate */
async function measureInvocationRate(
  agent: ReturnType<typeof useAgentRunner>,
  prompt: string,
  setup?: (workspace: string) => Promise<void>
): Promise<{ rate: number; successCount: number; total: number }> {
  let successCount = 0;

  for (let i = 0; i < RUNS_PER_PROMPT; i++) {
    try {
      const agentMetadata = await agent.run({ prompt, setup });
      if (isSkillInvoked(agentMetadata, SKILL_NAME)) {
        successCount++;
      }
    } catch (e: unknown) {
      if (e instanceof Error && e.message?.includes("Failed to load @github/copilot-sdk")) {
        return { rate: -1, successCount: 0, total: RUNS_PER_PROMPT };
      }
      throw e;
    }
  }

  const rate = successCount / RUNS_PER_PROMPT;
  return { rate, successCount, total: RUNS_PER_PROMPT };
}

/** Log and record invocation rate */
function logResult(label: string, result: { rate: number; successCount: number; total: number }) {
  const rateStr = `${(result.rate * 100).toFixed(1)}% (${result.successCount}/${result.total})`;
  console.log(`${SKILL_NAME} invocation rate for ${label}: ${rateStr}`);
  fs.appendFileSync(
    `./result-${SKILL_NAME}.txt`,
    `${SKILL_NAME} invocation rate for ${label}: ${rateStr}\n`
  );
}

describeIntegration(`${SKILL_NAME}_ - Integration Tests`, () => {
  const agent = useAgentRunner();

  describe("skill-invocation", () => {
    test("invokes skill for architecture planning prompt", async () => {
      const result = await measureInvocationRate(
        agent,
        "Plan Azure infrastructure for an event-driven serverless data pipeline with Cosmos DB and Event Hub"
      );
      if (result.rate === -1) return; // SDK not available
      logResult("architecture planning", result);
      expect(result.rate).toBeGreaterThanOrEqual(EXPECTED_INVOCATION_RATE);
    });

    test("invokes skill for web app infrastructure prompt", async () => {
      const result = await measureInvocationRate(
        agent,
        "I need to design Azure infrastructure for a web application with a SQL database, Redis cache, and VNet isolation"
      );
      if (result.rate === -1) return;
      logResult("web app infrastructure", result);
      expect(result.rate).toBeGreaterThanOrEqual(EXPECTED_INVOCATION_RATE);
    });

    test("invokes skill for multi-environment planning prompt", async () => {
      const result = await measureInvocationRate(
        agent,
        "Create an infrastructure plan for dev, staging, and production environments on Azure"
      );
      if (result.rate === -1) return;
      logResult("multi-environment planning", result);
      expect(result.rate).toBeGreaterThanOrEqual(EXPECTED_INVOCATION_RATE);
    });

    test("invokes skill for microservices architecture prompt", async () => {
      const result = await measureInvocationRate(
        agent,
        "Plan Azure infrastructure for a microservices platform with AKS, Service Bus messaging, and API Management"
      );
      if (result.rate === -1) return;
      logResult("microservices architecture", result);
      expect(result.rate).toBeGreaterThanOrEqual(EXPECTED_INVOCATION_RATE);
    });

    test("invokes skill for Bicep generation prompt", async () => {
      const result = await measureInvocationRate(
        agent,
        "Generate Bicep templates for my Azure workload that includes App Service, Key Vault, and managed identity"
      );
      if (result.rate === -1) return;
      logResult("Bicep generation", result);
      expect(result.rate).toBeGreaterThanOrEqual(EXPECTED_INVOCATION_RATE);
    });
  });

  describe("response-quality", () => {
    test("response references infrastructure plan for planning prompt", async () => {
      const agentMetadata = await agent.run({
        prompt: "Plan Azure infrastructure for a web application with a database and cache layer"
      });

      const mentionsPlan = doesAssistantMessageIncludeKeyword(agentMetadata, "plan") ||
        doesAssistantMessageIncludeKeyword(agentMetadata, "infrastructure");
      expect(mentionsPlan).toBe(true);
    });

    test("response mentions specific Azure resources", async () => {
      const agentMetadata = await agent.run({
        prompt: "What Azure resources do I need for a REST API with a relational database?"
      });

      // Should mention at least one concrete Azure service
      const mentionsResource =
        doesAssistantMessageIncludeKeyword(agentMetadata, "App Service") ||
        doesAssistantMessageIncludeKeyword(agentMetadata, "SQL") ||
        doesAssistantMessageIncludeKeyword(agentMetadata, "Container App") ||
        doesAssistantMessageIncludeKeyword(agentMetadata, "Function");
      expect(mentionsResource).toBe(true);
    });

    test("response mentions Bicep or Terraform for IaC prompt", async () => {
      const agentMetadata = await agent.run({
        prompt: "Generate infrastructure as code for my Azure workload"
      });

      const hasBicep = doesAssistantMessageIncludeKeyword(agentMetadata, "Bicep");
      const hasTerraform = doesAssistantMessageIncludeKeyword(agentMetadata, "Terraform");
      expect(hasBicep || hasTerraform).toBe(true);
    });
  });

  describe("workspace-context", () => {
    test("detects Express + Cosmos from package.json", async () => {
      const agentMetadata = await agent.run({
        setup: async (workspace: string) => {
          fs.writeFileSync(
            path.join(workspace, "package.json"),
            JSON.stringify({
              name: "my-api",
              dependencies: {
                "express": "^4.18.0",
                "@azure/cosmos": "^4.0.0"
              }
            })
          );
        },
        prompt: "What Azure infrastructure do I need for this project?"
      });

      expect(isSkillInvoked(agentMetadata, SKILL_NAME)).toBe(true);
    });

    test("detects Python Flask + PostgreSQL from requirements.txt", async () => {
      const agentMetadata = await agent.run({
        setup: async (workspace: string) => {
          fs.writeFileSync(
            path.join(workspace, "requirements.txt"),
            "flask==3.0.0\npsycopg2-binary==2.9.9\nazure-identity==1.15.0\n"
          );
        },
        prompt: "Plan Azure infrastructure for this Python application"
      });

      expect(isSkillInvoked(agentMetadata, SKILL_NAME)).toBe(true);
    });
  });
});
