---
name: meta-code
description: "Adaptive research pipeline that answers development questions by triangulating web search, the local codebase, and official docs into one grounded, cited answer with a confidence rating. Use when the user says 'meta-code', '/meta-code', 'research and answer', 'deep research', 'full analysis', or 'comprehensive answer'. Skip for trivial single-fact questions answerable directly. Runtime-agnostic core: load the adapter for your runtime before executing."
argument-hint: "[question or topic to research]"
model: opus
---

# meta-code: Adaptive Research Pipeline (runtime-agnostic core)

This file is the **shared core**: the logic, decision rules, and quality controls that hold regardless of which agent runtime executes them. It deliberately does NOT name execution primitives (how to dispatch a sub-agent, which docs tool to call, where memory lives). Those differ per runtime and live in adapters.

## Runtime adapter: read this first

Before executing, load the adapter for your runtime. It maps each pipeline step to concrete primitives (agent dispatch, docs lookup, codebase reading, memory path):

- **Claude Code** → [`adapters/claude.md`](adapters/claude.md) (typed `subagent_type` dispatch, ctx7 for docs, `_shared` references). Full prompt templates in [`adapters/claude-agent-protocols.md`](adapters/claude-agent-protocols.md).
- **Codex / gpt-5.5** → [`adapters/codex.md`](adapters/codex.md) (inline work by default, Exa MCP + `openai-docs` skill, prompt-driven fan-out, `~/.codex/memories/`).

When the core says "run web research" or "spawn a challenge reviewer", the adapter tells you *how*. The core tells you *what* and *why*, and which controls are non-negotiable.

## Operating Philosophy

Read this before the pipeline, it governs how the steps below are applied.

**Outcome over process.** The steps are decision rules, not a script to march through. Pick the shortest path that clears the Step 1 success criteria. A `simple` query may touch three steps; only a `complex` one earns the full machinery. Running every sub-step on every query is the failure mode this pipeline is designed to avoid, it burns tokens and degrades judgment into ritual.

**Scale effort to the query.** Classification (Step 1a) sets the ceiling: `simple` → minimal, no fan-out; `moderate` → web + conditional explore/docs + self-check; `complex` → full pipeline with an independent evaluator. Never run a heavier topology than the query warrants (behavior-by-level table in [references/workflow-engine.md](references/workflow-engine.md)).

**Don't over-explore.** Stop when the success criteria are met, not when the pipeline is "fully executed." A retrieval or refinement pass that adds <5% is noise, cut it.

**Reserve absolutes.** ALWAYS/NEVER apply only to the load-bearing controls below. Everything else, when to decompose, when to spawn a second agent, how many passes synthesis takes, is a judgment call. Use the decision rules, not blanket commands.

### Load-bearing controls (non-negotiable: never traded for brevity)

These are the substance, not the ceremony. They hold on every query that reaches their step, in every runtime:

1. **Every factual claim carries a traceable source** (URL / `file:line` / doc ID from a tool result). Never fabricate one. (INV-1, Step 5h Citation Audit)
2. **Contradictions are surfaced with both sources, never silently resolved.** (Step 5b)
3. **Generator-evaluator separation** on complex queries: the synthesizer never grades its own work. (Step 7d)
4. **Anti-sycophancy** on refinement: gap + sources only, never the draft; hard-reset framing. (Step 8)
5. **Confidence calibration**: web-only claims drop one tier; niche-topic cap holds confidence at `medium` under 3 T1–T2 sources. (Step 5f)
6. **Delegation depth = 1.** Sub-agents never spawn sub-agents. Gaps return to the orchestrator.

Everything not in this list is a decision rule, apply what the query needs, skip what it doesn't.

## Pipeline

`TRIAGE → ANALYZE → RESEARCH → GATE → PARALLEL → SYNTHESIZE → CHALLENGE (cond.) → VERIFY → REFINE (cond.) → OUTPUT`

Steps 0-9. Print a `[Step N/9]` header for each step you actually run, a simple query won't print all ten. Scale headers to the path taken; don't fake the full march.

### Step 0: TRIAGE (orchestrator only)

- **0a. Ambiguity.** Count unstated dimensions (technology, version, context, scope, constraints). If 3+ are unstated, infer the likeliest from codebase manifests, cwd context, and the query itself. Log inferences visibly. Never interrogate the user.
- **0b. Trivial fast-path.** Single-hop fact with one unambiguous answer → answer directly from knowledge, flag `trivial_bypass`, skip the rest.

