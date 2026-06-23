# Workflow Engine: Tables & Scoring (runtime-agnostic)

Decision tables, credibility tiers, confidence scoring, invariants, the common error matrix, and the memory schema for the meta-code pipeline. For pipeline logic see [SKILL.md](../SKILL.md); for execution primitives (dispatch, docs tool, memory path, runtime-specific error cases) see your adapter in [`../adapters/`](../adapters/).

These are reference tables, not a script. The model chooses the path, use them to calibrate effort and to verify, not to march through mechanically.

## Classification

Assign the **highest matching level** across all dimensions.

| Dimension | simple | moderate | complex |
|-----------|--------|----------|---------|
| Concepts | 1 | 2–3 | 4+ |
| Hops | 1 (direct answer) | 2 (lookup + apply) | 3+ (multi-hop) |
| Scope | Single library/API | Component/feature | Cross-cutting / architectural |
| Decision | Factual | How-to with context | Trade-off analysis |

## Behavior by level

Described in terms of *what runs*, not which primitive. The adapter maps "web pass", "explore", "docs", "challenge", "evaluator" to concrete dispatch.

| Level | Web | Codebase / docs | Challenge | Evaluator | Refinement | Fan-out |
|-------|-----|-----------------|-----------|-----------|------------|---------|
| `simple` | 1 broad search; early-exit common | only if a library/codebase is clearly in play | Never | Never | Never | None |
| `moderate` | retrieval-budgeted | if codebase exists or a library matters | only if contested claims / low confidence | No (self-check) | Max 1 if completeness <0.75 | None |
| `complex` | supportive + deliberate critical pass | codebase read + official docs | Always | Yes (independent) | Max 1, or max 2 if completeness <0.5 | Optional: critical pass and/or skeptic in parallel |

**Early-exit (skip codebase/docs → synthesis):** web coverage high, all `must_answer` met by T1–T2, no library needs docs, no local code bears on the question. Exception: `must_include` has `code_example` and a codebase exists → always read the code.

### Simple fast-path

For `simple` queries that trigger early-exit:
- **Gate**: skip the boundary check and route detection; only compress + early-exit check.
- **Synthesize**: run the **lite path**: `5d` (citation-first generation) + `5h` (citation audit) only. Skip 5a-5c (nothing to reconcile with a single source) and 5e-5g (collapse into one inline `medium`/`high` rating). The citation audit is load-bearing and NEVER skipped, it is the only sourcing guarantee on the fast-path, since Verify is skipped.
- **Verify**: skip entirely → straight to Output. Sourcing integrity (INV-1) is carried by the 5h audit.

Reduces simple queries to: 0 → 1 → 2 → 3(fast) → 5(lite) → 9.

## Decomposition (moderate / complex)

Keep it lightweight. Moderate: list 2–4 sub-questions, tag each with target evidence source (web / codebase / docs) and whether entities are known or must be retrieved. Complex: list the atomic claims the answer must establish + a **sufficiency check** (after each retrieval round, ask whether accumulated evidence satisfies the open claims; halt when it does, prevents drift). Per sub-question, you may override the global `source_priority` (API/config → `product`; trade-offs/architecture → `architecture`; benchmarks/research → `academic`).

## Source credibility tiers

| Tier | Weight | Examples |
|------|--------|----------|
| T1 | 1.0 | Official docs, RFCs, specs, primary research papers |
| T2 | 0.7 | Engineering blogs (major companies), reputable tech media |
| T3 | 0.4 | Community blogs, Stack Overflow, forum answers |
| T4 | 0.2 | AI-generated content, SEO-optimized articles |

**Priority by query type:** `product` (default) → T1 docs > T2 blogs > T1 papers > T3. `academic` → T1 papers > T1 docs > T2 > T3. `architecture` → T2 blogs > T1 docs > codebase patterns > T1 papers.

**Calibration correction** (web tools are systematically over-confident, retrieved text superficially resembles correct info):
- Web-only claim, no docs/codebase corroboration → treat one tier below apparent confidence.
- Corroborated by docs or codebase → keep stated confidence.
- T3–T4 only → flag `needs verification`.

## Confidence scoring

Two dimensions.

**Trajectory** (were the right sources used?): coverage of `must_answer` (high weight), search depth per finding, cross-source convergence, whether any evidence source failed (negative), whether refinement was needed (negative), coordination gaps detected at 2z/4z (negative).

**Response** (is the content correct?): count of concordant 2+-source claims (high), T1–T2 share (high), source diversity (high), recency (medium), survived challenge (medium), unresolved contradictions (negative), niche-topic indicator (negative).

**Source diversity** = `unique_domains / total_sources`. `< 0.5` → downgrade response confidence one level (4 sources from one docs domain = clustering, not corroboration).

