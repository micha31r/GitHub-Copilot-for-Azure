# Insight Pipeline Experiment Findings

## Background

The infra-planner skill generates "insights" — patterns mined from a customer's existing Azure infrastructure that inform downstream infrastructure planning. Three pipeline approaches were built and compared:

- **Baseline (C)**: Property counts only → LLM
- **Itemset (B)**: Property counts + FP-Growth Maximal Frequent Itemsets (MFIs) → LLM
- **BM25 (A)**: Query-conditioned retrieval + pre-digested claims → LLM

Initial comparison showed an unexpected result: the baseline (property counts only) produced higher-quality insights than the itemset approach (which adds co-occurrence data). This experiment suite was designed to understand why.

**Test query**: "Internal web app for the finance team with a relational database backend"

## Hypotheses

| ID | Hypothesis | Description |
|---|---|---|
| H1 | Attention dilution | 76 MFIs add ~19K chars, reducing depth on property aggregations |
| H2 | Prompt steering | The itemset prompt's "Analyze MFIs" / "Cross-reference both" instructions redirect the model toward generic MFI-derived insights |
| H3 | Slot competition | ~8 insight slots are zero-sum; MFI insights crowd out property-deep ones |
| H4 | MFI signal redundancy | MFIs state obvious co-occurrences (NSG+VNet) the LLM already knows |
| H5 | Context pressure | 67K chars vs 49K may degrade recall on specific property details |

## Experiments

| Experiment | Data | Prompt | Tests |
|---|---|---|---|
| Exp1: Prompt ablation | Itemset (property counts + MFIs) | Baseline (no MFI instructions) | H2 |
| Exp2: Data ablation | Baseline (property counts only) | Itemset (MFI instructions) | H1 vs H2 |
| Exp3: Filtered MFIs | Property counts + medium+ MFIs only | Itemset | H4 |
| Exp4: More insights | Property counts + all MFIs | Itemset (request ~15 insights) | H3 |
| Exp5: Two-pass | Pass 1: property counts → insights; Pass 2: MFIs + Pass 1 → supplementary | Baseline (pass 1), MFI-supplement (pass 2) | H3 + H5 |

## Evaluation Method

Each experiment output was compared pairwise against the baseline using an LLM evaluator. To control for positional bias, every comparison was run twice with A/B order swapped. All 4 pairwise verdicts were consistent across both orderings.

## Results

### Rankings

