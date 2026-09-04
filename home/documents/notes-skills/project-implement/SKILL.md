---
name: project-implement
description: Work through a graduated project repo's outstanding requirements and implement selected ones on a branch. Reads PROJECT_SPEC.md's specified requirements and anything the user has written into DIRECTIONS.md. Use when the user wants to act on, build, tackle, or knock out outstanding work from a project, rather than plan or review it.
---

# project-implement

The session where outstanding work actually gets built. It reads two things: the
requirements `PROJECT_SPEC.md` says are specified but not yet implemented, and
whatever the user has written into `DIRECTIONS.md` since anyone last looked. It
does not require a `/project-review` pass to have just run — a line the user
wrote an hour ago is buildable today.

**This is an implement skill, not a review skill.** `/project-review` is
read/critique/propose only, and finds new candidate work; this skill does the
opposite — it doesn't audit, critique, or go looking for problems, it builds
what the user picks.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
```

## 0. The gate

This only runs against a graduated **project** repo with a `PROJECT_SPEC.md`
already in place.

```sh
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" gate review project "$NAME"
```

Every `error:` line is a hard stop — report it plainly and do not proceed
(not tracked under this name, tracked under the wrong bucket, still a vault
seed, no `.claude/PROJECT.md`, or no `vault_ref:`).

**A `warn:` about a missing `PROJECT_SPEC.md`** means the repo predates the spec
format. Unlike `/project-review`, this skill does **not** migrate it — tell the
user to run `/project-review` first, then stop. Migration is a judgment-heavy
pass that belongs with the skill that reads the whole repo anyway.

**A `warn:` about a missing `DIRECTIONS.md`** is not fatal here: the user has
nowhere to write, but there is still a spec to build from. Mention it and carry
on.

## 1. Read the queue

Three commands. The first two are the queue; the third is what must stay off it.

```sh
python3 "$VM" spec ls R --status specified --columns id,title,acceptance
python3 "$VM" spec directions
python3 "$VM" spec blocked
```

`spec blocked` lists items stalled by an unanswered `Q-`. **Never offer a
blocked item.** Its design question is still open with the user, and building
against an unanswered question is how you produce work that has to be thrown
away. Say which items you withheld and why.

Read `spec ls NG` too, and hold it — it is the fence for step 4.

If both the specified list and `DIRECTIONS.md` are empty, say so and stop.
There is nothing to implement, and inventing work is `/project-review`'s job,
not this skill's.

## 2. Offer

Present everything with `AskUserQuestion` (multi-select): "Which of these should
I implement now?" Label the two sources separately — a `R-` item has been
through a review pass and has acceptance criteria; a `DIRECTIONS.md` line is
raw, and picking it means agreeing on what "done" means before any code is
written.

Don't pre-select anything, and don't rank or filter the list yourself — the user
decides what's worth doing today.

If nothing is selected, stop here.

## 3. Preflight

```sh
git status --porcelain
```

If this is not empty, show what's uncommitted and ask whether to stop
(default) or proceed anyway. Never silently build new work on top of the
user's uncommitted changes.

If clean, create and switch to a new branch for this session:

```sh
git checkout -b "implement/$(date +%F)"
```

## 4. Work each selected item, in the order presented

**If it came from `DIRECTIONS.md`, make it an item first.** Agree the acceptance
criterion with the user, write it down, and drain the line — before any code:

```sh
python3 "$VM" spec add R "<the requirement>" --set acceptance="<how you'd know>" 'covers=[G-n]'
python3 "$VM" spec directions --set "<whatever is left>"
```

Writing the item before the code is the point. It is what makes the work
reviewable later, and it is the only moment the user is present to say what
"done" means.

Then, for every item:

**Check it against the non-goals first.** If it conflicts with an `NG-` item,
don't implement it — flag the conflict and move to the next one. A stated
boundary outranks a request that drifted past it. If the user wants the boundary
moved, that is a `/project-review` decision, not something to do quietly here.

**Judge feasibility.** A concrete, scoped item (references specific
files/functions, or is a small well-defined addition) gets implemented
directly. A big or vague one — spans an unwritten subsystem, bundles several
undecided design questions, reads like a milestone rather than a task — gets
decomposed first:

```sh
python3 "$VM" spec set R-3 status=superseded
python3 "$VM" spec add R "<first slice>" --set acceptance="..." 'supersedes=[R-3]' status=specified
python3 "$VM" spec add R "<the rest>"    --set acceptance="..." 'supersedes=[R-3]' status=specified
```

The original keeps its wording and drops out of the rubric; the slices carry the
work. Implement only the first slice this pass — the rest are queue for a future
one.

**Implement.** Read the relevant existing code before writing. Follow the
repo's own conventions — module layout, error handling style, naming. Match
the vault-wide discipline of minimal, targeted diffs: no unrelated
refactors, no speculative abstractions beyond what this item calls for.

**Verify locally.** Prefer the repo's own `justfile` `check` recipe if one
exists. Otherwise run the language-appropriate checks through the repo's
`flake.nix` devshell — for Python, tests (`pytest`/`uv run pytest`), lint
(`ruff check`), type-check (`basedpyright`); for Rust, `cargo test`, `cargo
clippy`, `cargo fmt --check`. If checks fail and can't be resolved as part of
finishing this item, stop working the remaining items, leave this one
uncommitted, and report the failure plainly. Never force a commit through a
failing check.

**Write back.** The item is never deleted — it changes status:

```sh
python3 "$VM" spec set R-n status=implemented
python3 "$VM" touch .claude/PROJECT.md
```

Then update `README.md` to describe what now exists, same
agent-maintains-README convention as always: `README.md` is agent → user, and
keeping it accurate as work finishes is this skill's job, not the user's. Never
restate the requirement itself there — that lives in the spec. Add one `## Log`
entry to `.claude/PROJECT.md`: a fact about the project ("implemented X"), never
a description of the tooling action.

If the item completes every requirement a milestone covers, set the milestone
`status: done` as well — `spec get M-n` shows what it covers.

**Commit.** One commit per item (or per decomposed slice): the code change
together with its `PROJECT_SPEC.md`/`README.md`/`PROJECT.md` updates, since
those updates are part of finishing the work, not a separate step. Do
**not** add a `Co-Authored-By` trailer.

## 5. Rewrite the handoff, then report

```sh
python3 "$VM" spec handoff --set "- **Last session:** implemented R-4, R-6 (SARIF writer); decomposed R-3 into R-9/R-10.
- **Now blocked on:** nothing.
- **Next action:** R-9 — the plain-text writer, against the same diagnostic struct R-6 introduced."
```

"Next action" must be executable by someone with no memory of this session.

Then report: the branch name, then one line per selected item — implemented /
decomposed and partially implemented (name the slice that landed) / skipped for
conflicting with an `NG-` item / withheld as blocked by an open question /
stopped on failing checks. Close by reminding the user the branch is local-only
and not pushed — it's theirs to review before it goes anywhere.
