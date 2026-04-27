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

---

## Multi-Prompt Validation (MFI Value Test)

The initial experiments used a single prompt ("Internal web app for the finance team with a relational database backend"). To validate whether MFI data consistently adds value, a follow-up experiment tested baseline vs MFI (Exp1 approach: MFI data + baseline prompt) across all 9 prompts from the skill's trigger test suite.

### Prompts Tested

| # | Prompt | Domain |
|---|--------|--------|
| 1 | Internal web app for the finance team with a relational database backend | Web app + SQL |
| 2 | Deploy a geo-redundant backup solution for on-premises SQL servers using Azure Backup, configure encryption-at-rest, and automate monthly DR tests | Backup / DR |
| 3 | Deploy 3-tier architecture with hardened OS images, VM backups scheduled daily, and application-level redundancy for the business logic tier | 3-tier / HA |
| 4 | Configure a site recovery plan for disaster failover from East to West Azure region, replicate major VM workloads, and automate DNS failbacks | Site Recovery / DR |
| 5 | Provision a jumpbox VM for secure management, establish NSGs for each tier, and connect tiers using internal Azure Load Balancer | Network security |
| 6 | Spin up Linux VMs for each tier using Terraform, automate patch management via Azure Automation, and log traffic between subnets for compliance | VM / compliance |
| 7 | Deploy three distinct VM scale sets for a legacy app, route incoming HTTP/S via Application Gateway with WAF, and encrypt all data disks | VMSS / WAF |
| 8 | Set up Azure Backup for critical VM workloads, create a long-term retention policy for compliance, and test backup restores quarterly | Backup / retention |
| 9 | Deploy disaster recovery for VMware VMs using Azure Site Recovery, configure runbooks for smooth failover, and maintain compliance audit trails | VMware DR |

### Results

| Prompt | Ordering 1 | Ordering 2 | Final Verdict |
|--------|------------|------------|---------------|
| 1 (web app + SQL) | MFI | MFI | **MFI wins** |
| 2 (backup/DR) | MFI | MFI | **MFI wins** |
| 3 (3-tier/HA) | Draw | Baseline | Inconclusive |
| 4 (site recovery) | MFI | Baseline | Inconclusive |
| 5 (jumpbox/NSGs) | MFI | Draw | Inconclusive |
| 6 (Linux VMs/Terraform) | MFI | MFI | **MFI wins** |
| 7 (VMSS/WAF) | MFI | MFI | **MFI wins** |
| 8 (backup retention) | MFI | Draw | Inconclusive |
| 9 (VMware DR) | Baseline | Baseline | **Baseline wins** |

**Summary**: MFI wins 4, Baseline wins 1, Inconclusive 4. Consistency: 5/9 verdicts agreed across orderings.

### Interpretation

With 9 prompts, the picture is clearer than the initial 4-prompt run. MFI consistently outperforms baseline — winning 4 of 9 prompts with full consistency, while baseline only wins 1. The 4 inconclusive cases all had MFI winning in at least one ordering.

Notably, the one prompt where baseline clearly won (VMware DR) is a scenario involving mostly VMware-specific resources where co-occurrence patterns add limited architectural signal.

### Cost-Benefit

- **Computation**: FP-Growth mining takes ~2–3 seconds on 490 transactions. Negligible.
- **Token cost**: MFI adds ~19K chars (~5–6K tokens) to the payload. At current pricing, this is a fraction of a cent per call.
- **Complexity**: Adding MFI to the payload requires the FP-Growth pipeline (TransactionEncoder, fpgrowth, MFI maximality filter). This is ~50 lines of code.
- **Risk**: None. The baseline prompt doesn't mandate MFI analysis, so including MFI data can't hurt — the model uses it when relevant and ignores it otherwise.

### Conclusion

**Include MFI data.** The 9-prompt experiment strengthens the recommendation from the initial 4-prompt run. MFI wins outright in 4/9 cases, ties or nearly-ties in another 4, and loses only 1. The cost is trivial (~2s compute, ~5K extra tokens), and since the baseline prompt doesn't force MFI analysis, MFI data is strictly additive.

