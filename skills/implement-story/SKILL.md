---
model: opus
name: implement-story
disable-model-invocation: true
description: "End-to-end pipeline to implement a user story from a PRD through 8 phases: intake, research, planning, implementation, static analysis, parallel code review + security audit, remediation, and status update. Ends at story status IN_REVIEW (no commit, no push). Fully autonomous, no user questions. Invoke with /implement-story [prd-path] [story-id]."
argument-hint: "[prd-path] [story-id]"
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Agent
---

# implement-story: PRD User Story Implementation Pipeline

Implement the following: $ARGUMENTS

## Current State
- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Recent commits: !`git log --oneline -5`

## Overview

Gate-based pipeline: each phase has an exit gate that must pass before the next phase begins. The orchestrator writes code only in Phases 4 and 7 (IMPLEMENT and REMEDIATE). All other phases are coordination or read-only analysis. The pipeline is fully autonomous: no user questions, the orchestrator decides at every gate. It ends at story status IN_REVIEW and does not commit or push (the sibling /review-story takes IN_REVIEW → DONE, or the user commits when ready).

**Principles:** Research before code. Static analysis before AI review. Fresh-context reviews. Risk-tiered autonomy for fixes. Proof-of-fix.

**Context compression:** At each phase boundary the listed Phase Summary is the ONLY state downstream phases need. Raw agent outputs, reasoning, and intermediate attempts are not carried forward. The orchestrator cannot compact its own context mid-run (slash commands like `/compact` are user-initiated and not callable by the model), so the lever that actually works is structural: push every heavy read to a fresh-context subagent and carry only the Phase Summaries forward, keeping the orchestrator window small by construction. Autocompact is disabled, so if usage still crosses ~50% at a boundary, surface a one-line note recommending the user run `/compact` (resume anchor = the latest Phase Summary) rather than pretending to self-compact.

## Execution Flow

`INTAKE → RESEARCH → PLAN → IMPLEMENT → STATIC → REVIEW+SECURITY (parallel) → REMEDIATE → STATUS`

Print `[Phase N/8] PHASE_NAME` before each phase.

---

## Phase 1: INTAKE

Parse the PRD and extract the target user story.

**1a. Parse arguments:** Extract file path and story ID (e.g., `US-001`, `#1`) from `$ARGUMENTS`. If ambiguous, infer the most likely match from the PRD content.

**1b. Read the PRD.** Extract: story title/description, acceptance criteria, quality gates, dependencies, technical considerations.

**1c. Comprehension check:** Reformulate the acceptance criteria in your own words, not a copy-paste but a restatement proving understanding. Include: what the feature does, what it does NOT do (scope boundary), and how each criterion will be verified.

**1d. Display comprehension check:** print the reformulated story and criteria so the user can see them, then proceed immediately.

**1e. Pre-filter scope:** Exclude from analysis: lock files (`package-lock.json`, `yarn.lock`, `Cargo.lock`, `pnpm-lock.yaml`), generated files (`*.generated.*`, `@generated` header), vendor directories (`vendor/`, `node_modules/`, `third_party/`), build output (`dist/`, `build/`, `target/`, `.next/`).

**1f. Complexity triage:** Classify the story to scale Phase 2 research effort:

| Level | Criteria | Phase 2 scope |
|---|---|---|
| SIMPLE | Boilerplate, UI tweak, rename, config change, single-file edit | Skip 2b websearch. Only agent-explore (2d) |
| STANDARD | New feature, API endpoint, multi-file change | Full Phase 2 (websearch + explore + docs) |
| COMPLEX | New integration, auth/payments, cross-service, unfamiliar domain | Full Phase 2 + expanded websearch scope |

If unsure, default to STANDARD. The replan gate (4a) catches under-estimates.

**1g. Detect status tracking:**

