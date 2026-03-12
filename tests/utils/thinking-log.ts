/**
 * Thinking-Process Log Generator for Integration Tests
 *
 * Processes Copilot SDK SessionEvent[] into two log formats:
 * - thinking-summary.log: compact one-line-per-event human-readable
 * - thinking-detailed.jsonl: full JSON per event for machine consumption
 *
 * Designed to mirror the CLI hook logger (Phase 1) but leverages richer
 * SDK data: toolCallId correlation, parentToolCallId nesting, subagent
 * identity, assistant reasoning, and duration tracking.
 */

import * as fs from "fs";
import * as path from "path";
import type { SessionEvent } from "@github/copilot-sdk";

// ── Types ──────────────────────────────────────────────────────────────

interface ToolStartInfo {
  toolName: string;
  startTime: number;
  args?: unknown;
  parentToolCallId?: string;
}

interface SubagentInfo {
  agentName: string;
  displayName: string;
  toolCallId: string;
  events: SessionEvent[];
}

interface PartitionResult {
  mainEvents: SessionEvent[];
  subagents: Map<string, SubagentInfo>;
}

// ── Event partitioning ────────────────────────────────────────────────

/**
 * Partition events into main-agent and per-subagent groups.
 *
 * Ownership rules (in priority order):
 * 1. `subagent.*` lifecycle events → matched by data.toolCallId
 * 2. Events with `data.parentToolCallId` matching a subagent → that subagent
 * 3. Events whose `parentId` points to an already-assigned subagent event → same subagent (chain propagation)
 * 4. Everything else → main agent
 */
export function partitionEventsByAgent(events: SessionEvent[]): PartitionResult {
  const subagents = new Map<string, SubagentInfo>();
  const eventOwner = new Map<string, string>(); // event.id → toolCallId
  const mainEvents: SessionEvent[] = [];

  // Pass 1: identify subagent boundaries
  for (const event of events) {
    if (event.type === "subagent.started") {
      const tcId = (event.data as Record<string, unknown>).toolCallId as string;
      const agentName = ((event.data as Record<string, unknown>).agentName || "unknown") as string;
      const displayName = ((event.data as Record<string, unknown>).agentDisplayName || agentName) as string;
      subagents.set(tcId, { agentName, displayName, toolCallId: tcId, events: [] });
    }
  }

  if (subagents.size === 0) {
    return { mainEvents: events, subagents };
  }

  // Pass 2: assign events to subagents
  for (const event of events) {
    const data = event.data as Record<string, unknown>;
    let assignedTo: string | undefined;

    // Rule 1: subagent lifecycle events
    if (event.type.startsWith("subagent.") && data.toolCallId && subagents.has(data.toolCallId as string)) {
      assignedTo = data.toolCallId as string;
    }
    // Rule 2: direct parentToolCallId link
    else if (data.parentToolCallId && subagents.has(data.parentToolCallId as string)) {
      assignedTo = data.parentToolCallId as string;
    }
    // Rule 3: parentId chain propagation
    else if (event.parentId && eventOwner.has(event.parentId)) {
      assignedTo = eventOwner.get(event.parentId);
    }

    if (assignedTo) {
      eventOwner.set(event.id, assignedTo);
      subagents.get(assignedTo)!.events.push(event);
    } else {
      mainEvents.push(event);
    }
  }

  return { mainEvents, subagents };
}

// ── Smart tool classification ──────────────────────────────────────────

