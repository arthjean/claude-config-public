# ultron - audit dimensions & design rationale

Reference for the eight lenses `~/.claude/workflows/ultron.js` runs, the static
signals each finder hunts, how severity is calibrated, the failure modes the
pipeline defends against, and where it all comes from. The finder/verifier prompts
live in the engine; this doc is the human-readable map.

## The pipeline (teamlead → engine)

```
/ultron <target>            ← skill: the teamlead. scopes, launches, writes files.
  └─ Workflow ultron.js     ← engine: the deterministic multi-agent orchestrator.
       Recon      agent-explore maps langs/frameworks/entry-points → scan units + threat model
       Find       focused finder per (unit × dimension), read-only, one lens each   [sectioning]
       Dedup      deterministic (file:line+category) then one semantic pass, cross-dimension
       Verify     N independent adversarial verifiers per finding, fresh context     [voting]
       Patch      (optional) inert candidate diff + isolated reviewer per confirmed HIGH+
       Synthesize audit-lead writes AUDIT.md; completeness critic flags thin coverage
```

Two Anthropic *Building Effective Agents* patterns: **sectioning** for finders
(split independent work for breadth/speed) and **voting** for verification
(redundant independent runs aggregated for accuracy). The engine returns a fully
structured result; the skill does all filesystem I/O (the Workflow runtime has none).

## The eight dimensions

| key | lens | the question it answers |
|-----|------|--------------------------|
| `security` | OWASP / CWE | Can untrusted input reach a dangerous sink? |
| `correctness` | logic bugs | Does it produce wrong results / crash on **valid** input? |
| `robustness` | stability | What breaks under **adverse** conditions in production? |
| `perf-machine` | CPU / GPU / RAM | Where does it waste cycles/memory/bandwidth under load? |
| `perf-web` | Core Web Vitals | What regresses LCP/INP/CLS or inflates infra cost? |
| `approach-optimality` | architecture | Is this the **right shape**, not just correct? |
| `best-practices` | idioms + stack rules | Does it follow the language idiom and the mandatory stack? |
| `quality` | maintainability | Comment signal vs noise, naming, dead code, duplication, complexity. |

Each finder gets exactly one lens and one scan unit, told *"other agents cover other
areas; duplication is wasted effort"* - the explicit scope partitioning that drives
~80% of multi-agent performance (Anthropic: token budget is the dominant variable).

### Static signals (what finders grep for)

- **security** - concatenated SQL/shell/template into a sink reachable from a handler;
  missing/post-hoc authz; secrets in source; `dangerouslySetInnerHTML`/`v-html`/`|safe`
  on attacker data; SSRF; unsafe deserialization; trust-boundary path traversal.
- **correctness** - off-by-one / mixed `<`,`<=` (CWE-193/787/125); `.unwrap()`/`!`/
  as-casts on fallible-or-undefined (CWE-476); swallowed errors (CWE-390/755);
  await-read→mutate→await-write & shared-mutable-async (CWE-362/367); integer over/
  underflow into index/alloc (CWE-190/681); leaked handles (CWE-772/401).
- **robustness** - no validation at a trust/IO boundary; panic reachable from input;
  unbounded queue/cache/retry growth; no timeout/cancellation; no backoff; no
  partial-failure path; resource checked out on an error return; missing idempotency.
- **perf-machine** - *blocking-in-async* (top bug for Axum/Tokio: `std::fs`,
  `reqwest::blocking`, `std::thread::sleep`, long unyielding loop in an `async fn`);
  `Arc<Mutex>`/`RwLock` contention on per-request state; O(n²) on user input; hot-path
  alloc / needless `.clone()`; AoS→SoA & false sharing (data-parallel only). GPU:
  per-object `writeBuffer` of shared matrices, unbatched draws, branch divergence,
  overdraw, `textureGather`-vs-4-samples, register pressure.
- **perf-web** - render waterfall (sequential independent awaits → `Promise.all`);
  N+1 (`await` inside `.map`); needless `"use client"`; bundle bloat (>250KB vendor,
  full lodash/icon packs); missing memoization; cache misuse both ways
  (`no-store` on shared data / no cache on cacheable); CLS (`<img>` without dims,
  unthrottled scroll/resize → `setState`).
- **approach-optimality** - over-engineering (abstraction/generic with one use site);
  under-engineering (god handler, validation copy-pasted instead of a type, raw
  primitives where newtypes belong, mixed units); design-level data-structure mismatch;
  the *"is this even the right shape"* call - only with a concrete simpler alternative.
