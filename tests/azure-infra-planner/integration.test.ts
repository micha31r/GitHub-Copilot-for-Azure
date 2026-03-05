/**
 * Integration Tests for azure-infra-planner
 * 
 * Tests skill behavior with a real Copilot agent session.
 * Runs prompts to verify skill invocation.
 * 
 * Prerequisites:
 * 1. npm install -g @github/copilot-cli
 * 2. Run `copilot` and authenticate
 */

import * as fs from "fs";
import * as path from "path";
import {
  useAgentRunner,
  // areToolCallsSuccess,
  doesAssistantMessageIncludeKeyword,
  shouldSkipIntegrationTests,
  getIntegrationSkipReason
} from "../utils/agent-runner";
import { isSkillInvoked, softCheckSkill, getToolCalls } from "../utils/evaluate";

const SKILL_NAME = "azure-infra-planner";
const RUNS_PER_PROMPT = 1;
const FOLLOW_UP_PROMPT = ["Go with recommended options. Assume all defaults to make the plan."];

const skipTests = shouldSkipIntegrationTests();
const skipReason = getIntegrationSkipReason();

if (skipTests && skipReason) {
  console.log(`⏭️  Skipping integration tests: ${skipReason}`);
}

const describeIntegration = skipTests ? describe.skip : describe;

describeIntegration(`${SKILL_NAME}_ - Integration Tests`, () => {
  const agent = useAgentRunner();
  const maxToolCallBeforeTerminate = 3;

  describe("skill-invocation", () => {
    test("invokes skill for architecture planning prompt", async () => {
      for (let i = 0; i < RUNS_PER_PROMPT; i++) {
        try {
          const agentMetadata = await agent.run({
            prompt: "Plan Azure infrastructure for an event-driven serverless data pipeline with Cosmos DB and Event Hub.",
            nonInteractive: true,
            followUp: FOLLOW_UP_PROMPT,
            shouldEarlyTerminate: (agentMetadata) => isSkillInvoked(agentMetadata, SKILL_NAME) || getToolCalls(agentMetadata).length > maxToolCallBeforeTerminate
          });

          softCheckSkill(agentMetadata, SKILL_NAME);
        } catch (e: unknown) {
          if (e instanceof Error && e.message?.includes("Failed to load @github/copilot-sdk")) {
            console.log("⏭️  SDK not loadable, skipping test");
            return;
          }
          throw e;
        }
      }
    });

    test("invokes skill for web app infrastructure prompt", async () => {
      for (let i = 0; i < RUNS_PER_PROMPT; i++) {
        try {
          const agentMetadata = await agent.run({
            prompt: "I need to design Azure infrastructure for a web application with a SQL database, Redis cache, and VNet isolation.",
            nonInteractive: true,
            followUp: FOLLOW_UP_PROMPT,
            shouldEarlyTerminate: (agentMetadata) => isSkillInvoked(agentMetadata, SKILL_NAME) || getToolCalls(agentMetadata).length > maxToolCallBeforeTerminate
          });

          softCheckSkill(agentMetadata, SKILL_NAME);
        } catch (e: unknown) {
          if (e instanceof Error && e.message?.includes("Failed to load @github/copilot-sdk")) {
            console.log("⏭️  SDK not loadable, skipping test");
            return;
          }
          throw e;
        }
      }
    });

    test("invokes skill for microservices architecture prompt", async () => {
      for (let i = 0; i < RUNS_PER_PROMPT; i++) {
        try {
          const agentMetadata = await agent.run({
            prompt: "Plan Azure infrastructure for a microservices platform with AKS, Service Bus messaging, and API Management.",
            nonInteractive: true,
            followUp: FOLLOW_UP_PROMPT,
            shouldEarlyTerminate: (agentMetadata) => isSkillInvoked(agentMetadata, SKILL_NAME) || getToolCalls(agentMetadata).length > maxToolCallBeforeTerminate
          });

          softCheckSkill(agentMetadata, SKILL_NAME);
        } catch (e: unknown) {
          if (e instanceof Error && e.message?.includes("Failed to load @github/copilot-sdk")) {
            console.log("⏭️  SDK not loadable, skipping test");
            return;
          }
          throw e;
        }
      }
    });

    test("invokes skill for Bicep generation prompt", async () => {
      for (let i = 0; i < RUNS_PER_PROMPT; i++) {
        try {
          const agentMetadata = await agent.run({
            prompt: "Generate Bicep templates for my Azure workload that includes App Service, Key Vault, and managed identity.",
            nonInteractive: true,
            followUp: FOLLOW_UP_PROMPT,
            shouldEarlyTerminate: (agentMetadata) => isSkillInvoked(agentMetadata, SKILL_NAME) || getToolCalls(agentMetadata).length > maxToolCallBeforeTerminate
          });

          softCheckSkill(agentMetadata, SKILL_NAME);
        } catch (e: unknown) {
          if (e instanceof Error && e.message?.includes("Failed to load @github/copilot-sdk")) {
            console.log("⏭️  SDK not loadable, skipping test");
            return;
          }
          throw e;
        }
      }
    });
  });

  describe("response-quality", () => {
    test("response references infrastructure plan for planning prompt", async () => {
      const agentMetadata = await agent.run({
        prompt: "Plan Azure infrastructure for a web application with a database and cache layer. Assume all defaults to make the plan.",
        nonInteractive: true,
        followUp: FOLLOW_UP_PROMPT,
      });

      const mentionsPlan = doesAssistantMessageIncludeKeyword(agentMetadata, "plan") ||
        doesAssistantMessageIncludeKeyword(agentMetadata, "infrastructure");
      expect(mentionsPlan).toBe(true);
    });

    test("response mentions specific Azure resources", async () => {
      const agentMetadata = await agent.run({
        prompt: "What Azure resources do I need for a REST API with a relational database? Assume all defaults to make the plan.",
        nonInteractive: true,
        followUp: FOLLOW_UP_PROMPT,
        // preserveWorkspace: true
      });

      const mentionsResource =
        doesAssistantMessageIncludeKeyword(agentMetadata, "App Service") ||
        doesAssistantMessageIncludeKeyword(agentMetadata, "SQL") ||
        doesAssistantMessageIncludeKeyword(agentMetadata, "Container App") ||
        doesAssistantMessageIncludeKeyword(agentMetadata, "Function");
      expect(mentionsResource).toBe(true);
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
        prompt: "What Azure infrastructure do I need for this project? Assume all defaults to make the plan.",
        nonInteractive: true,
        followUp: FOLLOW_UP_PROMPT,
      });

      softCheckSkill(agentMetadata, SKILL_NAME);
    });

    test("detects Python Flask + PostgreSQL from requirements.txt", async () => {
      const agentMetadata = await agent.run({
        setup: async (workspace: string) => {
          fs.writeFileSync(
            path.join(workspace, "requirements.txt"),
            "flask==3.0.0\npsycopg2-binary==2.9.9\nazure-identity==1.15.0\n"
          );
        },
        prompt: "Plan Azure infrastructure for this Python application. Assume all defaults to make the plan.",
        nonInteractive: true,
        followUp: FOLLOW_UP_PROMPT,
      });

      softCheckSkill(agentMetadata, SKILL_NAME);
    });
  });
});