### Step 1: ANALYZE (orchestrator only)

- **1a. Classify** complexity (simple / moderate / complex): highest matching level across all dimensions (matrix in workflow-engine.md).
- **1b. Success criteria**: fix the bar before researching:
  ```
  expected_output_type: factual_answer | comparison | architecture_decision | how_to
  must_answer:   [the questions the final answer MUST resolve]
  must_include:  [code_example | version_info | trade_offs, only those the query needs]
  source_priority: product | academic | architecture
  ```
  These become the Step 7 checklist. Every `must_answer` must map to ≥1 piece of evidence.
- **1c. Decompose** (moderate/complex). Moderate: 2–4 sub-questions, each tagged with target evidence source + known/unknown entities. Complex: atomic claims + a sufficiency check (halt retrieval once accumulated evidence satisfies open claims).
- **1d. Reformulate** (moderate/complex). Rewrite into one self-contained canonical research question: assumptions explicit, scope bounded, output type named. Skip for simple.
- **1e. Enrich** (all levels). Turn the canonical question into actionable per-source instructions referencing the `must_answer` items they serve.
- **1f. Plan answer shape** (complex only). Outline the 2–4 sections the answer needs before dispatching.
- **1g. Validate plan.** Every `must_answer` maps to an instruction; no redundant overlapping work; no dependency cycles.

### Step 2: RESEARCH (web first)

Always runs first (unless trivial bypass). Apply the **retrieval budget**: one broad search with discriminative keywords; search again only when a `must_answer` is unmet, a required fact/version/date is absent, the user asked for exhaustive coverage, or the answer would otherwise carry an unsupported claim. Do NOT re-search to polish phrasing.

- Simple/moderate: one web pass with the dual-perspective protocol (for each top-3 finding, one `"{finding}" limitations OR problems OR alternatives` search).
- Complex: a supportive pass AND a deliberate critical pass (limitations / alternatives / deprecations). Report both supporting and challenging evidence, never only confirm.

*Dispatch primitive: see adapter.*

**2z. Output structure check (MAST).** Verify each return contains all requested sections, addresses its assigned sub-questions, and stays within budget. Log any `coordination_gap` and carry it to Step 3 rather than discovering it at Step 7.

### Step 3: GATE (orchestrator only)

- **3a. Compress** Step 2 output into a structured handoff (claims with source+tier+date, libraries, contradictions, gaps, coverage): NOT prose. Merge multiple research passes, noting convergence/divergence.
- **3b. Boundary check.** Coverage of sub-questions, completion-signal validity, intent preservation. Note gaps for Step 4.
- **3c. Route.** Codebase present? (`.git` or a manifest in cwd → yes.) Libraries in play needing docs? Set which Step-4 work to run.
- **3d. Early-exit.** Skip Step 4 → straight to synthesis when: web coverage is high, all `must_answer` met by T1–T2, no library needs docs, and no local code bears on the question. Exception: `must_include` has `code_example` and a codebase exists → always read the code.

### Step 4: PARALLEL (EXPLORE + DOCUMENT)

Run only what 3c flagged, concurrently where the runtime allows.

- **EXPLORE** the codebase: relevant functions, types, handlers, conventions, partial implementations, dependency versions. Cite every finding as `file:line`. Targeted, not a full scan.
- **DOCUMENT**: pull official docs for the top 1–2 relevant libraries. Exact signatures, version-specific behavior, deprecations, official examples. Prefer T1 (official) over T2.

*Codebase-reading and docs primitives: see adapter.*

**4z. Output structure check (MAST).** Same as 2z, for Step 4 returns.

### Step 5: SYNTHESIZE

Sub-tasks run in dependency order, compress before you generate, calibrate after. This is an **ordering, not a mandatory march**: scale to how many sources contributed. A single-source `simple` result runs the **lite path**: `5d` + `5h` only.

**Compress & merge (multi-source only, skip if one source contributed).**
- **5a.** Compress each source's output (~300-500 tok/source).
- **5b. Conflict resolution** *(load-bearing, never skipped when sources disagree).* Tier order: official docs > web > codebase pattern. Intentional codebase deviation → note both. 2/3 concordant = corroborated, else contested. NEVER silently resolve a contradiction, list each position with its source under `Contested Claims`.
- **5c. Coverage check.** Each active source's output is represented, or its exclusion is stated.

