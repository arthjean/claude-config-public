# Codex / gpt-5.5 adapter: meta-code

Read this **with** the core [SKILL.md](../SKILL.md). The core defines *what* each step does and which controls are load-bearing; this adapter maps each step to Codex primitives. There is **no typed sub-agent dispatch** and **no ctx7** in Codex, each evidence source maps to a real Codex primitive below.

## Operating rules (gpt-5.5)

gpt-5.5 degrades under over-specified process and contradictory instructions. The core's Operating Philosophy already encodes outcome-over-process; these are the gpt-5.5-specific reinforcements:

- **Preamble.** For any non-trivial run, before the first tool call emit one short user-visible line: acknowledge the question and name your first step. Skip it for trivial fast-path answers.
- **Verbosity low by default.** Prose over heavy structure, except where a comparison table or code block genuinely aids comprehension.
- **Do the work inline by default.** The model usually does web/codebase/docs work in one context. Reach for a spawned sub-agent only when two angles are genuinely independent enough that parallel execution adds real value (complex queries): not as a reflex.
- **Don't over-explore.** gpt-5.5 already explores thoroughly; do not add "be exhaustive / get the full picture" nudges. Stop when the success criteria are met.

## Dispatch model

| Pipeline role | Codex primitive | Notes |
|---------------|-----------------|-------|
| RESEARCH / CHALLENGE (web) | **Exa MCP** (`web_search_exa`, `web_fetch_exa`) | Configured in `~/.codex/config.toml` `[mcp_servers.exa]`. Call directly. |
| EXPLORE (codebase) | **Read files directly** (`rg`, read, glob) | No sub-agent. Cite `file:line`. Cap broad `rg` output. |
| DOCUMENT (official docs) | **Exa fetch** of primary docs + the **`openai-docs` skill** | `openai-docs` for OpenAI/Codex/model-API questions; Exa fetch for everything else. |
| Parallel fan-out (optional) | **Codex sub-agents**, prompt-driven | Complex queries only, independent angles. Bounded by `[agents] max_threads`, `max_depth = 1`. Spawn via natural language. |
| Step 9 memory | `~/.codex/memories/` | Native memories dir; one-fact-per-file + `MEMORY.md` index. |

## Web research: Exa MCP

Tools surface as native calls; no prompt needed to "introduce" them.

**Retrieval budget (stop rule, every run):** start with one broad search using short discriminative keywords. Search again only when a `must_answer` is unmet, a required fact/version/date/owner/URL is absent, the user asked for exhaustive coverage/comparison, or the answer would otherwise carry an unsupported claim. Do NOT re-search to improve phrasing or add nonessential examples.

**Dual-perspective (complex):** after the supportive pass, run one deliberate critical pass, `{topic} limitations`, `{topic} alternatives`, `{topic} deprecated`, `{topic} known issues`. Report both supporting and challenging evidence.

Per finding: record source URL + tier (T1–T4) + date. Include the current year in time-sensitive searches.

## Codebase: read files directly

Detect a codebase (`.git` or a manifest in cwd, list in [workflow-engine.md](../references/workflow-engine.md)). Read, don't scan: target functions, types, handlers, conventions, partial implementations, and dependency versions from the manifest. Cite every finding as `file:line`. When codebase practice diverges from web/docs recommendations, record both and flag whether the deviation looks intentional, don't assume the web is right.

## Official docs: Exa fetch + `openai-docs`

No ctx7. Two routes:
- **OpenAI / Codex / model-API questions** → the bundled **`openai-docs`** skill (wraps the OpenAI Developer Docs MCP; carries model-selection / migration / prompting references). Prefer it for anything about GPT-5.x behavior, the Responses API, Codex config, or model migration.
- **Any other library** → `web_fetch_exa` on the primary docs URL (resolve the canonical domain via `web_search_exa` first). Extract exact signatures, version-specific behavior, deprecations, official examples. Prefer T1 over T2.

Record the doc URL / source as the citation.

## Optional parallel fan-out: Codex sub-agents

Prompt-triggered, not a typed call. Governed by `[agents]` in `config.toml` (`max_threads` default 6; `max_depth = 1`). Use only for independent angles on complex queries. Canonical phrasing: *"Spawn one agent per {angle}, wait for all of them, then summarize the result for each."* Brief each agent block-structured with XML tags (gpt-5.5 prefers this over prose): one task, an output contract, explicit boundaries:

```
<task>Research the LIMITATIONS, problems, and alternatives for: {canonical_question}.
You are the critical-angle pass; another agent covers best practices, do not duplicate it.</task>
<done_criteria>Address each: {must_answer items relevant to risks}. Note any you cannot as a gap.</done_criteria>
<retrieval_budget>One broad search per angle; re-search only to fill a named gap. Max ~6 searches.</retrieval_budget>
<output_contract>
Return ≤ ~1000 tokens, third-person framing:
- Limitations & problems (most impactful first, each with source + tier)
- Alternatives with trade-offs
- Deprecations / breaking changes (or "none found")
- Sources (URL + tier T1–T4)
</output_contract>
<boundaries>Web only, do not read local files, do not modify anything, do not spawn further agents.</boundaries>
```

## Challenge (Step 6): skeptic pass

- **Inline fresh-context (default):** mentally reset, evaluate the 3–5 claims as a skeptic who has not seen your draft. Default stance is doubt; a single source is weak; "no counter-evidence after a focused search" = confirmed, not before.
- **Spawned skeptic sub-agent (stronger, complex only):** give it ONLY the claims + sources, never the draft:

```
<task>You are an independent skeptical reviewer. Challenge each claim below by searching for
counter-evidence, known limitations, and recency problems. Default stance: doubt.</task>
<claims>{3–5 highest-impact claims, each with its cited source}</claims>
<rules>A single source is WEAK, not confirmed. Do not soften verdicts. You have NOT seen any draft.</rules>
<output_contract>Per claim: CONFIRMED | WEAKENED, {detail|source} | REFUTED, {detail|source}. Then a 1–3 sentence overall assessment.</output_contract>
<boundaries>Web only. No local files. No further agents.</boundaries>
```

Integrate: CONFIRMED → corroborated; WEAKENED → downgrade + nuance; REFUTED → remove/reframe + note contradiction. Update synthesis before Verify.

## Refinement (Step 8)

Fill only the gap, don't re-run the pipeline. Anti-sycophancy: work from the gap description + a quality bar, not from your own draft. Max 1 (moderate) / 2 (complex, weak coverage). Stop if a pass changes <5%.

## Runtime-specific error cases

| Scenario | Action |
|----------|--------|
| Exa search returns empty | Proceed; note "web research yielded no results." Still ground in code if relevant. |
| Exa MCP unavailable / not initialized | Confirm `enabled = true` under `[mcp_servers.exa]`; note `degraded: exa unavailable`; fall back to model knowledge with lowered confidence (see openai/codex#3441). |
| `openai-docs` / Exa fetch fails | Report "documentation unavailable"; rely on web. |
| Spawned sub-agent fails / times out | Use the inline result instead; note partial coverage. |
| No `~/.codex/memories/` dir | Skip persistence. |
