---
name: invocation-master
description: "Iteratively test and improve skill invocation rates by running golden prompts against the Copilot agent, evaluating activation scores, and refining frontmatter and trigger statements. WHEN: \"improve skill discoverability\", \"skill not being selected\", \"wrong skill invoked\", \"fix skill activation\", \"skill invocation test\", \"improve frontmatter\", \"optimize triggers\", \"skill selection rate\"."
---

# Invocation Master

Iteratively test and improve skill invocation rates by running golden prompts, measuring activation scores, and refining frontmatter and trigger statements.

## Triggers

Activate this skill when user wants to:
- Improve the invocation/activation rate of a skill
- Debug why a skill is not being selected by the agent
- Test whether the agent selects the correct skill for a set of prompts
- Optimize a skill's frontmatter and trigger statements for discoverability

## Rules

- **Do not use glob/file search to discover files.** All paths are listed below. Read them directly.
- **Do not use or install SQLite.** It is not needed.

## Key File Locations

| File | Path |
|------|------|
| Target skill SKILL.md | `<root>/plugin/skills/<skill-name>/SKILL.md` |
| Golden prompts | `<root>/GoldenPrompts.csv` |
| Invocation test file | `<root>/tests/<skill-name>/invocation.integration.test.ts` |
| Test results output | `<root>/.invocation-test-logs/` |
| Test utilities | `<root>/tests/utils/` |
| Test config | `<root>/tests/jest.config.ts` |

## Step 1: Check for Invocation Test

Check if `<root>/tests/<skill-name>/invocation.integration.test.ts` exists. If it does, continue to Step 2. If not, create it by following the instructions in [setup.md](references/setup.md).

## Step 2: Improvement Loop

Track these variables:
- `currentIndex` = `0` (which batch of prompts to test)
- `fullPasses` = `0` (how many times we've cycled through all prompts, max 4)

Repeat the following:

1. **Run tests.** From `<root>/tests/`, run:
   ```bash
   INVOCATION_INDEX=<currentIndex> npm run test:integration -- <skill-name> --testNamePattern="invocation"
   ```
2. **Read results.** Read the JSON result files from `<root>/.invocation-test-logs/`. Each file contains `promptIndex`, `prompt`, `selectedSkill`, `correct`, and `reasoning`.
3. **Print invocation rate.** Calculate `correct / total` for this batch and print it.
4. **Improve frontmatter.** Based on the test results, update the target SKILL.md's frontmatter and trigger statements. When analyzing, also consider results from previous batches — look at which prompts succeeded and why, not just which failed. Some golden prompts may not be good candidates for the target skill; identifying common factors in successful prompts can be as useful as diagnosing failures. Read [constraints.md](references/constraints.md) for refinement rules and [competing-skills.md](references/competing-skills.md) for how to analyze competing skills.
5. **Advance index.** Set `currentIndex += 5`. If `currentIndex` exceeds total prompts in `GoldenPrompts.csv`, wrap to `0` and increment `fullPasses`.
6. **Check full pass limit.** If `fullPasses >= 4`, stop.
7. **Repeat** from step 1.

## Stopping Criteria

The loop only stops when `fullPasses >= 4`.

If the invocation rate reaches **70%** or higher for a batch, note what changes contributed to the improvement and continue to the next batch. Do not stop — keep exploring other strategies and testing remaining prompts.

If multiple successive batches show no improvement, note that the issue may be outside the frontmatter, but still continue until the full pass limit is reached.