**Generate citation-first (always).**
- **5d.** Every claim cites its source inline as you write it, never claims-first, sources-after.
- **5e.** Weight claims by source tier (workflow-engine.md: T1=1.0 … T4=0.2).

**Calibrate & audit (load-bearing, runs on every path above the simple lite path).**
- **5f. Calibration:** web-only → one tier down; source-diversity downgrade; niche-topic cap at `medium` under 3 T1–T2 sources.
- **5g. Confidence:** assign `high|medium|low` with basis (workflow-engine.md table).
- **5h. Citation audit** *(load-bearing, runs on every path, including lite):* segment into individual claims, map each to a tool-result URL, flag `[unsourced]`, verify no URL was fabricated.

### Step 6: CHALLENGE (signal-conditional)

- `simple` → always skip.
- `moderate` → only if contested claims exist or confidence is low.
- `complex` → always (high-stakes safety net).

Adversarial review of the 3–5 highest-impact claims by a fresh-context skeptic that sees ONLY the claims + sources, never the draft. Default stance: doubt; a single source is weak, not confirmed. Integrate: CONFIRMED → corroborated; WEAKENED → downgrade + nuance; REFUTED → remove or reframe and note the contradiction. Update synthesis before Step 7.

*Independent-reviewer vs inline-skeptic primitive: see adapter.*

### Step 7: VERIFY

- **7a. Completeness** against Step 1 criteria (formula in workflow-engine.md). Threshold 0.75.
- **7b. Invariants**: run the deterministic invariant list (INV-1…8 in workflow-engine.md). Critical failure → always refine; major → refine if completeness <0.75; minor → warn in output.
- **7c. Noise check**: claims not mapping to a `must_answer`; if >30%, flag for removal.
- **7d. Evaluator** *(complex only, generator-evaluator separation, load-bearing):* an independent reviewer that did NOT generate the synthesis grades it against the success criteria. Returns pass/fail per `must_answer`, gaps, recommendation. Simple/moderate use an orchestrator self-check instead.

Decision: simple → skip to Step 9; completeness ≥0.75 and no critical invariant failure → Step 9; else → Step 8.

### Step 8: REFINE (conditional, gap-only)

Never for simple. Max 1 iteration (moderate), max 2 (complex with completeness <0.5). Stop if a pass changes <5%, report remaining gaps honestly rather than loop.

**Anti-sycophancy (load-bearing):** the refinement agent receives the **gap description + relevant sources only, never the draft**, with a hard-reset framing and claims anonymized (sources withheld) so it evaluates on substance. It returns independent findings; the orchestrator merges them. Spawn only agents whose domain matches the gap.

### Step 9: OUTPUT

Deliver using [references/output-format.md](references/output-format.md): conclusion first, citation-first, contradictions surfaced, confidence rated.

**Persist** (moderate/complex, only if novel + reusable + medium+ confidence): write a research memo and update the memory index. *Memory path + schema: see adapter and workflow-engine.md.*

## Hard Rules

1. **Delegation depth = 1.** Sub-agents never spawn sub-agents; gaps return to the orchestrator.
2. **Generator-evaluator separation** (complex): Step 7 uses an independent evaluator; the orchestrator does not grade its own synthesis.
3. **Anti-sycophancy** (refine): gap + sources only, never the draft; hard-reset; claims anonymized before authority reveal.
4. **Refinement cap**: max 1 (moderate) / 2 (complex, completeness <0.5); never simple; stop at <5% change.
5. **Graceful degradation**: any source fails → continue with available data and note the gap. All fail → deliver what exists with an honest disclaimer.
6. **Selective persistence**: novel, reusable, medium+ confidence only.
7. **Read-only by default**: this pipeline researches and answers; it does not modify files unless the user asked for an implementation.
8. **Third-person evidence framing**: "web research found X" / "the codebase shows Y", never "I found X", keeps spawned agents from misattributing prior findings.

## References

- [Workflow Engine](references/workflow-engine.md): classification matrix, behavior-by-level, credibility tiers + calibration, confidence scoring, completeness formula, invariant list, codebase detection, common error matrix, memory schema.
- [Output Format](references/output-format.md): answer template + confidence-line format + flags.
- [Bibliography](references/bibliography.md) / [extended](references/bibliography-extended.md): research grounding for the pipeline's design choices.
- Adapters: [Claude Code](adapters/claude.md) · [Codex](adapters/codex.md).
