# Workflow

## Mandatory Rules

- You must execute the seven stages in sequential order. Follow the instructions precisely as defined. Do not continue to the next phase until the current phase is complete.
- You must stop on all "gate" conditions and only continue when the conditions have been met.
- Destructive actions require explicit user confirmation.
- You must read each phase's reference file in full before executing it.

## Overview

Start with Phase 1, once the subagent has been created, you can run Phase 2 in parallel.

However, you must wait for both Phase 1 and 2 to be complete before moving onto Phase 3, and all subsequent phases must be executed in sequence.

| Phase | Action | Reference | Key Gate |
|-------|--------|-----------|----------|
| 1 | Extract insights | [1-extract-insights.md](phases/1-extract-insights.md) | Insights written to `.azure/insights.json` |
| 2 | Research best practices | [2-research-best-practices.md](phases/2-research-best-practices.md) | All MCP tool calls complete and WAF guides summarized |
| 3 | Research resources | [3-research-resources.md](phases/3-research-resources.md) | All resources have ARM type, naming rules, and pairing constraints; user approves resource list |
| 4 | Generate plan | [4-generate-plan.md](phases/4-generate-plan.md) | Plan JSON written to disk |
| 5 | Verify plan | [5-verify.md](phases/5-verify.md) | All checks pass, user approves |
| 6 | Generate IaC | [6-generate-iac.md](phases/6-generate-iac.md) | All IaC files generated and saved to disk |
| 7 | Deploy to Azure | [7-deploy.md](phases/7-deploy.md) | User confirms destructive actions |
