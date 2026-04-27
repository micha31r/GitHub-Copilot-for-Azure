# Insight Data Processing Experiments

Experiments comparing different approaches to generate Azure infrastructure insights from ARG (Azure Resource Graph) data.

## What are insights?

Insights are patterns mined from a customer's existing Azure infrastructure that inform downstream infrastructure planning. They answer: "given what this tenant already has deployed, what conventions should a new deployment follow?"

## Pipelines (base approaches)

| Notebook | Approach | Data to LLM |
|---|---|---|
| `baseline.ipynb` | Property counts only | Per-type property aggregations |
| `itemset.ipynb` | Property counts + FP-Growth MFIs | Property aggregations + co-occurrence patterns |
| `bm25.ipynb` | Query-conditioned BM25 retrieval | Pre-computed claims + exemplar RG |

## Experiments

| Notebook | What it tests | Key variable |
|---|---|---|
| `prompt_ablation.ipynb` | Does the prompt cause quality loss? | Itemset data + baseline prompt |
| `data_ablation.ipynb` | Does MFI data cause quality loss? | Baseline data + itemset prompt |
| `filtered_mfis.ipynb` | Does MFI noise matter? | Only medium+ reliability MFIs |
| `more_insights.ipynb` | Does slot competition matter? | Request ~15 insights |
| `two_pass.ipynb` | Does separation of concerns help? | Pass 1: properties → Pass 2: MFI supplement |

## Running

All notebooks use cached ARG data from `../../plugin/skills/azure-enterprise-infra-planner/scripts/arg_raw_output_all.json`. To regenerate the cache:

```bash
python plugin/skills/azure-enterprise-infra-planner/scripts/fetch_arg.py
```

Results are written to `results/<notebook_name>.json`.

## Adding new experiments

1. Create a new `.ipynb` in this directory
2. Use `../../plugin/skills/azure-enterprise-infra-planner/scripts/arg_raw_output_all.json` for ARG data
3. Write output to `results/<your_experiment_name>.json`
4. Document what you're testing in the notebook's first markdown cell

## Findings

See [FINDINGS.md](FINDINGS.md) for the full analysis report.