| Rank | Approach | Key Strengths | Key Weaknesses |
|---|---|---|---|
| 1 | **Exp1** (MFI data + baseline prompt) | Best factual grounding, surfaces region/monitoring/subnet/RBAC detail that baseline misses, correctly identifies KV purge protection gap (8.9%) | Misses TLS and backup (addressable via prompt tuning) |
| 2 | **Exp5** (two-pass) | Broadest coverage (15 insights), MFI supplement adds certificate lifecycle and ILB guidance | 2 of 4 MFI supplementary insights are redundant with pass 1 |
| 3 | **Baseline** (property counts only) | Concise, non-redundant, covers backup/DR and TLS | Misses monitoring, subnet topology, region selection |
| 4 | **Exp3** (filtered MFIs) | Good coherence, quantitative grounding | Some redundancy (#3/#9 overlap on private endpoints) |
| 5 | **Itemset** (full MFIs + itemset prompt) | Rich statistical detail | Redundancy (#1/#9), misses backup/DR entirely |
| 6 | **Exp4** (15 insights requested) | Surfaces 4 unique insights others miss | Severe redundancy (~4 recycled), tangential content (containers, IP SKUs) |

### Hypothesis Outcomes

| Hypothesis | Verdict | Evidence |
|---|---|---|
| **H2: Prompt steering** | ✅ Confirmed | Exp1 (MFI data + baseline prompt) ranked #1. The model voluntarily extracts useful MFI signal when not forced to dedicate insights to it. The itemset prompt's explicit "Analyze MFIs" instruction is the primary cause of quality loss. |
| **H4: MFI signal redundancy** | ⚠️ Partially confirmed | Exp3 (filtered MFIs) improved over full itemset but still didn't beat baseline. Low-reliability MFIs add noise, but even high-reliability ones state Azure-101 co-occurrences. |
| **H3: Slot competition** | ⚠️ Partially confirmed | Exp4 (more slots) didn't help — diluted quality. But Exp5 (two-pass) worked by separating concerns, suggesting the bottleneck is attention allocation, not hard slot limits. |
| **H1: Attention dilution** | Inconclusive | Exp1 performed well despite 67K char payload. Context size alone doesn't explain the gap. |
| **H5: Context pressure** | Inconclusive | Exp5's two-pass worked, but Exp1 also worked with a single pass at full payload size. |

### Factual Accuracy Issue

A notable finding: the baseline consistently claims Key Vaults "uniformly enable purge protection." Verified against raw data:

- 169 Key Vaults total
- `enablePurgeProtection: True` → **15 vaults (8.9%)**
- `enablePurgeProtection: None` → **154 vaults (91.1%)**

The baseline LLM hallucinated this claim — likely confusing `enableSoftDelete` (~98.8% True) with `enablePurgeProtection`. Exp1 and Exp5 correctly reported the 8.9% figure because their prompts didn't push the model toward confirmatory patterns.

## Key Findings

### 1. The prompt matters more than the data

The same MFI data produces better insights with the baseline prompt (4-step: analyze properties → identify relevant types → include tenant-wide → re-examine) than with the itemset prompt (5-step: adds "Analyze MFIs" and "Cross-reference both"). The explicit instruction to analyze MFIs causes the model to:
- Allocate insight slots to generic co-occurrence observations
- Produce redundant insights (e.g., two separate "use private endpoints" insights)
- Miss coverage areas that property data supports (backup, TLS, region)

### 2. More data doesn't hurt — forced analysis of that data does

Exp1 proves MFI data in the payload is not toxic. The model can see it and optionally use it. The problem is when the prompt *mandates* MFI analysis, forcing the model to produce insights from a data type that is inherently less information-dense than property aggregations.

### 3. More insights ≠ better insights

Exp4 (requesting ~15 insights) produced the worst signal-to-noise ratio: ~4 recycled insights, tangential topics (container registry, public IP SKUs), and vaguer claims. Quality scales inversely with forced quantity.

### 4. Two-pass has potential but needs dedup

Exp5's separation of concerns works conceptually — pass 1 gets full attention on properties, pass 2 adds MFI-derived supplements. But 2 of 4 MFI supplements were redundant with pass 1. A production implementation would need automated deduplication.

### 5. MFIs add marginal value in specific areas

Across all experiments, MFI data contributed exactly two insights that property counts alone couldn't produce:
- **Certificate lifecycle management**: App Service Certificates co-deployed with private DNS (automated renewals)
- **ILB vs public Application Gateway**: Explicit recommendation to choose internal load balancer variant

These are useful but narrow. The 76 MFIs mined from 489 transactions mostly restate Azure deployment 101.

## Recommendation

**Use the baseline-style prompt with MFI data available in the payload.** This corresponds to Exp1's design:

- Property counts + MFIs in the user message (same data as itemset)
- Baseline prompt (4-step process, no MFI-specific instructions)
- The LLM data format preamble should describe both `resourceContext` and `tenantPatterns` so the model understands the data, but the process instructions should not mandate MFI analysis

This approach ranked #1 across both evaluation orderings and avoids the prompt-steering problem while keeping MFI data accessible for the model to draw on when it adds genuine value.

## Files

| File | Description |
|---|---|
| `experiments/exp1_prompt_ablation.ipynb` | MFI data + baseline prompt |
| `experiments/exp2_data_ablation.ipynb` | Baseline data + itemset prompt |
| `experiments/exp3_filtered_mfis.ipynb` | Medium+ reliability MFIs only |
| `experiments/exp4_more_insights.ipynb` | Request ~15 insights |
| `experiments/exp5_two_pass.ipynb` | Two-pass: property → MFI supplement |
| `experiments/results/exp{1-5}_*.json` | Generated insight outputs |
| `insights_baseline.ipynb` | Baseline pipeline (property counts only) |
| `insights_itemset.ipynb` | Full itemset pipeline (property counts + MFIs) |
| `insights_bm25.ipynb` | BM25 retrieval pipeline |
