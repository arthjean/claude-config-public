# Agent Harness

> Status: current | Owner: user | Last verified: 2026-07-23

Read this document when changing the assistant setup, managing context, designing long-running work, responding to repeated failures, or deciding where guidance belongs.

## Operating Model

The user specifies intent, priorities, constraints, and acceptance criteria. The agent executes and produces inspectable artifacts.

Work depth-first through dependency-ordered slices. Use an in-thread plan for normal multi-step work. Create a durable spec or execution plan only when work spans sessions, carries material decision history, or the repository already uses one.

Separate exploration, planning, implementation, and delivery when uncertainty warrants it. Skip planning overhead for clear tactical edits.

## Context Architecture

Context is scarce. Global instructions, conversation history, file reads, command output, memory, and loaded skills all compete for it.

Keep always-loaded guidance concise. This repository enforces 160 lines for `CLAUDE.md` and 140 lines for `AGENTS.md`.

Claude Code expands `@...` imports into startup context. Imports improve organization but do not provide progressive disclosure. This setup uses an explicit knowledge map and on-demand document reads instead.

| Mechanism | Use |
|---|---|
| Current prompt | One-off constraints and acceptance criteria |
| Global instruction file | Behavior and safety needed every session |
| Repository instruction file | Project conventions and non-obvious architecture |
| Path-scoped rules | File-type or directory-specific constraints |
| Documentation | Detailed policy, decisions, references, and durable specs |
| Skill | On-demand knowledge or repeatable reasoning workflow |
| Custom subagent | Isolated investigation that would pollute the main context |
| Agent team | Independent sessions that must coordinate |
| Hook, test, linter, or script | Deterministic, mechanical invariant |
| MCP server | Live external data or actions |
| Settings | Permissions, environment, hooks, plugins, and runtime behavior |

For Claude Code, rules without `paths` frontmatter load unconditionally. Hooks belong in `settings.json`; standalone hook files are loaded only through plugins. Critical subagent constraints belong in the agent definition or delegation brief.

## Verification Loop

Give work a check the agent can run and read: a targeted test, build result, linter, screenshot, fixture diff, schema, log, metric, or trace.

Use the smallest check that proves the requested behavior. Show evidence rather than asserting success. Do not turn verification into automatic broad validation.

## Capability-Gap Loop

When the same failure recurs twice:

1. Stop repeating the approach.
2. Identify the missing context, tool, observability, feedback loop, invariant, or decision.
3. Fix the narrowest durable source.
4. Prefer mechanical enforcement for objective rules.
5. Keep judgment-heavy guidance in documentation or skills.
6. Remove stale or conflicting guidance.

## Claude Code Session Hygiene

- Use `/context` to confirm loaded instructions.
- Use `/memory` to inspect instruction and auto-memory sources.
- Use `/clear` between unrelated tasks.
- Use `/compact <focus>` to preserve the active workstream.
- Use `/rewind` to restore or summarize from a checkpoint.
- Name persistent sessions when work spans sittings.

Auto memory stores learned project context, not behavioral policy. Keep recurring rules in maintained guidance.

## Public Configuration Hygiene

Maintain only declarative, portable configuration:

- `CLAUDE.md`
- `AGENTS.md`
- `settings.json`
- `docs/`
- `rules/`
- `agents/`
- vendored `skills/`
- `statusline.sh`
- `scripts/`

Never publish sessions, memories, credentials, logs, telemetry, security state, plugin caches, machine-local settings, or absolute user paths.

After editing the global maps or `docs/`, run `scripts/check-guidance.sh`.

## Official Claude Code References

- [Best practices](https://code.claude.com/docs/en/best-practices)
- [Memory and CLAUDE.md](https://code.claude.com/docs/en/memory)
- [Extension mechanisms](https://code.claude.com/docs/en/features-overview)
- [Configuration debugging](https://code.claude.com/docs/en/debug-your-config)
