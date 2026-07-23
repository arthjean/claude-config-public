# Engineering Defaults

> Status: current | Owner: user | Last verified: 2026-07-23

Read this document when choosing architecture or stack, adding a dependency, writing JavaScript or TypeScript package commands, or working without stronger project conventions. Existing project constraints take precedence.

## Default Stack

| Domain | Default | Conditions |
|---|---|---|
| Frontend | Next.js latest or Astro latest | Project dependent |
| UI | React latest, Tailwind CSS, accessible primitives | Prefer the existing design system |
| Data layer | TanStack, Zod, react-hook-form | Use only what the task needs |
| Backend TypeScript | Next.js server code | Keep server and client boundaries explicit |
| Backend Rust | Axum, SeaORM, Tokio | Performance or concurrency systems |
| Database | PostgreSQL | Add Redis only when its value exceeds its cost |
| Auth | Better Auth or Clerk | Project dependent |
| Package manager | Bun | Use the established project manager when different |
| Lint and format | Biome for JavaScript and TypeScript, rustfmt and Clippy for Rust | Prefer project scripts |
| Tests | Vitest, Testing Library, strict TypeScript | Scale validation to risk |
| Deployment | Vercel for web applications | Use the project platform when different |

These are tie-breakers, not a checklist. Replace them in a private fork when your stack differs.

## Cross-Cutting Defaults

- Keep modules and components focused.
- Avoid barrel files without a current reason.
- Centralize design tokens.
- Treat accessibility, validation at boundaries, security headers, and sensitive-data scrubbing as first-class.
- Never hardcode secrets.
- Comments explain a non-obvious why, not the code itself.

## Rust

Follow `rules/rust-lints.md` when it applies. Prefer recoverable errors and explicit invariants over production `unwrap()` or `expect()`.

## JavaScript and TypeScript Package Manager

In a Bun project:

- Use `bun` and `bunx`.
- Preserve the repository's existing lockfile format.
- Do not convert package managers without a current requirement.

Project-specific conventions override this default.
