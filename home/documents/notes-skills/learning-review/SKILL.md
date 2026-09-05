---
name: learning-review
description: Critically review a graduated learning repo's ROADMAP.md, guided by its own ## Direction notes - fold in tagged backlog entries, reorder or add or cut units, and keep the progress table honest. Use when the user wants to iterate on, restructure or expand the curriculum of a learning project that has already graduated out of the vault.
---

# learning-review

The post-graduation counterpart to `/learning-init`. That skill shapes the
curriculum outline while the seed is still in `Learning/`; this one revises the
curriculum after graduation, when it lives as `ROADMAP.md` in a repo under
`$LEARNING_REPOS_DIR` and there is no vault seed left to edit.

This is a structural pass, not day-to-day bookkeeping. Marking a unit done,
logging progress notes, and recording detours are things the agent already does
during ordinary learning sessions per the repo's `CLAUDE.md`
(`Templates/Learning/assisted-learning.md`) — leave that alone here. This skill
is for when the curriculum itself needs to change: new goals surfaced, a unit
turned out to be two, scope needs cutting.

**This pass is guided by `## Direction`, not just informed by it.** Whatever
the user wrote there — a unit to reconsider, a subject to fold in, a doubt
about where the curriculum is headed — is the actual agenda for this revision,
not one more item competing with the agent's own proposals. An empty
`## Direction` means an unguided pass: fall back to proposing revisions on the
agent's own judgment, same as before this section existed.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
```

## 0. The gate

This only runs against a graduated learning repo — not a vault seed (that's
`/learning-init`) and not a project repo.

```sh
python3 "$VM" gate review learning <name>
REPO="$LEARNING_REPOS_DIR/<name>"
```

Every `error:` line is a hard stop — report it plainly and do not proceed
(not tracked under this name, tracked under the wrong bucket, still a seed,
no `.claude/PROJECT.md`, no `vault_ref:`, or missing `ROADMAP.md` — ask the
user how to handle a missing `ROADMAP.md` rather than scaffolding one
unasked).

**A `warn:` about `.claude/PROJECT.md`'s body** means fix just that heading
to `## Log` in place before continuing — leave the content beneath it
untouched, this is a heading fix, not a content migration.

## 1. Read Direction first — it sets this pass's agenda

Read `ROADMAP.md`'s `## Direction` section before anything else. This is not
backlog material to hold for later — it's the brief for step 2. A named unit
gets reconsidered directly; a subject the user wants folded in gets weighed
against the existing sequence; a vague doubt gets chased down until it
resolves one way or the other. If it's empty, note that and proceed to an
unguided pass in step 2.

Then pull tagged backlog entries — these supplement Direction, they don't
replace it. Once the seed is deleted, `<name>` (the repo directory name) is
what backlog entries get tagged with, still in `vaultmeta projects`'
vocabulary:

```sh
python3 "$VM" backlog list --tag <name>
```

Hold both Direction's items and the backlog entries for step 2. Drain each
once its fate is decided — a backlog entry via the tool, a `## Direction` line
by removing it directly from the file:

```sh
python3 "$VM" backlog remove "<title>"
```

Do this before proposing anything of your own — same rule as every other
`*-init`/`*-review` skill: the user's captured thoughts outrank your
suggestions.

## 2. Read state, then propose — Direction leads, the principles fill in

Read `ROADMAP.md` in full, including every unit's `### Progress notes` and the
`## Progress at a glance` table. A unit already marked `Done` or `In progress`
is not free to cut or reorder out from under the learner without saying so
explicitly — surface that tension rather than silently proposing it away.

**If step 1 found anything in `## Direction`, address it first.** Is a named
unit really scope creep or a legitimate addition; does splitting a unit the
user is unsure about actually help; does the roadmap already cover the doubt
they raised. This is what the pass was actually for, and it takes priority
over any revision the agent would otherwise propose on its own.

**Then formulate whatever else the state of the roadmap calls for** — the
default pass, and the whole pass when `## Direction` was empty: units to add,
split, merge, reorder, or cut. The same principles `/learning-init` uses
for new units apply to revised ones, whether the revision came from
`## Direction` or from this step's own read of the roadmap:

- **Each unit ends in something built.** Not "understand X."
- **Order by dependency**, not tradition — and not by the order units happened
  to be drafted in originally.
- **Naive before optimised, always.** If a "unit" is really "the optimised
  version of unit N," it goes after unit N, not folded into it.
- **Safety, security and concurrency invariants are correctness**, not a
  cleanup pass — they belong in the unit that introduces the thing.
- **Five to eight units total** stays the target. Growth past that is a sign
  scope needs to move to `## Where to go next` instead of another unit.

Hold everything formulated here for step 3 — nothing gets put to the user yet.

## 3. Present revisions critically

Put every proposal — Direction-driven or not — to the user with
`AskUserQuestion`, in rounds: real alternatives with trade-offs, one
recommended, not a neutral menu. Be critical of your own proposals too, and
say so when:

- A `## Direction` question resolves to "the roadmap already handles this" —
  report that as the answer, don't invent a unit change to justify the pass.
- A proposed unit duplicates ground an earlier unit's `### Milestone` already
  covers.
- The learner is asking to skip ahead past a prerequisite the roadmap itself
  established.
- Cutting a unit would strand a later one that depends on it.
- The revision is really scope creep dressed as curriculum — check
  `python3 "$VM" projects` for whether it's actually a separate project.

Keep going until the user has made a call on everything raised, not just the
first pass' worth.

## 4. Write the roadmap

**Every accepted change is written into `ROADMAP.md` immediately** — no
batching. Update `## Progress at a glance` in the same edit as any unit
add/remove/reorder, so the table and the sections underneath never drift apart.
Use the unit template shape from `Templates/Learning/roadmap-template.md` for
anything new: `### Theory` / `### Build` / `### Milestone` / `### Checkpoint` /
`### Progress notes` (new units start `_No progress logged yet._`).

```sh
python3 "$VM" touch "$REPO/.claude/PROJECT.md"
```

Add a `## Log` entry to `.claude/PROJECT.md` for what changed — what
`## Direction` asked and how it resolved, units added, cut, reordered, scope
narrowed. Not "edited ROADMAP.md"; the fact, not the tooling action, same rule
as vault `## Log` entries.

Drain every backlog entry that got folded in:

```sh
python3 "$VM" backlog remove "<title>"
```

## 5. Report

State up front whether this was a guided pass (`## Direction` had content) or
an unguided one (it was empty), and if guided, how each item resolved before
anything else. Then report which units changed and confirm nothing marked
`Done` or `In progress` was touched without the user explicitly agreeing to
it.
