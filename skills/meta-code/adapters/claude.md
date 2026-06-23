# Claude Code adapter: meta-code

Read this **with** the core [SKILL.md](../SKILL.md). The core defines *what* each step does and which controls are load-bearing; this adapter maps each step to Claude Code execution primitives. Full prompt templates live in [`claude-agent-protocols.md`](claude-agent-protocols.md).

## Dispatch model

Claude Code spawns sub-agents with the **Agent tool**, typed via `subagent_type`. Use simple per-agent spawning, never `TeamCreate`. Launch independent agents in a **single message** for parallel execution. Sub-agents return condensed summaries (budget below) to the orchestrator; depth = 1 (a sub-agent never spawns another).

| Pipeline role | `subagent_type` | Notes |
|---------------|-----------------|-------|
| RESEARCH / CHALLENGE (web) | `agent-websearch` | Exa MCP tools; falls back to native WebSearch/WebFetch. |
| EXPLORE (codebase) | `agent-explore` | Read-only; cite `file:line`. |
| DOCUMENT (official docs) | `agent-docs` | ctx7 CLI two-step protocol (below). |
| Step 7d evaluator | `general-purpose` | Receives criteria + draft; has NOT generated it. Generic fresh-context grader (no web/codebase/docs agent fits a pure-grading task), so general-purpose here is a deliberate exception to the "general-purpose only for code" routing rule. |

**Output budgets:** 1,000 tok for research/explore, 800 tok for docs (≤1,500 hard cap per the agent-protocols templates). See [`~/.claude/skills/_shared/agent-boundaries.md`](~/.claude/skills/_shared/agent-boundaries.md) for the CAN/CANNOT table and call budgets.

## Step → primitive mapping

- **Step 2 RESEARCH.** Simple/moderate: one `agent-websearch`. Complex: two `agent-websearch` in a single message, one supportive angle, one critical angle. Templates: `claude-agent-protocols.md` §Step 2.
- **Step 3a handoff.** Compress into the **Typed Handoff Format** (below): not prose. Pass it verbatim to Step 4 agents.
- **Step 4 PARALLEL.** Spawn `agent-explore` + `agent-docs` in a single message; only each whose 3c condition is met. Pass the typed handoff.
- **Step 6 CHALLENGE.** Spawn `agent-websearch` with the challenge protocol, it receives ONLY the 3–5 claims + sources, never the draft (independent fresh context = uncorrelated review; the strong form of generator-evaluator separation).
- **Step 7d EVALUATOR.** Spawn `general-purpose` with the evaluator protocol (complex only).
- **Step 8 REFINE.** Spawn only the agent(s) matching the gap, in a single message; anti-sycophancy ordering per `claude-agent-protocols.md` §Step 8.
- **Step 9 memory.** Persist to `$HOME/.claude/projects/$(pwd | sed 's#[/.]#-#g')/memory/research-{topic-slug}.md` (dash-encode the cwd: every `/` and `.` becomes `-`) and update that project's `MEMORY.md`. Use the schema in [workflow-engine.md](../references/workflow-engine.md) plus Claude's cross-run `pipeline_performance` block (agents_spawned, early_exit_triggered, refinement_gap, invariant_failures).

## ctx7 CLI protocol (DOCUMENT)

Two-step, run via Bash inside `agent-docs`:

1. Resolve: `bunx ctx7@latest library {library_name} "{user_question}"` → pick best by name similarity / snippet count / reputation → note the ID (`/org/project`, or `/org/project/version`).
2. Query: `bunx ctx7@latest docs {library_id} "{focused_query}"`, descriptive query, not single words.

**Hard limit: max 3 ctx7 calls total** (library + docs combined). After 3, use the best result you have.

## MAST coordination checks (Steps 2z / 4z)

After each agent return, verify: all requested sections present; assigned sub-questions addressed (cross-ref `must_answer`); within output budget. Log `coordination_gap: {agent, missing_section, unaddressed_question}` and carry it forward, catches silent multi-agent failures (~37% of multi-agent breakdowns are coordination) before Step 7.

## Progress headers

Print `[Step N/9] STEP_NAME` for each step you actually run. Scale to the path, a simple query won't print all ten. Don't fake the full march.

## Runtime-specific error cases

| Scenario | Action |
|----------|--------|
| Exa MCP unavailable | `agent-websearch` falls back to native WebSearch/WebFetch. |
| ctx7 fails / `unknown option` | Report "documentation lookup unavailable"; rely on web. (Empty results ≠ quota.) |
| ctx7 quota/rate-limit/429 (output literally says so) | Check `whoami`: logged in → monthly cap (login won't help); else suggest `ctx7 login`. Rely on web. |
| Evaluator agent fails (complex) | Fall back to orchestrator self-check; note in confidence basis. |
| Complex: one of two websearch agents fails | Use available results; note partial web coverage. |

## Typed Handoff Format (Step 3a)

```
Research context for downstream agents:

claims:
- text: "{finding}" | source: "{url}" | tier: T1|T2|T3|T4 | date: "YYYY-MM"

libraries: [{name: "lib", version: "X.Y.Z"}]
contradictions: ["{claim_a} (source_a) vs {claim_b} (source_b)"]
gaps: ["{what was not found}"]
query_coverage: high|medium|low
```

Target: 300-500 tokens. Source URLs are pointers for restorability. Always frame prior findings in third person.
