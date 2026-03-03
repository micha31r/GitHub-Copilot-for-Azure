---
name: invocation-master
description: "Iteratively test and improve skill invocation rates by running golden prompts against the Copilot agent, evaluating activation scores, and refining frontmatter and trigger statements. WHEN: \"improve skill discoverability\", \"skill not being selected\", \"wrong skill invoked\", \"fix skill activation\", \"skill invocation test\", \"improve frontmatter\", \"optimize triggers\", \"skill selection rate\"."
---

# Invocation Master

Iteratively test and improve skill invocation rates. Runs golden prompts against the Copilot agent, measures activation scores, and delegates frontmatter refinement to a subagent.

## Triggers

Activate this skill when user wants to:
- Improve the invocation/activation rate of a skill
- Debug why a skill is not being selected by the agent
- Test whether the agent selects the correct skill for a set of prompts
- Optimize a skill's frontmatter and trigger statements for discoverability

## Your Role

You are the **orchestrator**. You run integration tests in batches, then call a subagent to analyze results and refine the frontmatter. You do not analyze or edit the target skill's SKILL.md yourself.

## Prerequisites

The integration test file at `<root>/tests/<skill-name>/` will already exist. Check if it contains invocation-specific test cases (tests that send golden prompts and record skill selection). If not, invoke a subagent with the instructions in [setup.md](references/setup.md) to add them.

## Workflow

1. **Run a batch of 5 test cases in parallel.** Each test case sends one golden prompt (from `<root>/GoldenPrompts.csv`) to the Copilot agent and records whether the target skill was selected. Write results to `<root>/.invocation-test-logs/`, one JSON file per prompt.
2. **Evaluate.** Calculate the activation rate from the batch results and append an entry to `<root>/.eval-logs.json`. The first iteration serves as the baseline.
3. **Call a subagent** to read the test results and the current SKILL.md. The subagent will analyze the results and refine the frontmatter and trigger statements. Pass the subagent the instructions in [subagent.md](references/subagent.md).
4. **Repeat** — run the next batch of tests against the updated SKILL.md, evaluate, then call the subagent again. Continue until the stopping criteria are met.

## Running Tests

From the repo root:

```bash
cd tests
npm run test:integration -- <skill-name>
```

## Test Result Format

Each test result file in `<root>/.invocation-test-logs/` should be a JSON file:

```json
{
  "prompt": "the golden prompt text",
  "selectedSkill": "skill-name",
  "correct": true,
  "reasoning": "agent's explanation for why it chose this skill"
}
```

## Evaluation Log

The orchestrator writes `<root>/.eval-logs.json` — the only file the orchestrator edits. Schema:

```json
{
  "iterations": [
    {
      "iteration": 1,
      "score": 0.6,
      "totalPrompts": 5,
      "correctSelections": 3,
      "baseline": true
    }
  ]
}
```

## Stopping Criteria

Stop when either condition is met:

- The activation percentage has improved significantly and the target skill is consistently selected for relevant prompts.
- Multiple successive frontmatter iterations produce no measurable improvement, suggesting the root cause lies outside the frontmatter (e.g., skill overlap at the feature level, routing logic, or other systemic factors).

Finally, output the metrics for both baseline and the optimised versions.
