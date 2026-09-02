---
name: project-implement
description: Work through a graduated project repo's DIRECTIONS.md To-do list and implement selected items on a branch. Use when the user wants to act on, build, tackle, or knock out items from a project's outstanding to-do list, rather than just planning or reviewing them.
---

# project-implement

`DIRECTIONS.md`'s `## To do` is user → agent, editable "at any time, in any
session" — this skill is the session where it actually gets acted on. It
reads whatever is currently there; it doesn't require a `/project-review` or
`/project-iterate` pass to have just run, and it isn't the place those
skills' own review/critique work happens — this only implements, on a
dedicated branch, items the user explicitly picks.

**This is an implement skill, not a review skill.** `/project-review` is
read/critique/propose only, and finds new candidate to-do items; this skill
does the opposite — it doesn't audit, critique, or add new items, it builds
what's already accepted into `## To do`.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
```

## 0. The gate

This only runs against a graduated **project** repo with a `DIRECTIONS.md`
already in place.

```sh
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" gate review project "$NAME"
```

Every `error:` line is a hard stop — report it plainly and do not proceed
(not tracked under this name, tracked under the wrong bucket, still a vault
seed, no `.claude/PROJECT.md`, or no `vault_ref:`).

A `warn:` about a missing `DIRECTIONS.md` means this repo predates the
current file split. Unlike `/project-review`, this skill does **not**
migrate it on the spot — tell the user to run `/project-review` or
`/project-iterate` first to get `DIRECTIONS.md` scaffolded, then stop.

A `warn:` about `.claude/PROJECT.md`'s body heading is not this skill's
concern — proceed.

## 1. Read the to-do list

Read `DIRECTIONS.md`'s `## To do` and `## Not doing` in full. `## Not doing`
is context for step 4, not something to act on.

If `## To do` is empty, say so and stop. There's nothing to implement.

## 2. Offer

Present every `## To do` item with `AskUserQuestion` (multi-select): "Which
of these should I implement now?" Don't pre-select anything, and don't rank
or filter the list yourself — the user decides what's worth doing today.

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

For each one:

**Check it against `## Not doing` first.** If it conflicts with an explicit
exclusion, don't implement it — flag the conflict and move to the next
item. A stated boundary outranks a to-do line that drifted past it.

**Judge feasibility.** A concrete, scoped item (references specific
files/functions, or is a small well-defined addition) gets implemented
directly. A big or vague one — spans an unwritten subsystem, bundles several
undecided design questions, reads like a milestone rather than a task (e.g.
"DSL, parser and evaluator: parse to a DAG, evaluate by topological walk...")
— gets decomposed first: replace the single `## To do` line with an ordered
breakdown into smaller, concrete steps (the phased style already used in
mature repos' `DIRECTIONS.md` files is the model to follow), then treat only
the first of those sub-items as this pass's actual implementation target.
The rest stay in `## To do` for a future pass.

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

**Write back.** Remove the finished item (or slice) from `DIRECTIONS.md`'s
`## To do` — if it was decomposed, leave the remaining sub-items in place.
Add or update its description in `README.md`, same agent-maintains-README
convention as always: `README.md` is agent → user, and keeping it accurate
as work finishes is this skill's job, not the user's. Add one `## Log` entry
to `.claude/PROJECT.md` — a fact about the project ("implemented X"), never
a description of the tooling action itself.

```sh
python3 "$VM" touch .claude/PROJECT.md
```

**Commit.** One commit per item (or per decomposed slice): the code change
together with its `DIRECTIONS.md`/`README.md`/`PROJECT.md` updates, since
those updates are part of finishing the work, not a separate step. Do
**not** add a `Co-Authored-By` trailer.

## 5. Report

State the branch name, then one line per selected item: implemented /
decomposed and partially implemented (name the sub-item that landed) /
skipped for conflicting with `## Not doing` / stopped on failing checks.
Close by reminding the user the branch is local-only and not pushed — it's
theirs to review before it goes anywhere.
