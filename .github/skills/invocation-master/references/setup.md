# Setup: Create the Invocation Integration Test

### Goal

Create the file `<root>/tests/<skill-name>/invocation.integration.test.ts` — an integration test that checks whether the Copilot agent selects the correct skill for a batch of golden prompts.

### Rules

- **Do not use glob/file search to discover files.** All paths are specified explicitly below. Read them directly.
- **Do not use or install SQLite.** It is not needed.

### Location

Create the test file at `<root>/tests/<skill-name>/invocation.integration.test.ts`. Look at an existing integration test (e.g. `<root>/tests/azure-deploy/integration.test.ts`) for the expected structure and imports.

### Golden Prompts

Test prompts are defined in `<root>/GoldenPrompts.csv`. The test should read this file at runtime (not hardcode prompts).

### Batch Index

The test accepts a batch index via the `INVOCATION_INDEX` environment variable (default: `0`). It reads 5 prompts from `GoldenPrompts.csv` starting at that index (e.g. index `0` = prompts 0–4, index `5` = prompts 5–9).

### Test Implementation

- Implement this as an integration test using the Copilot SDK (already configured for integration tests).
- **One prompt per test case.** Use `test.concurrent.each` to run the 5 prompts in parallel.
- **CSV parsing.** Golden prompts contain commas inside quoted fields. Use a proper CSV parser (e.g. `csv-parse/sync`) or a regex that handles quoted fields correctly. Do not use a naive split on commas.
- **Early termination.** Use the `shouldEarlyTerminate` callback to abort the agent session as soon as a skill selection event is detected (`tool.execution_start` with `toolName === "skill"`). This prevents the agent from executing the full skill and keeps tests fast.
- **Follow-up for reasoning.** After the agent selects a skill, send a follow-up prompt to get an explanation. The `agent-runner` supports a `followUp` option (array of strings). Use this exact follow-up prompt:
  ```
  "Explain why you selected that skill instead of other available skills. List the specific keywords or phrases in the user's prompt that matched the chosen skill's description or triggers."
  ```
  Capture the agent's response to this follow-up and use it as the `reasoning` field in the test result JSON.
- **No unused imports.** Only import what the test actually uses.
- **Do not add a halt instruction to the prompt.** Skill selection is a tool call — telling the agent to halt prevents the skill tool from being invoked, which means no selection event is recorded. Rely on `shouldEarlyTerminate` to cut off execution after selection instead.
- Write each result as a JSON file to `<root>/.invocation-test-logs/`, one file per prompt. Filename: `<skill-name>-prompt-<NNN>.json` where NNN is the zero-padded prompt index. Use this format:

```json
{
  "promptIndex": 0,
  "prompt": "the golden prompt text",
  "selectedSkill": "skill-name",
  "correct": true,
  "reasoning": "agent's explanation for why it chose this skill"
}
```

### Running Tests

From the `<root>/tests/` directory:

```bash
INVOCATION_INDEX=0 npm run test:integration -- <skill-name> --testNamePattern="invocation"
```
