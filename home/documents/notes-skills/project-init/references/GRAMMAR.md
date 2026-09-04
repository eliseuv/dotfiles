# PROJECT_SPEC.md grammar

Deliberately a strict subset of Markdown: renders on any Markdown viewer, parses
with a few regexes, and survives hand-editing by someone who has never read this
file. `spec.py` never reserializes the document — it edits individual lines — so
prose, comments and formatting outside the fields are preserved exactly.

## Frontmatter

```
---
spec_version: 1
project: delphi-borrowck
status: drafting | ready | in-progress | frozen
created: 2026-09-03
updated: 2026-09-03
---
```

Flat `key: value` scalars only. No nesting, no allocator state — the next ID for
a kind is computed as `max(existing) + 1`, so the file cannot desynchronise from
its own counter.

## Sections

`## <n>. <Name>`. A section that holds items carries an HTML-comment marker
naming the ID prefix it accepts:

```markdown
## 10. Open Questions

<!-- items: Q -->
```

`spec.py add` inserts before the next `## ` heading. Sections without a marker
(Directions, Problem, Glossary, Interfaces, Handoff, Changelog) are prose — read
by humans and quoted by agents, never queried structurally.

### Guidance lives in HTML comments, not placeholder text

Handoff and Directions are checked for emptiness, so "has anyone written here
yet" has to be decidable. Their instructional text is an HTML comment, which
`spec.py` strips before deciding. Do not replace it with italic placeholder
prose: an earlier template seeded `- **Last session:** —`, which is non-empty
text, and the empty-handoff check could never fire on a real spec.

`handoff --set` and `directions --set/--add/--clear` preserve the leading
comment block and replace only what follows it.

## Items

```markdown
### Q-7 — Does SonarDelphi expose a CFG at the plugin API boundary?
- status: open
- blocks: [R-12, M-2]
- asked: 2026-09-03

If it does not, we either build CFG construction ourselves (~2 weeks) or fork
the plugin, which costs DelphiLint IDE integration.

> ANSWER:
```

Three parts, in order:

1. **Heading** — `### <ID> — <title>`. ID is `<PREFIX>-<n>`, never reused, never
   renumbered. The separator may be `—`, `–`, or `-`.
2. **Fields** — contiguous `- key: value` bullets immediately after the heading.
   Keys are `[a-z_]+`. Values are single-line scalars, or `[a, b, c]` lists.
   Empty, `~`, `TBD` and `unknown` all parse as null and are what `--unresolved`
   finds. Anything multi-line belongs in the body.
3. **Body** — free Markdown until the next `###` or `##`.

Field bullets must come before the body; the first non-field, non-blank line
ends the field block.

## Directions — the user's free-prose channel

`## 1. Directions` is the one section the user writes in freely, in any shape,
at any time. It is not parsed: no items, no fields, no format.

```markdown
## 1. Directions

<!-- guidance comment -->

- Wire `concursos` up as a consumer via a `uv` path dependency.
- Second thought on the CFG estimate — two weeks feels optimistic now.
```

Every session reads it before its own agenda and **drains** it: each line
becomes a typed item and is removed from here. It accumulates between sessions
and empties during them, so a non-empty Directions block means work is waiting.
`validate` warns while anything is left; `status` counts it.

This is deliberately a second channel alongside `> ANSWER:`, not a replacement:
answers reply to what the agent asked, Directions carries what the user brought
unprompted. See PROTOCOL.md.

## The ANSWER marker

Only on `Q-` items. A line matching `^>?\s*ANSWER:` opens the answer; everything
after it, to the end of the item, is the answer text (leading `> ` stripped).
Multi-line is fine. Write below the marker or on the same line, whichever:

```markdown
> ANSWER: No — the API only exposes the AST. Build our own CFG; two weeks is
> acceptable, I'd rather not fork.
```

Non-empty answer + `status: open` = the agent has work waiting. That pair is the
entire async handshake; see PROTOCOL.md.

## ID prefixes

| Prefix | Section | Required fields |
|---|---|---|
| `G` | Goals | `status`, `metric` |
| `NG` | Non-Goals | `status` |
| `C` | Constraints | `status` |
| `R` | Requirements | `status`, `acceptance`, (`covers`) |
| `D` | Decisions | `status`, `options`, `chosen` |
| `A` | Assumptions | `status`, `confidence`, `impact_if_wrong` |
| `Q` | Open Questions | `status`, `blocks` |
| `RK` | Risks | `status`, (`mitigation`) |
| `M` | Milestones | `status`, `covers` |

Parenthesised fields are warnings rather than errors in `validate`.

## Cross-references

Reference fields are checked for dangling IDs: `blocks`, `refs`, `covers`,
`satisfies`, `supersedes`, `from`. Conventions:

- `blocks: [R-12]` on a question — what stalls until it is answered.
- `covers: [G-2]` on a requirement, `covers: [R-3, R-4]` on a milestone.
- `supersedes: [D-3]` on a decision; set the old one to `status: superseded`
  rather than deleting it. Deleting loses the reason a path was abandoned, which
  is exactly what the next session will otherwise re-litigate.
- `from: [Q-7]` records provenance when an item was born from an answer.

## Status enums

```
G   proposed | accepted | dropped
NG  accepted | dropped
C   proposed | accepted | dropped
R   draft | specified | accepted | implemented | dropped
D   proposed | accepted | superseded | dropped
A   unconfirmed | confirmed | refuted
Q   open | answered | dropped
RK  open | mitigated | accepted | closed
M   planned | active | done | dropped
```

`validate` rejects anything outside these sets, so a typo'd status surfaces
immediately rather than silently dropping an item out of every future query.
