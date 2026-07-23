# Research and Delegation

> Status: current | Owner: user | Last verified: 2026-07-23

Read this document when the task needs current library documentation, live web evidence, broad codebase exploration, or subagent delegation.

## Source Routing

| Need | Route |
|---|---|
| Stable fact or direct reasoning | Main conversation |
| A few local files or exact call sites | Targeted local inspection |
| Broad cross-module architecture or flow | `agent-explore` |
| Version-sensitive library, SDK, CLI, or cloud API | `agent-docs` or direct Context7 CLI |
| Current releases, pricing, company facts, or comparisons | `agent-websearch` or native web research |
| Repeatable workflow or reference knowledge | Relevant skill |

Use local code for project behavior, current documentation for API contracts, and current primary sources for volatile external claims.

## Documentation Lookup

Follow `rules/context7.md`.

Use Context7 for libraries, frameworks, SDKs, APIs, CLI tools, and cloud services. Do not use it for business logic, code review, refactoring, or general programming concepts.

Never send secrets, credentials, private source, or personal data to documentation services. For Claude Code, prefer official `code.claude.com` and `anthropic.com` sources. For OpenAI products, prefer official OpenAI sources.

## Custom Subagents

- `agent-explore`: deep, read-only codebase analysis.
- `agent-docs`: version-sensitive documentation research.
- `agent-websearch`: current primary-source web research.

Delegate only bounded work that materially improves correctness or keeps noisy evidence out of the main context.

- Keep quick lookups and a few targeted reads in the main conversation.
- Keep briefs self-contained and focused.
- Keep implementation in the main conversation. The research agents are read-only.
- Run independent agents in parallel only when latency savings exceed coordination and token cost.
- Keep delegation at depth one.
- Do not broaden a role's tools without a concrete need.
- Put critical constraints in the agent definition or delegation brief.
- Use agent teams only when independent sessions must communicate and coordinate.

If a custom role is unavailable, perform the equivalent work directly.
