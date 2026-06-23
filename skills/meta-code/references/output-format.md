# Output Format

Answer template for the meta-code pipeline. Conclusion first, citation-first, contradictions surfaced, confidence rated. Use prose by default (gpt-5.5 `verbosity` low); reach for tables/code only where they aid comprehension.

```markdown
## Answer

[Direct, actionable answer, 3–10 sentences, most important finding first.]

**Confidence:** {high|medium|low} (trajectory: {level}, response: {level}): {one-line basis}

## Details

### From web research
[Key findings, each with source URL + tier. Or: "Web research yielded no usable results."]

### From the codebase
[Findings with file:line references. Or: "No codebase detected." / "Not relevant to this question."]

### From official docs
[API details / version notes / examples with doc source. Or: "No library docs needed."]

### Contested claims
[Each disputed point with both positions and their sources. Or: "No contradictions detected across sources."]

## Recommended approach

[3–7 concrete next steps, tailored to the user's actual context and local code.]

## Sources
- [Title](URL): tier T1–T4, annotation
- file:line, what it shows
- doc: {library/source} {version if known}

## Follow-up
[What further research would materially improve this. Or: "No significant gaps."]
```

## Confidence line

Format: `**Confidence:** {level} (trajectory: {t}, response: {r}): {basis}`

- **trajectory** = were the right sources used and did they converge (coverage, agent/source convergence, search depth).
- **response** = is the content correct (concordant T1–T2 sources, diversity, recency, survived challenge).
- Combined level per the table in [workflow-engine.md](workflow-engine.md). Apply the niche-topic cap: fewer than 3 T1–T2 sources across all evidence → cap at `medium`.

## Flags

Surface these inline when they apply:
- `trivial_bypass`, answered directly from knowledge, no research run.
- `needs verification`, claim rests only on T3–T4 sources.
- `degraded: exa unavailable`, web evidence missing, confidence lowered accordingly.
