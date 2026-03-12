/**
 * Tests for thinking-log utility
 *
 * Uses mock SessionEvent arrays to verify both summary and detailed log generation
 * without requiring a live Copilot SDK session.
 */

import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { generateThinkingLogs, partitionEventsByAgent } from "../thinking-log";
import type { SessionEvent } from "@github/copilot-sdk";

function makeEvent(type: string, data: Record<string, unknown>, overrides?: Partial<SessionEvent>): SessionEvent {
  return {
    id: `evt-${Math.random().toString(36).slice(2, 8)}`,
    timestamp: overrides?.timestamp ?? new Date().toISOString(),
    parentId: overrides?.parentId ?? null,
    type,
    data,
  } as SessionEvent;
}

function makeTimestamp(offsetMs: number): string {
  return new Date(Date.UTC(2025, 0, 1, 12, 0, 0, 0) + offsetMs).toISOString();
}

describe("thinking-log", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "thinking-log-test-"));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test("generates both log files from tool events", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "bash",
        arguments: { command: "git status", description: "Check repo" },
      }, { timestamp: makeTimestamp(0) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc1",
        success: true,
        result: { content: "On branch main\nNothing to commit" },
      }, { timestamp: makeTimestamp(700) }),
      makeEvent("session.idle", {}, { timestamp: makeTimestamp(1000) }),
    ];

    const { summaryPath, detailedPath } = generateThinkingLogs(events, tmpDir, "Fix the bug");

    expect(fs.existsSync(summaryPath)).toBe(true);
    expect(fs.existsSync(detailedPath)).toBe(true);

    const summary = fs.readFileSync(summaryPath, "utf-8");
    expect(summary).toContain("TOOL>");
    expect(summary).toContain("bash");
    expect(summary).toContain("cmd: git status");
    expect(summary).toContain("TOOL<");
    expect(summary).toContain("700ms");
    expect(summary).toContain("✓");
    expect(summary).toContain("SESSION<");
    expect(summary).toContain("1 tools");
    expect(summary).toContain('Prompt: "Fix the bug"');

    const detailed = fs.readFileSync(detailedPath, "utf-8").trim().split("\n");
    expect(detailed).toHaveLength(3);
    const first = JSON.parse(detailed[0]);
    expect(first.event).toBe("tool.execution_start");
    expect(first.meta.toolName).toBe("bash");

    // Verify file names match CLI hook convention
    expect(path.basename(summaryPath)).toBe("summary.log");
    expect(path.basename(detailedPath)).toBe("detailed.jsonl");
  });

  test("classifies skill invocations", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "skill",
        arguments: { skill: "azure-prepare" },
      }, { timestamp: makeTimestamp(0) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc1",
        success: true,
      }, { timestamp: makeTimestamp(1500) }),
    ];

    const { summaryPath } = generateThinkingLogs(events, tmpDir);
    const summary = fs.readFileSync(summaryPath, "utf-8");
    expect(summary).toContain("skill");
    expect(summary).toContain("name:azure-prepare");
  });

  test("classifies task/subagent spawns", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "task",
        arguments: { agent_type: "explore", mode: "background", description: "Search auth files", prompt: "Find all auth..." },
      }, { timestamp: makeTimestamp(0) }),
      makeEvent("subagent.started", {
        agentName: "explore",
        agentDisplayName: "Search auth files",
      }, { timestamp: makeTimestamp(100) }),
      makeEvent("subagent.completed", {
        agentName: "explore",
      }, { timestamp: makeTimestamp(3000) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc1",
        success: true,
        result: { content: "Found 5 auth files" },
      }, { timestamp: makeTimestamp(3100) }),
    ];

    const { summaryPath } = generateThinkingLogs(events, tmpDir);
    const summary = fs.readFileSync(summaryPath, "utf-8");
    expect(summary).toContain("agent:explore");
    expect(summary).toContain("mode:bg");
    expect(summary).toContain('desc:"Search auth files"');
    expect(summary).toContain("SUBAGENT>");
    expect(summary).toContain("SUBAGENT<");
  });

  test("shows nested tool calls with indent", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "task",
        arguments: { agent_type: "explore", mode: "sync", description: "Check files" },
      }, { timestamp: makeTimestamp(0) }),
      // Nested tool call (inside subagent)
      makeEvent("tool.execution_start", {
        toolCallId: "tc2",
        toolName: "grep",
        arguments: { pattern: "auth", path: "src/" },
        parentToolCallId: "tc1",
      }, { timestamp: makeTimestamp(500) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc2",
        success: true,
        result: { content: "5 matches" },
        parentToolCallId: "tc1",
      }, { timestamp: makeTimestamp(800) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc1",
        success: true,
        result: { content: "Done" },
      }, { timestamp: makeTimestamp(1000) }),
    ];

    const { summaryPath } = generateThinkingLogs(events, tmpDir);
    const summary = fs.readFileSync(summaryPath, "utf-8");
    const lines = summary.split("\n");

    // Find the nested grep lines — they should have 2-space indent
    const grepStart = lines.find(l => l.includes("grep") && l.includes("TOOL>"));
    const grepEnd = lines.find(l => l.includes("grep") && l.includes("TOOL<"));
    expect(grepStart).toMatch(/\]   TOOL>/); // 2-space indent before TOOL
    expect(grepEnd).toMatch(/\]   TOOL</);
  });

  test("captures reasoning and response events", () => {
    const events: SessionEvent[] = [
      makeEvent("assistant.reasoning", {
        content: "Let me analyze the authentication module to understand the issue.",
      }, { timestamp: makeTimestamp(0) }),
      makeEvent("assistant.message", {
        messageId: "msg1",
        content: "I found the bug in auth.ts",
      }, { timestamp: makeTimestamp(1000) }),
    ];

    const { summaryPath } = generateThinkingLogs(events, tmpDir);
    const summary = fs.readFileSync(summaryPath, "utf-8");
    expect(summary).toContain("THINKING");
    expect(summary).toContain("authentication module");
    expect(summary).toContain("RESPONSE");
    expect(summary).toContain("found the bug");
  });

  test("captures errors", () => {
    const events: SessionEvent[] = [
      makeEvent("session.error", {
        errorType: "TimeoutError",
        message: "Network request timed out after 30s",
      }, { timestamp: makeTimestamp(0) }),
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "bash",
        arguments: { command: "curl example.com" },
      }, { timestamp: makeTimestamp(100) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc1",
        success: false,
        error: { message: "Connection refused" },
      }, { timestamp: makeTimestamp(600) }),
    ];

    const { summaryPath } = generateThinkingLogs(events, tmpDir);
    const summary = fs.readFileSync(summaryPath, "utf-8");
    expect(summary).toContain("ERROR");
    expect(summary).toContain("TimeoutError");
    expect(summary).toContain("✗");
    expect(summary).toContain("Connection refused");
    expect(summary).toContain("Errors: 2");
  });

  test("detects parallel subagent bursts", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "task",
        arguments: { agent_type: "explore", mode: "background", description: "Task A" },
      }, { timestamp: makeTimestamp(0) }),
      makeEvent("tool.execution_start", {
        toolCallId: "tc2",
        toolName: "task",
        arguments: { agent_type: "explore", mode: "background", description: "Task B" },
      }, { timestamp: makeTimestamp(10) }), // 10ms apart = parallel
      makeEvent("tool.execution_start", {
        toolCallId: "tc3",
        toolName: "task",
        arguments: { agent_type: "explore", mode: "background", description: "Task C" },
      }, { timestamp: makeTimestamp(20) }), // 20ms after first = parallel
    ];

    const { summaryPath } = generateThinkingLogs(events, tmpDir);
    const summary = fs.readFileSync(summaryPath, "utf-8");
    expect(summary).toContain("Parallel subagents detected: 1 burst");
  });

  test("handles edit/view/create path classification", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "edit",
        arguments: { path: "C:\\Users\\dev\\project\\src\\components\\Auth.tsx" },
      }, { timestamp: makeTimestamp(0) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc1",
        success: true,
      }, { timestamp: makeTimestamp(200) }),
    ];

    const { summaryPath } = generateThinkingLogs(events, tmpDir);
    const summary = fs.readFileSync(summaryPath, "utf-8");
    expect(summary).toContain("edit");
    expect(summary).toContain("path:");
    expect(summary).toContain("Auth.tsx");
  });

  test("handles usage events", () => {
    const events: SessionEvent[] = [
      makeEvent("assistant.usage", {
        model: "claude-sonnet-4.5",
        inputTokens: 15000,
        outputTokens: 2000,
        duration: 3500,
      }, { timestamp: makeTimestamp(0) }),
    ];

    const { summaryPath } = generateThinkingLogs(events, tmpDir);
    const summary = fs.readFileSync(summaryPath, "utf-8");
    expect(summary).toContain("USAGE");
    expect(summary).toContain("claude-sonnet-4.5");
    expect(summary).toContain("in:15000");
    expect(summary).toContain("out:2000");
  });

  test("detailed JSONL contains all enrichment fields", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "bash",
        arguments: { command: "echo hello" },
      }, { timestamp: makeTimestamp(500) }),
    ];

    const { detailedPath } = generateThinkingLogs(events, tmpDir);
    const line = JSON.parse(fs.readFileSync(detailedPath, "utf-8").trim());
    expect(line.event).toBe("tool.execution_start");
    expect(line.ts).toBeDefined();
    expect(line.tsMs).toBeGreaterThan(0);
    expect(line.relativeMs).toBe(0); // first event
    expect(line.id).toBeDefined();
    expect(line.meta.toolName).toBe("bash");
    expect(line.meta.toolCallId).toBe("tc1");
    expect(line.meta.args.command).toBe("echo hello");
  });
});

