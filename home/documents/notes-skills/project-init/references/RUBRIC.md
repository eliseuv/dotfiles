# Completeness rubric

`spec.py validate` implements this. It exists so that "iterate until the spec is
detailed enough" terminates on a checkable condition rather than on the model
deciding it has asked enough questions.

Run it with `--json` to branch on the result; exit code 1 means errors.

## Errors — the spec is not ready

**Every goal has a metric.**
A goal without a measurable criterion cannot be failed, so it cannot steer any
decision. "Fast enough" is not a metric; "analyzes 100k LOC in under 30s on the
CI box" is. This is the single check that catches the most hand-waving.

**Every requirement has acceptance criteria.**
The line an implementation agent will be judged against. If you cannot state how
you would know it works, the requirement is still an aspiration.

**Every decision records rejected options and a choice.**
`options` plus `chosen`. Without the rejected list, a future session cannot tell
whether an alternative was considered and dismissed or simply never occurred to
anyone — and will spend a session rediscovering it.

**Every assumption has `confidence` and `impact_if_wrong`.**
These two fields are what make an assumption safe to proceed on. Together they
give the human a triage list: scan for `high` impact and `low` confidence, refute
those, ignore the rest.

**Every milestone lists the requirements it covers.**
A milestone that covers nothing is a date with no content.

**Non-goals is non-empty.**
Scope without a fence expands to fill the available time. If nothing was ruled
out, the scope conversation did not actually happen. This check has no technical
justification and is worth more than most of the ones that do.

**No unanswered question blocks the first milestone.**
You may ship a spec with open questions — but not ones that block the work about
to start. Those must be answered or downgraded to assumptions.

**Structural integrity.** Unique IDs, statuses within their enum, no dangling
cross-references. Cheap to check, and a typo'd status silently drops an item out
of every future query.

## Warnings — probably wrong, occasionally fine

- A requirement not linked to any goal via `covers` — usually scope creep, though
  some infrastructure requirements legitimately serve no user-visible goal.
- A decision with no rationale body. The `chosen` value says what; six weeks
  later only the body says why.
- A risk with no mitigation. Sometimes correct: an accepted risk is a real
  position, but mark it `status: accepted` deliberately.
- An answered question not yet folded into a durable item.
- **Undrained `## 1. Directions` content.** The human wrote something and the
  session ended without folding it into an item. A warning rather than an error
  because the human may write while a session is mid-flight — but at session
  end it means their input was left on the floor, which is the failure this
  whole channel exists to prevent.
- An empty handoff block.

Use `--strict` to treat warnings as failures. Reasonable before flipping to
`ready`; too aggressive during drafting.

## What the rubric deliberately does not check

Length, section prose, or whether the architecture is any good. A spec can pass
every check and describe a bad project. The rubric guarantees the spec is
*answerable and actionable*, not that it is *right* — that is what the adversarial
pass at the start of `project-init` is for, and no static check substitutes for it.
