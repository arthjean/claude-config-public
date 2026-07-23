# Git and Delivery

> Status: current | Owner: user | Last verified: 2026-07-23

Read this document before a pull, commit, push, pull request, issue action, release, or delivery validation.

## Repository Sync

When asked for `git pull`:

1. Capture `git status --short --branch` and `git rev-parse --short HEAD`.
2. Pull only when tracked local work is safe.
3. Capture the new HEAD and final status.
4. If HEAD changed, inspect the commit range and targeted diffs.

Report the old commit, new commit, pull mode, final worktree state, and meaningful changes. Never discard local work to make a pull succeed.

## Attribution and Issue Safety

- Never add AI attribution, coauthor trailers, generated-by notes, or assistant signatures unless explicitly requested.
- Never close an issue without explicit approval.
- Never use `Fixes`, `Closes`, or `Resolves` keywords unless issue closure was requested.
- Default to `Refs #...`.

## Commit Quality

- One coherent intent per commit.
- Use Conventional Commits: `type(scope): concise imperative summary`.
- Avoid unrelated churn.
- Split unrelated behavior, configuration, refactoring, and documentation.
- Inspect the staged diff before committing.

## Validation at Delivery

Do not run broad validation after every edit.

- At a requested commit boundary, run one proportionate validation pass.
- Start with targeted checks for changed behavior.
- Use broad suites only when risk, repository instructions, or the user requires them.
- Without a commit request, skip broad validation unless requested or required for diagnosis.
- Do not repeat a passing check unless relevant code changed.
- Inspect the final diff before delivery.