describe("subagent partitioning", () => {
  let tmpDir: string;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "thinking-log-subagent-"));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function makeTimestamp(offsetMs: number): string {
    return new Date(Date.UTC(2025, 0, 1, 12, 0, 0, 0) + offsetMs).toISOString();
  }

  function makeEvent(type: string, data: Record<string, unknown>, overrides?: Partial<SessionEvent>): SessionEvent {
    return {
      id: overrides?.id ?? `evt-${Math.random().toString(36).slice(2, 8)}`,
      timestamp: overrides?.timestamp ?? new Date().toISOString(),
      parentId: overrides?.parentId ?? null,
      type,
      data,
    } as SessionEvent;
  }

  test("partitions events by subagent using parentToolCallId", () => {
    const events: SessionEvent[] = [
      // Main agent spawns task
      makeEvent("tool.execution_start", {
        toolCallId: "tc-task",
        toolName: "task",
        arguments: { agent_type: "explore", mode: "sync", description: "Search" },
      }, { id: "e1", timestamp: makeTimestamp(0) }),
      // Subagent starts
      makeEvent("subagent.started", {
        toolCallId: "tc-task",
        agentName: "explore",
        agentDisplayName: "Search files",
        agentDescription: "Search for files",
      }, { id: "e2", timestamp: makeTimestamp(100) }),
      // Tool inside subagent
      makeEvent("tool.execution_start", {
        toolCallId: "tc-grep",
        toolName: "grep",
        arguments: { pattern: "auth" },
        parentToolCallId: "tc-task",
      }, { id: "e3", timestamp: makeTimestamp(200) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc-grep",
        success: true,
        result: { content: "3 matches" },
        parentToolCallId: "tc-task",
      }, { id: "e4", timestamp: makeTimestamp(500) }),
      // Subagent completes
      makeEvent("subagent.completed", {
        toolCallId: "tc-task",
        agentName: "explore",
        agentDisplayName: "Search files",
      }, { id: "e5", timestamp: makeTimestamp(600) }),
      // Main agent tool
      makeEvent("tool.execution_start", {
        toolCallId: "tc-edit",
        toolName: "edit",
        arguments: { path: "src/auth.ts" },
      }, { id: "e6", timestamp: makeTimestamp(800) }),
    ];

    const { mainEvents, subagents } = partitionEventsByAgent(events);

    // Main gets: task spawn (e1) and edit (e6)
    expect(mainEvents).toHaveLength(2);
    expect(mainEvents[0].id).toBe("e1");
    expect(mainEvents[1].id).toBe("e6");

    // Subagent gets: started, grep start, grep complete, completed
    expect(subagents.size).toBe(1);
    const sub = subagents.get("tc-task")!;
    expect(sub.agentName).toBe("explore");
    expect(sub.events).toHaveLength(4);
    expect(sub.events.map(e => e.id)).toEqual(["e2", "e3", "e4", "e5"]);
  });

  test("groups reasoning events via parentId chain", () => {
    const events: SessionEvent[] = [
      makeEvent("subagent.started", {
        toolCallId: "tc-task",
        agentName: "explore",
        agentDisplayName: "Explore",
        agentDescription: "Explore code",
      }, { id: "e1", timestamp: makeTimestamp(0) }),
      // Reasoning inside subagent — no parentToolCallId, but parentId chains to subagent
      makeEvent("assistant.reasoning", {
        reasoningId: "r1",
        content: "Let me search for auth files",
      }, { id: "e2", parentId: "e1", timestamp: makeTimestamp(100) }),
      // Tool inside subagent (via parentToolCallId)
      makeEvent("tool.execution_start", {
        toolCallId: "tc-grep",
        toolName: "grep",
        arguments: { pattern: "auth" },
        parentToolCallId: "tc-task",
      }, { id: "e3", parentId: "e2", timestamp: makeTimestamp(200) }),
      // Response chains through parentId
      makeEvent("assistant.message", {
        messageId: "m1",
        content: "Found auth module",
      }, { id: "e4", parentId: "e3", timestamp: makeTimestamp(500) }),
      makeEvent("subagent.completed", {
        toolCallId: "tc-task",
        agentName: "explore",
        agentDisplayName: "Explore",
      }, { id: "e5", timestamp: makeTimestamp(600) }),
    ];

    const { mainEvents, subagents } = partitionEventsByAgent(events);

    expect(mainEvents).toHaveLength(0);
    const sub = subagents.get("tc-task")!;
    expect(sub.events).toHaveLength(5);
    // Reasoning (e2) grouped via parentId → e1 (subagent.started)
    expect(sub.events.map(e => e.id)).toEqual(["e1", "e2", "e3", "e4", "e5"]);
  });

  test("generates subagent subfolders", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc-main",
        toolName: "bash",
        arguments: { command: "echo hello" },
      }, { id: "e1", timestamp: makeTimestamp(0) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc-main",
        success: true,
      }, { id: "e2", timestamp: makeTimestamp(100) }),
      makeEvent("subagent.started", {
        toolCallId: "tc-sub-abc123",
        agentName: "explore",
        agentDisplayName: "Search code",
        agentDescription: "Search code",
      }, { id: "e3", timestamp: makeTimestamp(200) }),
      makeEvent("tool.execution_start", {
        toolCallId: "tc-grep",
        toolName: "grep",
        arguments: { pattern: "test" },
        parentToolCallId: "tc-sub-abc123",
      }, { id: "e4", timestamp: makeTimestamp(300) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc-grep",
        success: true,
        result: { content: "2 matches" },
        parentToolCallId: "tc-sub-abc123",
      }, { id: "e5", timestamp: makeTimestamp(600) }),
      makeEvent("subagent.completed", {
        toolCallId: "tc-sub-abc123",
        agentName: "explore",
        agentDisplayName: "Search code",
      }, { id: "e6", timestamp: makeTimestamp(700) }),
    ];

    const result = generateThinkingLogs(events, tmpDir, "Test prompt");

    // Main logs exist
    expect(fs.existsSync(result.summaryPath)).toBe(true);
    expect(fs.existsSync(result.detailedPath)).toBe(true);

    // Subagent subfolder exists
    expect(result.subagentPaths).toHaveLength(1);
    const sub = result.subagentPaths![0];
    expect(sub.agentName).toBe("explore");
    expect(sub.toolCallId).toBe("tc-sub-abc123");
    expect(fs.existsSync(sub.summaryPath)).toBe(true);
    expect(fs.existsSync(sub.detailedPath)).toBe(true);

    // Verify subfolder path structure
    expect(sub.summaryPath).toContain(path.join("subagents", "explore-abc123"));

    // Verify subagent summary contains only its events
    const subSummary = fs.readFileSync(sub.summaryPath, "utf-8");
    expect(subSummary).toContain("explore");
    expect(subSummary).toContain("grep");
    expect(subSummary).not.toContain("echo hello"); // main agent's tool
  });

  test("handles multiple subagents", () => {
    const events: SessionEvent[] = [
      makeEvent("subagent.started", {
        toolCallId: "tc-a1",
        agentName: "explore",
        agentDisplayName: "Agent A",
        agentDescription: "First",
      }, { id: "e1", timestamp: makeTimestamp(0) }),
      makeEvent("tool.execution_start", {
        toolCallId: "tc-grep-a",
        toolName: "grep",
        arguments: { pattern: "foo" },
        parentToolCallId: "tc-a1",
      }, { id: "e2", timestamp: makeTimestamp(100) }),
      makeEvent("subagent.started", {
        toolCallId: "tc-b2",
        agentName: "task",
        agentDisplayName: "Agent B",
        agentDescription: "Second",
      }, { id: "e3", timestamp: makeTimestamp(150) }),
      makeEvent("tool.execution_start", {
        toolCallId: "tc-bash-b",
        toolName: "bash",
        arguments: { command: "ls" },
        parentToolCallId: "tc-b2",
      }, { id: "e4", timestamp: makeTimestamp(200) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc-grep-a",
        success: true,
        parentToolCallId: "tc-a1",
      }, { id: "e5", timestamp: makeTimestamp(300) }),
      makeEvent("subagent.completed", {
        toolCallId: "tc-a1",
        agentName: "explore",
        agentDisplayName: "Agent A",
      }, { id: "e6", timestamp: makeTimestamp(400) }),
      makeEvent("tool.execution_complete", {
        toolCallId: "tc-bash-b",
        success: true,
        parentToolCallId: "tc-b2",
      }, { id: "e7", timestamp: makeTimestamp(500) }),
      makeEvent("subagent.completed", {
        toolCallId: "tc-b2",
        agentName: "task",
        agentDisplayName: "Agent B",
      }, { id: "e8", timestamp: makeTimestamp(600) }),
    ];

    const result = generateThinkingLogs(events, tmpDir);

    expect(result.subagentPaths).toHaveLength(2);
    const names = result.subagentPaths!.map(s => s.agentName).sort();
    expect(names).toEqual(["explore", "task"]);

    // Each subfolder has its own files
    for (const sub of result.subagentPaths!) {
      expect(fs.existsSync(sub.summaryPath)).toBe(true);
      expect(fs.existsSync(sub.detailedPath)).toBe(true);
    }
  });

  test("returns no subagentPaths when no subagents exist", () => {
    const events: SessionEvent[] = [
      makeEvent("tool.execution_start", {
        toolCallId: "tc1",
        toolName: "bash",
        arguments: { command: "echo hi" },
      }, { timestamp: makeTimestamp(0) }),
    ];

    const result = generateThinkingLogs(events, tmpDir);
    expect(result.subagentPaths).toBeUndefined();
  });
});
