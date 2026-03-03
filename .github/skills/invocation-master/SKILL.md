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

Track a `currentIndex` starting at `0`. Repeat the following:

1. **Run tests.** From `<root>/tests/`, run:
   ```bash
   INVOCATION_INDEX=<currentIndex> npm run test:integration -- <skill-name> --testNamePattern="invocation"
   ```
2. **Read results.** Read the JSON result files from `<root>/.invocation-test-logs/`. Each file contains `promptIndex`, `prompt`, `selectedSkill`, `correct`, and `reasoning`.
3. **Print invocation rate.** Calculate `correct / total` for this batch and print it.
4. **Improve frontmatter.** Based on the test results, update the target SKILL.md's frontmatter and trigger statements. Read [constraints.md](references/constraints.md) for refinement rules and [competing-skills.md](references/competing-skills.md) for how to analyze competing skills.
5. **Advance index.** Set `currentIndex += 5`. If it exceeds total prompts in `GoldenPrompts.csv`, wrap to `0`.
6. **Repeat** from step 1.

## Stopping Criteria

Stop when either:

- The invocation rate reaches **70%** or higher consistently.
- Multiple successive iterations show no improvement, suggesting the issue is outside the frontmatter.