**Niche-topic cap (Dunning-Kruger correction):** if fewer than 3 T1–T2 sources were found across all evidence combined, cap overall confidence at `medium` regardless of other signals, and note "limited authoritative sources available."

**Combined level:**

| Level | Criteria |
|-------|----------|
| `high` | 3+ concordant T1–T2 sources, no unresolved contradictions, full coverage, survived challenge |
| `medium` | 2 sources or mixed tiers, minor gaps, some claims weakened by challenge |
| `low` | Single source, significant gaps, unresolved contradictions, or refuted claims |

Output: `**Confidence:** {level} (trajectory: {t}, response: {r}): {basis}`.

## Completeness (verify step)

```
completeness = 0.35*question_coverage + 0.25*source_backing + 0.20*actionability
             + 0.10*coherence + 0.10*noise_ratio
```

| Component | 1.0 | 0.5 | 0.0 |
|-----------|-----|-----|-----|
| question_coverage | all `must_answer` met | most | major items missing |
| source_backing | all claims cited | most | many unsourced |
| actionability | all `must_include` present | some | none |
| coherence | consistent, contradictions surfaced | minor issues | internal contradictions |
| noise_ratio | all claims map to `must_answer` | some tangential | many off-topic |

Threshold **0.75**. Below it → one targeted refinement pass (unless simple). `noise_ratio = on_topic_claims / total_claims`: 1.0 if ≥0.9, 0.5 if ≥0.7, else 0.0, flag tangential claims for removal if noise >30%.

## Invariants (verify step)

| # | Invariant | Severity |
|---|-----------|----------|
| INV-1 | Every factual claim has a traceable source (URL / `file:line` / doc ID from a tool result) | Critical |
| INV-2 | Every `must_answer` item has a response | Critical |
| INV-3 | No T3–T4-only claim without a `needs verification` flag | Major |
| INV-4 | Time-sensitive claims ("latest", "current", "best practice") cite current/previous-year sources | Major |
| INV-5 | All `must_include` items present (code_example / version_info / trade_offs as specified) | Major |
| INV-6 | If `how_to` + codebase exists: referenced imports, functions, and framework versions actually exist in the local tree | Minor |
| INV-7 | No evidence source's findings silently dropped | Minor |
| INV-8 | Per-claim grounding: each individual factual claim maps to a source | Major |

Critical failure → always refine. Major failure → refine if completeness <0.75. Minor → note as a warning in output, don't refine.

## Codebase & library detection

**Codebase exists** if `.git` is present, or a manifest in cwd: `Cargo.toml`, `package.json`, `pyproject.toml`, `go.mod`, `pom.xml`, `build.gradle`, `*.sln`, `composer.json`, `mix.exs`, `deno.json`. No codebase + conceptual question → skip grounding.

**Library extraction:** read the manifest for dependency versions; pick the top 1–2 libraries most relevant to the question for a docs lookup. Don't fan out across every dependency.

## Common error matrix

Runtime-agnostic failures. Runtime-specific cases (e.g. Exa unreachable, ctx7 quota) are in the adapters.

| Scenario | Action |
|----------|--------|
| Web search returns empty | Proceed; note "web research yielded no results." Still ground in code if relevant. |
| Web search times out | Proceed with empty research context; note the timeout. |
| Boundary check fails | Note gaps; pass them to Step 4 as specific targets. |
| Early-exit triggers | Skip Step 4 → synthesis with web research only. |
| Codebase read finds nothing relevant | Report "no relevant codebase findings." |
| Docs lookup fails | Report "documentation unavailable"; rely on web. |
| Docs lookup returns empty | Report "no documentation found for {library}." |
| Spawned sub-agent fails / times out | Use the inline/partial result; note partial coverage. |
| Challenge returns empty | Proceed; note claims unchallenged in the confidence basis. |
| Evaluator fails (complex) | Fall back to orchestrator self-check; note in confidence basis. |
| Refinement changes <5% | Stop; report remaining gaps honestly. |
| No memory directory | Skip persistence. |
| Everything fails | Return what's available with an honest disclaimer. |

## Memory schema (output step)

Persist only novel, reusable, medium+-confidence findings (moderate/complex). One fact per file + an index line, following the host runtime's memory convention. *The concrete memory directory is runtime-specific, see your adapter.*

```yaml
---
name: research-{topic-slug}
description: "{one-line summary}"
type: reference
query_strategies:
  effective: ["{search pattern that surfaced T1 results}"]
  ineffective: ["{pattern that returned noise}"]
reliable_sources: ["{domain that consistently gave T1–T2}"]
pipeline:
  complexity: simple|moderate|complex
  early_exit: true|false
  challenge_run: true|false
  refinement_needed: true|false
  completeness: 0.0–1.0
  confidence: high|medium|low
---

{the finding, conclusion first, with sources}
```

Before writing, check for an existing memory on the same topic and update it rather than duplicating.