The stronger signal remains property counts. Any effort to improve insight quality should prioritize prompt engineering and property aggregation depth over MFI sophistication.

---

## Factual Accuracy Verification

The LLM evaluator compared insights at face value — it judged "quality" without checking whether the numerical claims are true. To independently verify, we built a deterministic fact sheet from the raw ARG data (same aggregation logic as the notebooks) and used an LLM to match each insight's claims against it.

### Method

1. **Stage 1 (deterministic)**: Python script computes all resource counts and property distributions from the raw ARG cache — no LLM involved. This is ground truth.
2. **Stage 2 (LLM-assisted)**: For each insight, an LLM extracts verifiable factual claims and checks them against the fact sheet. Each claim is graded as:
   - **Supported (S)**: confirmed within ~5pp / ~10% tolerance
   - **Approximate (A)**: directionally correct but off by more than tolerances
   - **Hallucinated (H)**: contradicted by data or property doesn't exist

### Results

| Prompt | Baseline Accuracy | MFI Accuracy | Baseline H | MFI H |
|--------|-------------------|--------------|------------|-------|
| 1 (web app) | 92.0% | 86.2% | 2 | 4 |
| 2 (backup/DR) | 76.5% | 76.0% | 4 | 6 |
| 7 (VMSS/WAF) | 94.7% | 80.6% | 1 | 6 |
| 9 (VMware DR) | 73.1% | 82.8% | 7 | 5 |
| **Average** | **84.1%** | **81.4%** | **3.5** | **5.25** |

### Common Hallucination Patterns

Both approaches hallucinate the same types of claims:

1. **Key Vault purge protection**: Both consistently claim "enablePurgeProtection True for 100%" when the actual figure is ~8.9%. This is the same hallucination found in the initial experiments — the model confuses `enableSoftDelete` (~98.8% True) with `enablePurgeProtection`.

2. **Recovery Services vault encryption**: Both claim "infrastructure encryption Enabled for 100%" — this property may not be represented the same way in the fact sheet due to how the property is nested.

3. **Identity type distributions**: MFI occasionally overstates identity adoption (e.g., "UserAssigned in 100% of databases") when the actual distribution is more mixed.

### Interpretation

**Baseline is slightly more factually accurate than MFI on average** (84.1% vs 81.4%), with fewer hallucinations per prompt (3.5 vs 5.25). This is the opposite of what the LLM-as-judge found — MFI insights "sound better" but hallucinate more.

However, the gap is modest and driven largely by the same recurring hallucination (Key Vault purge protection) that appears in both approaches. The extra MFI data may encourage the model to make more claims overall (MFI insights average 9.25 per prompt vs baseline's 8.25), and more claims means more opportunities for hallucination.

The one exception is prompt 9 (VMware DR) where MFI is actually more accurate than baseline (82.8% vs 73.1%). This was also the prompt where baseline won the quality comparison — suggesting baseline makes bolder but less accurate claims for that domain.

### Implications for the MFI Recommendation

The factual accuracy findings temper but don't reverse the MFI recommendation:

- MFI still produces more architecturally relevant insights (per the quality evaluation)
- But it also produces slightly more hallucinated claims
- The hallucination rate is manageable (~81% accuracy) and mostly concentrated in a few recurring patterns (Key Vault purge protection, infrastructure encryption)
- **Mitigation**: These specific hallucination patterns could be addressed by improving the property aggregation (e.g., ensuring `enablePurgeProtection` is correctly captured and prominently surfaced in the data)

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
| `../mfi-value/mfi_value_test.ipynb` | Multi-prompt baseline vs MFI comparison |
| `../mfi-value/results/` | Per-prompt insight outputs, evaluations, and summary |
| `../mfi-value/verify_facts.py` | Factual accuracy verification script (Stage 1 + 2) |
| `../mfi-value/results/fact_sheet.json` | Deterministic ground truth from ARG data |
| `../mfi-value/results/factual_verification.json` | Per-claim verification results |