function classifyTool(toolName: string, args: Record<string, unknown> | undefined): string {
  if (!args) return toolName;

  switch (toolName) {
    case "bash":
    case "powershell": {
      const cmd = truncate(String(args.command ?? args.cmd ?? ""), 210);
      return `cmd: ${cmd}`;
    }
    case "task": {
      const parts: string[] = [];
      if (args.agent_type) parts.push(`agent:${args.agent_type}`);
      if (args.mode) parts.push(`mode:${args.mode === "background" ? "bg" : args.mode}`);
      if (args.description) parts.push(`desc:"${truncate(String(args.description), 90)}"`);
      if (args.prompt) parts.push(`prompt:"${truncate(String(args.prompt), 120)}"`);
      return parts.join(" ") || toolName;
    }
    case "skill": {
      const name = args.skill ?? "unknown";
      return `name:${name}`;
    }
    case "edit":
    case "create":
    case "view": {
      const p = args.path ? truncate(String(args.path), 210) : "";
      return p ? `path:${p}` : "";
    }
    case "grep":
    case "glob": {
      const parts: string[] = [];
      if (args.pattern) parts.push(`pattern:"${truncate(String(args.pattern), 120)}"`);
      if (args.path) parts.push(`path:${String(args.path)}`);
      return parts.join(" ");
    }
    case "ask_user": {
      const q = args.question ? truncate(String(args.question), 60) : "";
      return q ? `"${q}"` : "";
    }
    case "report_intent": {
      return args.intent ? `"${truncate(String(args.intent), 60)}"` : "";
    }
    case "sql": {
      return args.description ? truncate(String(args.description), 60) : "";
    }
    default: {
      // MCP tools (azure-*, github-*, foundry-*, context7-*, playwright-*)
      if (toolName.includes("-")) {
        const cmd = args.command || args.intent || args.method;
        if (cmd) return `${cmd}`;
      }
      // Generic: show first meaningful arg
      const firstKey = Object.keys(args).find(k => typeof args[k] === "string" && (args[k] as string).length < 100);
      if (firstKey) return `${firstKey}:"${truncate(String(args[firstKey]), 150)}"`;
      return "";
    }
  }
}

function formatResult(
  success: boolean,
  result?: { content?: string },
  error?: { message?: string },
  toolName?: string,
  toolArgs?: Record<string, unknown> | undefined,
): { statusIcon: string; detail: string } {
  let statusIcon: string;
  if (success) {
    statusIcon = "✓";
  } else {
    statusIcon = "✗";
  }

  const parts: string[] = [];
  // For task completions, prefix with agent type (like hooks)
  if (toolName === "task" && toolArgs?.agent_type) {
    parts.push(`agent:${toolArgs.agent_type}`);
  }
  if (!success && error?.message) {
    parts.push(`"${truncate(error.message.replace(/\n/g, "\\n"), 180)}"`);
  } else if (success && result?.content) {
    parts.push(`"${truncate(result.content.replace(/\n/g, "\\n"), 180)}"`);
  }

  return { statusIcon, detail: parts.join(" ") };
}

// ── Helpers ─────────────────────────────────────────────────────────────

function truncate(s: string, max: number): string {
  if (s.length <= max) return s;
  return s.substring(0, max) + "...";
}

function shortenPath(p: string): string {
  // Show last 2-3 segments
  const parts = p.replace(/\\/g, "/").split("/").filter(Boolean);
  if (parts.length <= 3) return parts.join("/");
  return ".../" + parts.slice(-3).join("/");
}

function relativeTime(eventMs: number, sessionStartMs: number): string {
  const diff = Math.max(0, eventMs - sessionStartMs);
  const mins = Math.floor(diff / 60000);
  const secs = Math.floor((diff % 60000) / 1000);
  const ms = diff % 1000;
  return `${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}.${String(ms).padStart(3, "0")}`;
}

function durationStr(ms: number): string {
  if (ms < 1000) return `${ms}ms`;
  return `${(ms / 1000).toFixed(1)}s`;
}

function parseTimestamp(ts: string): number {
  return new Date(ts).getTime();
}

function safeParseArgs(args: unknown): Record<string, unknown> | undefined {
  if (!args) return undefined;
  if (typeof args === "object" && args !== null) return args as Record<string, unknown>;
  if (typeof args === "string") {
    try { return JSON.parse(args); } catch { return undefined; }
  }
  return undefined;
}

// ── Core generator ─────────────────────────────────────────────────────

interface LogPaths {
  summaryPath: string;
  detailedPath: string;
  subagentPaths?: Array<{
    agentName: string;
    toolCallId: string;
    summaryPath: string;
    detailedPath: string;
  }>;
}

/**
 * Core log-writing logic shared by main and subagent logs.
 */