Look for a status JSON file alongside the PRD:
- If PRD is `tasks/prd-foo.md` → check for `tasks/prd-foo-status.json`
- If found → read it, verify the target story exists and is `TODO` or `BLOCKED`
- If not found → create a minimal status JSON from the PRD's story list (all stories start as `TODO`, PRD status as `IN_PROGRESS`)
- If story status is `IN_REVIEW` or `DONE` → log a warning and proceed (the user invoked the command explicitly)

**GATE:** Story parsed and comprehension check displayed.

**Phase 1 Summary:** Story ID, title, acceptance criteria, quality gates, pre-filter rules, complexity level, status JSON path.

---

## Phase 2: RESEARCH

Research scope is set by Phase 1f complexity triage.

**2a. Check memory:** Resolve the project's memory dir by dash-encoding the cwd (replace every `/` and `.` with `-`): `MEM="$HOME/.claude/projects/$(pwd | sed 's#[/.]#-#g')/memory/"`. If it exists, scan it for prior research on this domain; fresh, relevant findings narrow the websearch scope. If it does not exist, skip (no memory for this project yet).

**2b. Spawn agent-websearch** (STANDARD/COMPLEX only, skip for SIMPLE) with the Research template from phase-protocols.md. Wait for completion. Extract key findings, libraries, best practices.

**2c. Detect codebase:** Parallel Glob for `Cargo.toml`, `package.json`, `pyproject.toml`, `go.mod`.

**2d. Spawn agent-explore + docs agent in a SINGLE message** (parallel, templates in phase-protocols.md):
- **agent-explore:** Always spawn if codebase detected.
- **agent-docs:** Only spawn if Phase 2b identified new/unfamiliar libraries not already established in the codebase. If the story uses only existing project libraries with clear patterns found by agent-explore, skip docs.

**2e. Synthesize:** Combine outputs per [Synthesis Template](~/.claude/skills/_shared/synthesis-template.md). Compress to <500 words for downstream phases.

**GATE:** Research synthesis complete. At least agent-websearch returned results.

**Phase 2 Summary:** Synthesized research (<500 words), key libraries with versions, integration points with file:line, security considerations.

---

## Phase 3: PLAN

Generate a structured implementation plan from research + acceptance criteria.

**3a. Create the plan:** Include files to create/modify (with rationale), step-by-step implementation, test strategy, quality gate commands, and risk areas from research.

**3b. Scope guard:** Check against [Scope Guard](~/.claude/skills/_shared/scope-guard.md) thresholds (>7 change sets, >20 files, >800 LOC). If exceeded, log a scope warning and proceed: the user invoked implementation explicitly.

**3c. Print the plan** for visibility, then proceed immediately.

**GATE:** Plan generated and scope checked.

**Phase 3 Summary:** Approved plan (files to create/modify, step sequence, test strategy, quality gate commands).

---

## Phase 4: IMPLEMENT

Execute the plan step by step.

**4a. Implement:** Follow the plan sequentially. Read existing files before modifying. Use Edit (prefer) or Write (new files). Run quality gates after each logical group of changes. Track all modified files in a running list for the Phase 6 reviewers (code review + security).

**4a-replan. Replan gate:** If implementation reveals a blocker, incompatibility, or incorrect assumption in the plan, STOP. Do not force through an invalid plan. Update the plan with what was learned, log the revision, and resume with the corrected plan. This prevents cascading errors from faulty premises.

**4b. Run quality gates:** PRD-specified gates + language-specific checks (linters, type checkers) + tests.

**4c. Verify acceptance criteria:** For each criterion from Phase 1, confirm it is met. If it requires a test, confirm the test exists and passes. If it requires visual verification, note for the user.

**GATE:** All quality gates pass. All acceptance criteria met or marked for manual verification.

**Phase 4 Summary:** Files created/modified, quality gate results, acceptance criteria status, changed files list for reviewers.

---

## Phase 5: STATIC ANALYSIS

Run deterministic checks before spending AI tokens on review. Only run tools already configured in the project (check for config files). Do NOT install new tools.

