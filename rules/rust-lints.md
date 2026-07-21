---
description: Lints Clippy pour les projets Rust: politique panic/unwrap, clippy.toml et cfg_attr. Source de vérité référencée depuis ~/.claude/CLAUDE.md; validation proportionnelle, sans hook automatique.
paths:
  - "**/*.rs"
  - "**/Cargo.toml"
---

# Rust: Lints (MANDATORY)

Every new Rust project, or Rust project receiving new code without an existing policy, must include the following Clippy lints. They are selected from `clippy::restriction`; never enable the whole restriction group, which the Clippy project explicitly discourages.

## 1. `Cargo.toml`

```toml
[lints.clippy]
# Panic-like escapes: deny in production code
panic            = "deny"
unimplemented    = "deny"
dbg_macro        = "deny"
todo             = "warn"    # accept temporary TODOs

# unwrap / expect: warn, not deny
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

## Validation

- No hook runs Clippy automatically. Follow the global anti-friction policy: inspect during implementation and run `cargo clippy --no-deps` in the consolidated validation pass when the user asks for a commit, the repository requires it, or a concrete failure needs diagnosis.
- In normal code, replace `unwrap()`/`expect()` with `?`, `ok_or(...)?`, `unwrap_or(default)`, `match`, or `if let`. Reserve `expect("invariant reason")` for a documented invariant when no better boundary exists.