- **best-practices** - Rust: missing mandated clippy lints / `clippy.toml` / the test
  `cfg_attr`; `.unwrap()`/`.expect()`/`.lock().unwrap()` in prod; `panic!`/`dbg!`. JS/TS:
  `npm`/`pnpm`/`yarn`/`npx`; ESLint/Prettier; client-only validation, no server Zod;
  `any`; barrel files; component >250 lines. Next/web: missing a11y + OWASP/HSTS headers.
- **quality** - comments that paraphrase code / dateless TODOs vs missing public-API
  docs; nothing-names (`data`/`manager`/`utils`), booleans without a predicate; dead
  code & `#[allow(dead_code)]`; near-identical bodies; cyclomatic >10 (warn)/>15 (split);
  fn >50 lines, nesting >3, file >400 lines mixing concerns.

## Severity calibration

Verifiers **recompute** severity from impact × reachability/frequency - not from the
finder's claim or the category name:

- **CRITICAL** - remotely exploitable / no auth / data-breach or RCE; O(n²) on large
  untrusted input.
- **HIGH** - exploitable with prerequisites; blocking-in-async; per-request lock
  contention; needless client component pulling a subtree into the bundle.
- **MEDIUM** - limited reach, defense-in-depth, memoization gaps, most CLS.
- **LOW** - best-practice gap with marginal impact.
- **INFO** - observation; everything `SUBJECTIVE` (taste, no concrete cost) lands here.

Perf findings must cite the **hot path** (loop / per-request / per-frame) or they are
refuted (`no_hotpath`). Approach critiques must name a concrete simpler alternative or
they degrade to `SUBJECTIVE`.

## Verdicts

`CONFIRMED` (real, ranked) · `REFUTED` (false positive - dropped to an appendix) ·
`SUBJECTIVE` (valid but taste/no-cost → kept as INFO, **not** dropped, so quality and
comment feedback still surfaces) · `CANNOT_VERIFY` (static reasoning hit its limit →
kept as needs-manual-review, never a confident verdict on unread code).

Each verifier runs in **fresh context**, sees only `{id, file:line, category, claimed
severity, title}` - never the finder's reasoning - re-reads the cited code itself,
traces reachability backwards quoting the first call site, hunts for protections, and
applies the exclusion list. Majority decides; ties break on the `--noise` policy.

## Design pitfalls it defends against

1. **False-positive flood** → exclusion rules in every verifier + N-vote majority +
   "flag only concrete problems" finder bar + a noise policy for split votes.
2. **Cross-dimension duplicates** (one `.unwrap()` is correctness *and* security *and*
   best-practices) → dedup *before* verify; a canonical finding tags every dimension it
   satisfies and is verified once.
3. **Prompt injection from target source** → anti-injection preamble in every prompt;
   read-only disposition; no `--apply`; inert output only.
4. **Context blowup / silent truncation** → the engine is a JS runtime (no LLM context
   to overflow); finders are unit-scoped; the Workflow journal handles resume; coverage
   gaps are reported, never hidden.
5. **Trusting the finder over the code** → verifiers re-derive from source; unlocatable
   findings → confidence 0.
6. **Over-engineering the audit / chasing every gap** → ruthless ranking; the report
   leads with verified Critical/High and appendices the rest.
7. **Scope mismatch / paying multi-agent cost on a trivial target** → `--single`
   auto-fallthrough on tiny trees; `--focus`, `--votes`, budget-aware finder caps with
   explicit drop logging.

## Sources

- The four sibling skills: `/vuln-scan` (focused fan-out, read-only), `/triage`
  (N-vote verify, 16-rule exclusions, dedup-before-verify, anti-injection), `/patch`
  (inert diffs, isolated reviewer, never applies), `/security-review` (scope →
  threat-model → layered audit → severity+confidence).
- Anthropic - *How we built our multi-agent research system* (orchestrator/worker,
  distributed output, token budget = ~80% of variance) and *Building Effective Agents*
  (sectioning vs voting, evaluator-optimizer, "add complexity only when it pays").
- Claude Code docs - custom subagents, dynamic-workflow orchestration, Boris Cherny's
  "hooks are deterministic, CLAUDE.md advisory", fresh-context review, "verification is
  the single highest-leverage step", "don't chase every finding".
- MITRE CWE Top 25; Core Web Vitals / Next.js perf heuristics (DebugBear, Pagepro);
  Rust perf catalogs (kvark, cache-locality) + WebGPU/NVIDIA shader-perf guides;
  code-smell literature (cyclomatic complexity, cohesion/coupling, comment signal).
- The user's `CLAUDE.md` mandatory stack rules (Rust clippy lints, bun, Biome, Zod
  boundaries, TS-strict 0-any, <250-line components, no barrel files, a11y, OWASP headers).