**5a. Run language-specific linters and formatters** already configured in the project. Nothing is hook-enforced, so the orchestrator runs every gate itself. For JS/TS, use bun/bunx (never npm/npx), biome (never eslint/prettier), and vitest (never jest). For Rust, run `cargo clippy --no-deps` and `cargo fmt --check` yourself before the phase ends: clippy must be clean, and `panic!`/`unimplemented!`/`dbg!` are deny-level lints (see `~/.claude/rules/rust-lints.md`). Treat any `unwrap()`/`expect()` outside tests as a Phase 7 finding.

**5b. Run type checking** if configured.

**5c. Auto-fix mechanical issues** (formatting, unused imports). Re-run quality gates to confirm. Queue remaining warnings for Phase 8.

**5d. Dependency diff check:** Run `git diff HEAD -- **/package.json **/Cargo.toml **/pyproject.toml **/go.mod`. If dependencies were added, changed, or removed, log each change visibly. Only add dependencies explicitly required by the story's acceptance criteria.

**GATE:** Auto-fixable issues resolved. Remaining warnings queued.

**Phase 5 Summary:** Auto-fixed issues, remaining warnings queue, dependency changes. Pass changed files list + acceptance criteria to Phase 6.

---

## Phase 6: CODE REVIEW + SECURITY AUDIT

Agent topology scales with Phase 1f complexity:

**SIMPLE:** Single agent-explore with the Combined Review+Security template from phase-protocols.md. Covers both correctness and security in one pass. Output: unified findings list with severity.

**STANDARD/COMPLEX:** Two agents in a SINGLE message for parallel execution (both agent-explore), with distinct description fields for a legible task list:
- Code Review leg: Review template from phase-protocols.md
- Security Audit leg: Security template from phase-protocols.md

Both legs are read-only agent-explore runs scoped to the changed files: a focused diff pass, not a whole-codebase audit. For a deeper standalone security pass the sibling `/security-review` skill exists; this phase deliberately keeps the audit inline and diff-scoped to stay self-contained.

**GATE:** Review(s) complete.

**Phase 6 Summary:** Consolidated findings (severity + file:line + issue + suggestion), review verdict, security verdict.

**Context-pressure trip:** This pipeline writes code in two phases (IMPLEMENT and REMEDIATE) in one growing orchestrator window, and autocompact is disabled, so there is no automatic backstop. The orchestrator cannot self-compact, so the discipline is preventive: by this boundary, everything except the Phase Summaries (status JSON path, changed-files list, open findings) should already be evictable. If usage still crosses ~50% here, surface a one-line note recommending the user run `/compact` with a forward-looking description naming the status JSON path and the changed-files list, then resume from the Phase Summaries.

---

## Phase 7: REMEDIATE

Fix all issues from Phase 5 (remaining warnings) and Phase 6 (review + security).

**7a. Triage:** CRITICAL/HIGH security and MUST_FIX review findings are mandatory to address. MEDIUM/SHOULD_FIX are recommended. LOW/INFO/CONSIDER are skipped unless trivial.

**7b. Risk-tier each fix before applying:**

| Risk | Criteria | Action |
|------|----------|--------|
| LOW | Formatting, unused imports, typos, dead code | Auto-fix |
| MEDIUM | Logic changes, validation, error handling, perf | Fix and show diff |
| HIGH | Auth, crypto, billing, data access, API contracts | Apply with extra caution, log rationale |

**7c. Fix loop (max 3 full cycles):** For each mandatory finding: classify risk, apply fix, run the specific validation that caught it, mark resolved. Between cycles, if a fix made things worse, revert that specific change before trying a different approach; do not stack corrections on top of a failed fix. After all fixes: re-run ALL quality gates. **Scope creep guard:** if a fix modifies files not in the original findings list, log a warning but proceed only if the fix is directly required. Remediation without scope control cascades into unrelated refactors.

**7d. Exit verification:** Re-read each file modified in Phase 7. For each original finding, verify the issue is resolved (not moved or masked) and no new issues introduced. If any CRITICAL/HIGH persists, log them clearly in the final output.

**7e. If issues persist after 3 cycles:** Stop, log what was tried and why it didn't resolve, and note remaining issues in the final output.