function writeLogFiles(
  events: SessionEvent[],
  reportDir: string,
  prompt?: string,
  agentLabel?: string,
): { summaryPath: string; detailedPath: string } {
  const summaryLines: string[] = [];
  const detailedLines: string[] = [];
  const toolStarts = new Map<string, ToolStartInfo>();

  const sessionStartMs = events.length > 0 ? parseTimestamp(events[0].timestamp) : Date.now();

  let toolCount = 0;
  let subagentCount = 0;
  let errorCount = 0;
  const bgTaskTimestamps: number[] = [];

  for (const event of events) {
    const ts = parseTimestamp(event.timestamp);
    const rel = relativeTime(ts, sessionStartMs);
    const indent = (event.type === "tool.execution_start" || event.type === "tool.execution_complete")
      && (event.data as Record<string, unknown>).parentToolCallId ? "  " : "";

    const detailed: Record<string, unknown> = {
      event: event.type,
      ts: event.timestamp,
      tsMs: ts,
      relativeMs: ts - sessionStartMs,
      id: event.id,
      parentId: event.parentId,
      data: event.data,
    };

    switch (event.type) {
      case "tool.execution_start": {
        const toolName = event.data.toolName as string;
        const toolCallId = event.data.toolCallId as string;
        const rawArgs = event.data.arguments;
        const parentId = event.data.parentToolCallId as string | undefined;
        const args = safeParseArgs(rawArgs);

        toolStarts.set(toolCallId, { toolName, startTime: ts, args: rawArgs, parentToolCallId: parentId });
        toolCount++;

        const info = classifyTool(toolName, args);
        const padded = toolName.padEnd(18);
        summaryLines.push(`[${rel}] ${indent}TOOL>     ${padded}| ${info}`);

        if (toolName === "task" && args?.mode === "background") {
          bgTaskTimestamps.push(ts);
        }

        detailed.meta = { toolName, toolCallId, parentToolCallId: parentId, args };
        break;
      }

      case "tool.execution_complete": {
        const toolCallId = event.data.toolCallId as string;
        const success = event.data.success as boolean;
        const result = event.data.result as { content?: string } | undefined;
        const error = event.data.error as { message?: string } | undefined;
        const startInfo = toolStarts.get(toolCallId);

        const toolName = startInfo?.toolName ?? "?";
        const dur = startInfo ? durationStr(ts - startInfo.startTime) : "";
        const startArgs = startInfo?.args ? safeParseArgs(startInfo.args) : undefined;
        const { statusIcon, detail } = formatResult(success, result, error, toolName, startArgs);
        const padded = toolName.padEnd(18);
        const durPad = dur ? `${dur.padStart(6)} ` : "";
        const statusPad = statusIcon.padEnd(5);
        const startIndent = startInfo?.parentToolCallId ? "  " : "";

        summaryLines.push(`[${rel}] ${startIndent}TOOL<     ${padded}${durPad}${statusPad}| ${detail}`);

        if (!success) errorCount++;
        detailed.meta = { toolName, toolCallId, success, durationMs: startInfo ? ts - startInfo.startTime : undefined };
        break;
      }

      case "subagent.started": {
        const name = (event.data.agentDisplayName || event.data.agentName || "?") as string;
        subagentCount++;
        summaryLines.push(`[${rel}] SUBAGENT> ${name}`);
        detailed.meta = { agentName: event.data.agentName, displayName: event.data.agentDisplayName };
        break;
      }

      case "subagent.completed": {
        const name = (event.data.agentName || "?") as string;
        summaryLines.push(`[${rel}] SUBAGENT< ${name} ✓`);
        detailed.meta = { agentName: name };
        break;
      }

      case "subagent.failed": {
        const name = (event.data.agentName || "?") as string;
        const errMsg = truncate(String(event.data.error ?? "unknown"), 80);
        errorCount++;
        summaryLines.push(`[${rel}] SUBAGENT! ${name} ✗ | ${errMsg}`);
        detailed.meta = { agentName: name, error: event.data.error };
        break;
      }

      case "assistant.reasoning": {
        const content = event.data.content as string;
        if (content) {
          summaryLines.push(`[${rel}] THINKING  "${truncate(content.replace(/\n/g, " "), 100)}"`);
        }
        break;
      }

      case "assistant.message": {
        const content = event.data.content as string;
        if (content) {
          summaryLines.push(`[${rel}] RESPONSE  "${truncate(content.replace(/\n/g, " "), 100)}"`);
        }
        break;
      }

      case "assistant.usage": {
        const inp = event.data.inputTokens ?? 0;
        const out = event.data.outputTokens ?? 0;
        const model = event.data.model || "?";
        const dur = event.data.duration ? durationStr(event.data.duration as number) : "";
        summaryLines.push(`[${rel}] USAGE     ${model} | in:${inp} out:${out}${dur ? " " + dur : ""}`);
        break;
      }

      case "session.error": {
        const errType = ((event.data.errorType || "UnknownError") as string).padEnd(18);
        const errMsg = truncate(String(event.data.message ?? "unknown"), 180);
        errorCount++;
        summaryLines.push(`[${rel}] ERROR     ${errType}| "${errMsg}"`);
        break;
      }

      case "session.idle": {
        const totalDur = durationStr(ts - sessionStartMs);
        summaryLines.push(`[${rel}] SESSION<  complete | ${totalDur} total | ${toolCount} tools | ${subagentCount} subagents | ${errorCount} errors`);
        break;
      }

      case "session.shutdown": {
        summaryLines.push(`[${rel}] SHUTDOWN`);
        break;
      }

      case "assistant.message_delta":
      case "assistant.reasoning_delta":
      case "tool.execution_progress":
      case "tool.execution_partial_result":
        break;

      default:
        break;
    }

    detailedLines.push(JSON.stringify(detailed));
  }

  const title = agentLabel ? `# Thinking Process Log — ${agentLabel}` : `# Thinking Process Log`;
  const header = [
    title,
    `# Generated: ${new Date().toISOString()}`,
    prompt ? `# Prompt: "${truncate(prompt, 180)}"` : null,
    `# Events: ${events.length} | Tools: ${toolCount} | Subagents: ${subagentCount} | Errors: ${errorCount}`,
    bgTaskTimestamps.length >= 2 ? `# Parallel subagents detected: ${countParallelBursts(bgTaskTimestamps)} burst(s)` : null,
    `#`,
  ].filter(Boolean).join("\n");

  const summaryContent = header + "\n" + summaryLines.join("\n") + "\n";
  const detailedContent = detailedLines.join("\n") + "\n";

  if (!fs.existsSync(reportDir)) {
    fs.mkdirSync(reportDir, { recursive: true });
  }

  const summaryPath = path.join(reportDir, "summary.log");
  const detailedPath = path.join(reportDir, "detailed.jsonl");

  fs.writeFileSync(summaryPath, summaryContent, "utf-8");
  fs.writeFileSync(detailedPath, detailedContent, "utf-8");

  return { summaryPath, detailedPath };
}

