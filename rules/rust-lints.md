---
description: Lints clippy obligatoires pour tout projet Rust - policy panic/unwrap, clippy.toml, belt cfg_attr. Source de vérité des lints Rust (référencée depuis ~/.claude/CLAUDE.md), enforced par le hook rust-cargo-check.sh.
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
---

# Rust - Lints (MANDATORY)

Every new Rust project (or any Rust project I'm adding code to that doesn't already have these) MUST include the following clippy lints. These are cherry-picked from `clippy::restriction` - never enable the whole restriction group (officially discouraged by the clippy team: *"It is not recommended to enable the whole group"*).

## 1. `Cargo.toml`

```toml
[lints.clippy]
# Panic-like escapes - deny in production code
panic            = "deny"
unimplemented    = "deny"
dbg_macro        = "deny"
todo             = "warn"    # accept temporary TODOs

# unwrap / expect - warn, NOT deny
# Rationale: deny breaks #[tokio::main] (tokio #3887), creates contradictions
# between unwrap_used and expect_used (clippy #9222), and triggers in integration
# tests despite allow-unwrap-in-tests (clippy #13981). Warn matches the prevailing
# community practice (tokio, axum, bevy have not enabled deny).
unwrap_used      = "warn"
expect_used      = "warn"
unwrap_in_result = "warn"
```

For workspaces, put this in the root `[workspace.lints.clippy]` and each member declares `[lints] workspace = true`.

## 2. `clippy.toml` (project root, next to `Cargo.toml`)

```toml
allow-unwrap-in-tests = true
allow-expect-in-tests = true
```

## 3. `src/main.rs` or `src/lib.rs` (first lines)

```rust
#![cfg_attr(test, allow(clippy::unwrap_used, clippy::expect_used))]
```

This belt works around [clippy #13981](https://github.com/rust-lang/rust-clippy/issues/13981) where `allow-*-in-tests` in `clippy.toml` doesn't cover integration tests.

## Enforcement

- `~/.claude/hooks/rust-cargo-check.sh` runs `cargo clippy --no-deps` on every `.rs` / `Cargo.toml` edit (PostToolUse) and at end of turn (Stop hook), blocking on `deny` lints. Warnings surface in the session so I can fix them before moving on.
- In normal code, replace `unwrap()`/`expect()` with `?`, `ok_or(...)?`, `unwrap_or(default)`, `match`, or `if let`. Reserve `expect("invariant reason")` for provably-infallible cases with a documented invariant.
