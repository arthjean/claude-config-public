Use the Context7 skill plus CLI for current documentation whenever the user asks about a library, framework, SDK, API, CLI tool, or cloud service. This includes API syntax, configuration, migrations, library-specific debugging, setup, and CLI usage. Prefer it over web search for library documentation.

Do not use for: refactoring, writing scripts from scratch, debugging business logic, code review, or general programming concepts.

## Steps

1. Unless the user provides an exact ID in `/org/project` or `/org/project/version` form, run `bunx ctx7@latest library <library_name> "<user's full question>"`.
2. Pick the best match by exact name, description relevance, snippet count, source reputation, benchmark score, and version fit. Retry with an alternate name only when the result is wrong.
3. Run `bunx ctx7@latest docs <libraryId> "<user's full question>"` with a specific query.
4. Answer from the fetched documentation and separate verified behavior from inference.

Use two retrieval calls normally and at most three. Do not include secrets, credentials, private source code, or personal data in queries. Do not use Context7 MCP tools unless the user explicitly requests MCP mode.

For version-specific docs, use `/org/project/version` from the `library` output (e.g., `/vercel/next.js/v14.3.0`).

Before reporting an authentication or quota problem, run `bunx ctx7@latest whoami` once. If it reports an authenticated session, do not tell the user to log in again. Report the exact CLI error and whether the apparent quota conflicts with the dashboard state. Never silently fall back to model memory.
