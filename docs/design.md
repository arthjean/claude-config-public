# Design Doctrine

> Status: current | Owner: user | Last verified: 2026-07-23

Read this document before UI design, frontend styling, interaction polish, visual review, design-system work, or design-token changes.

This is a quality floor, not a shared art direction. It should prevent generic AI-made interfaces without making every product look alike.

## Authority

Apply guidance in this order:

1. Product intent, user job, and current task.
2. Repository `DESIGN.md`, product brief, tokens, components, and validated screens.
3. This doctrine.
4. Skills, component libraries, pattern catalogs, and external references.

Local design intent wins when explicit and coherent. Preserve established identity even when a global guideline would choose differently in a greenfield project.

## Before Drawing

Determine:

- Whether this is a brand or product surface.
- The single dominant job or idea.
- The physical or conceptual scene behind the interface.
- The real artifact that proves the claim or helps complete the task.
- The existing token, primitive, or validated screen that governs implementation.
- Three concrete voice words. Avoid vague labels such as "clean", "modern", and "premium".

Do not fill uncertainty with generic SaaS conventions.

## Two Registers

| Axis | Brand and marketing | Product and application |
|---|---|---|
| Goal | Recognition, desire, narrative | Task completion, trust, repeated use |
| Originality | Distinctive composition and art direction | Earned familiarity with a few signature details |
| Typography | Expressive display choices may lead | Readability, density, stable hierarchy |
| Color | A committed palette can carry identity | Neutral system with scarce semantic accents |
| Layout | Editorial rhythm and controlled asymmetry | Predictable structure and operational density |
| Evidence | Photography, material, product proof | Real data, behavior, provenance, state |
| Motion | Narrative motion when it carries meaning | State change, feedback, spatial continuity |

Do not style an operational tool like a campaign page. Do not flatten a brand page into a component demo.

## Composition

Build hierarchy first from scale, width, placement, whitespace, and contrast. Weight, borders, shadows, decoration, and motion are secondary.

Each screen or section needs one dominant idea, one obvious reading path, and at most one primary action per action group.

Structure content by meaning before reaching for cards. A card is justified only for a bounded responsibility or interactive unit. Do not turn headings, paragraphs, rows, filters, or every white region into cards. Do not nest cards to manufacture depth.

Use responsive breakpoints where the composition fails, not from device names. Verify narrow widths, long translations, missing optional content, and 200% zoom.

## Banned Defaults

The following require a concrete, documented role:

- Centered hero badge, oversized generic headline, two pill CTAs, and abstract glow.
- Gradient text, ambient purple gradients, glass panels, decorative blur, glow, and gradient borders.
- Repeated eyebrow labels in tracked uppercase.
- Interchangeable three-card feature grids, icon mosaics, KPI-card dashboards, and card carousels.
- Oversized rounded rectangles, pills used as containers, and one large radius everywhere.
- Full border plus broad soft shadow on every container.
- Decorative grids, stripes, blobs, fake hand-drawn SVGs, or random grain unrelated to material identity.
- Generic terminal costumes, invented metrics, fake dashboards, fake testimonials, and decorative product screenshots.
- Automatic dark mode for technical products.
- Vague marketing copy and "Learn more" when a specific outcome can be named.
- Repeated section choreography and motion used to make ordinary controls feel novel.

An exception must be named, scoped, and tied to identity, comprehension, or task performance.

## Color and Tokens

Use this dependency order:

```text
palette -> semantic role -> component alias -> local composition
```

Prefer OKLCH for authored colors. Adjust lightness first for contrast, reduce chroma for gamut, and keep hue stable unless meaning changes.

Components consume semantic roles such as background, foreground, surface, border, focus, action, success, warning, and danger. Raw colors belong only in the palette, user-authored content, data visualization, isolated art, or a documented third-party boundary.

Accent color needs a job. Brand, action, selection, focus, and status are different roles. Light and dark themes are related material systems, not inverted ramps.

WCAG 2.2 is normative: at least 4.5:1 for normal text, 3:1 for large text, and 3:1 for meaningful non-text controls and states. APCA can be a secondary perceptual check.

Gradients are acceptable only as a named brand or material role. Never use gradient text as filler.

## Typography

Choose type by category and voice before choosing a family. Established brand typefaces take precedence.

Use the fewest families and weights that create a real hierarchy. Product surfaces usually need one interface family plus an optional monospace for machine-shaped data.

Keep public body copy at 16 px or larger unless density justifies otherwise. Long-form text generally stays between 60 and 75 characters. Balance headings and use tabular numerals for comparable values.

Avoid gratuitous all caps, aggressive negative tracking, fake weights, and huge headings without informational value.

## Surfaces and Geometry

Create depth with surface tones and spacing first. Use hairlines or local separators for structure. Use shadows only for genuinely floating layers.

Radii communicate containment. Preserve concentric corners and reserve fully rounded shapes for pills, badges, and circular controls.

Align optically, not only mathematically. Keep local corrections local until independent consumers prove a reusable invariant.

Interactive targets should be at least 44 by 44 CSS pixels on touch surfaces. Use a small semantic z-index scale, `dvh`, and safe-area insets for viewport-bound mobile layouts.

## Components

Use an existing accessible primitive before writing custom interaction behavior. Do not mix primitive systems within one surface without a documented constraint.

- Prefer existing variants, sizes, and states over local recreation.
- Remap semantic aliases at the theme boundary, not at every call site.
- Verify current component APIs instead of relying on memory.
- Treat pattern catalogs as behavioral evidence, not art direction.
- Use destructive confirmation, local errors, structural skeletons, and useful empty states where appropriate.

Promote a token or component only for independent consumers, a current invariant, or a known volatile boundary.

## Media and Evidence

A brief that depends on photography, texture, illustration, or product imagery requires real assets. Do not replace missing media with gradients or arbitrary SVG decoration.

Product claims require real proof: screenshot, interaction, report, command, artifact, or representative data. Decorative imagery may establish atmosphere but must not masquerade as evidence.

## Motion

Motion must explain state, causality, hierarchy, or spatial continuity.

Product feedback generally stays around 150 to 250 ms. Brand surfaces may justify a distinctive narrative transition, but repeated choreography destroys its signature.

Animate transform and opacity when possible. Never use `transition: all`. Use `will-change` only during active interaction. Advanced effects require explicit value, progressive enhancement, and a stable fallback.

`prefers-reduced-motion` must remove non-essential displacement without removing feedback or hiding content.

## Accessibility Contract

Use semantic HTML, logical headings, keyboard access, visible focus, accessible names, and correct state attributes. Never encode meaning with color alone.

Validate hover, focus, active, disabled, loading, empty, error, success, destructive, and long-content states as part of design.

## Delivery Gate

Before completion, confirm:

- The screen has one dominant idea, a clear next action, and no invented evidence.
- The result belongs to this product rather than a generic template.
- Existing tokens and primitives were reused without creating a second design system.
- Color, typography, spacing, radii, and surface depth are coherent.
- Narrow width, long content, loading, empty, error, disabled, focus, and reduced-motion states hold.
- Every decorative element has a named role.
- New abstractions correspond to current reuse or invariants.

Normative accessibility reference: [Web Content Accessibility Guidelines 2.2](https://www.w3.org/TR/WCAG22/).