/**
 * Generate thinking-process logs from SDK events.
 * Writes summary.log and detailed.jsonl to reportDir.
 * When subagents are detected, also writes per-subagent logs
 * to reportDir/subagents/<agentName>-<suffix>/.
 */
export function generateThinkingLogs(
  events: SessionEvent[],
  reportDir: string,
  prompt?: string
): LogPaths {
  // Write full interleaved timeline
  const { summaryPath, detailedPath } = writeLogFiles(events, reportDir, prompt);

  const result: LogPaths = { summaryPath, detailedPath };

  // Partition and write per-subagent logs
  const { subagents } = partitionEventsByAgent(events);
  if (subagents.size > 0) {
    result.subagentPaths = [];
    for (const [, info] of subagents) {
      if (info.events.length === 0) continue;
      const suffix = info.toolCallId.length > 6 ? info.toolCallId.slice(-6) : info.toolCallId;
      const subDir = path.join(reportDir, "subagents", `${info.agentName}-${suffix}`);
      const agentLabel = `${info.displayName} (${info.agentName})`;
      const sub = writeLogFiles(info.events, subDir, undefined, agentLabel);
      result.subagentPaths.push({
        agentName: info.agentName,
        toolCallId: info.toolCallId,
        summaryPath: sub.summaryPath,
        detailedPath: sub.detailedPath,
      });
    }
  }

  return result;
}

/**
 * Count "bursts" of parallel background task spawns.
 * Tasks within 100ms of each other are considered parallel.
 */
function countParallelBursts(timestamps: number[]): number {
  if (timestamps.length < 2) return 0;
  const sorted = [...timestamps].sort((a, b) => a - b);
  let bursts = 0;
  let inBurst = false;
  for (let i = 1; i < sorted.length; i++) {
    if (sorted[i] - sorted[i - 1] < 100) {
      if (!inBurst) {
        bursts++;
        inBurst = true;
      }
    } else {
      inBurst = false;
    }
  }
  return bursts;
}
