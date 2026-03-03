# Setup: Create the Invocation Integration Test

### Goal

Create an integration test for the target skill that tests whether the Copilot agent selects the correct skill for a given prompt.

### Location

Create the test file at `<root>/tests/<skill-name>/`. Follow the existing test naming convention (`tests/<skill-name>/`). Look at an existing integration test (e.g. `<root>/tests/azure-deploy/`) for the expected structure and imports.

### Golden Prompts

Test prompts are defined in `<root>/GoldenPrompts.csv`. Read this file and use the `prompt` column as test inputs.

### Test Implementation

- Implement this as an integration test using the Copilot SDK (already configured for integration tests).
- **One prompt per test case.** Do not loop through multiple prompts in a single test. Run up to 5 test cases in parallel.
- **Skip skill execution.** The SKILL.md has two sections relevant to skill selection: the YAML frontmatter (between `---` delimiters, containing `name`, `description`) and the `## Triggers` section (bullet list of activation conditions). After loading the SKILL.md, truncate it to only these two sections — discard everything after `## Triggers` ends (i.e. everything from `## Rules` onward). Append this sentence to each test prompt: `"This is an invocation test. Select the most appropriate skill and halt immediately — do not execute the skill."` This keeps tests fast.
- Write each result as a JSON file to `<root>/.invocation-test-logs/`, one file per prompt. Use this format:

```json
{
  "prompt": "the golden prompt text",
  "selectedSkill": "skill-name",
  "correct": true,
  "reasoning": "agent's explanation for why it chose this skill"
}
```

### Running Tests

From the repo root:

```bash
cd tests
npm run test:integration -- <skill-name>
```