**GATE:** Zero CRITICAL/HIGH/MUST_FIX remaining. All quality gates pass.

**Phase 7 Summary:** Findings resolved, findings deferred (with reason), files touched during remediation, final quality-gate status.

---

## Phase 8: STATUS UPDATE

Update the PRD status JSON (detected or created in Phase 1g):

1. Set story status: `TODO → IN_REVIEW`
2. Set `completed_at` to current date (`YYYY-MM-DD`)
3. Roll-up PRD status: if at least one story is `IN_PROGRESS` or beyond → PRD status = `IN_PROGRESS`
4. Save the updated status JSON

If the status JSON does not exist, skip silently.

**GATE:** Status updated. Print a summary of changes made, acceptance criteria met, and any remaining issues.

**Phase 8 Summary:** Terminal phase: the GATE output above (changes made, acceptance criteria met, remaining issues) IS the final summary.

---

## Error Handling

| Error | Action |
|---|---|
| PRD not found | Infer from cwd or fail with clear error |
| Story not found | Pick the first TODO story, log the choice |
| Agent fails | Continue with available data, note gap |
| All review agents fail | Inline review as orchestrator, note reduced coverage |
| Quality gates fail (Phase 4) | Fix before proceeding |
| Story already done | Log warning, proceed anyway |

## Constraints

Applies the Three-Tier Constraints model (ALWAYS/ASK FIRST/NEVER) with one deliberate override: because this pipeline runs only on explicit invocation and is autonomous by design, it **converts the ASK FIRST tier to LOG-AND-PROCEED**: it never pauses for confirmation on HIGH-risk fixes (Phase 7b, applied with logged rationale), scope-guard breaches (Phase 3b, logged), or dependency changes (Phase 5d, logged). The scope-guard import supplies its threshold numbers only (>7 change sets / >20 files / >800 LOC), not its AskUserQuestion escalation. The one ASK FIRST action that survives is structural: the pipeline never commits or pushes (it ends at IN_REVIEW), so "push to remote" cannot occur.

Pipeline-specific rules:

- **ALWAYS:** Research (Phase 2) before implementation. Quality gates after Phase 4 AND Phase 7, run by the orchestrator itself (nothing is hook-enforced). Static analysis (Phase 5) before AI review. Keep the orchestrator window small by construction: carry only Phase Summaries across boundaries and push heavy reads to subagents (the model cannot self-`/compact`; if usage still crosses ~50%, recommend the user compact). Compress research to <500 words. Keep agent outputs tight: roughly 1,000 tokens (websearch/explore), 800 (docs), 1,500 (review/security), prioritizing top findings over completeness. Update status JSON after completion (story to IN_REVIEW). Pass changed files list to review agents. Reformulate acceptance criteria in Phase 1c. Decide autonomously at every gate, never ask the user.
- **NEVER:** Skip Phase 2 entirely (websearch may be skipped for SIMPLE, but explore is always required). Modify files during the review phase (Phase 6). Continue past 3 remediation cycles. Invent acceptance criteria not in the PRD. Downplay security findings. Force through an invalid plan (use replan gate instead). Ask the user questions (AskUserQuestion); decide based on available context. Commit or push (the pipeline ends at IN_REVIEW).

## References

- [Phase Protocols](references/phase-protocols.md): agent prompt templates and expected output formats
- [Agent Boundaries](~/.claude/skills/_shared/agent-boundaries.md): agent CAN/CANNOT table, call budgets
- [Scope Guard](~/.claude/skills/_shared/scope-guard.md): threshold numbers only (this pipeline logs-and-proceeds instead of its AskUserQuestion escalation)
- [Synthesis Template](~/.claude/skills/_shared/synthesis-template.md): research output format and conflict resolution
- [Three-Tier Constraints](~/.claude/skills/_shared/three-tier-constraints.md): ALWAYS/ASK FIRST/NEVER model (ASK FIRST overridden to log-and-proceed; see Constraints)
