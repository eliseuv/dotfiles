---
name: scope
description: Scope a new project or learning track in aven, or revise an existing one - interrogate the user into goals, non-goals and a first proof of concept with demonstrable checkpoints (or a curriculum of units for a learning track), and scaffold its repository once the scope passes aven-lint. Use when the user wants to start, plan, scope, spec out or iterate on a project or learning track, or to create the repo for one.
---

# scope

Settle what a project (or learning track) is before anything gets built, and
record it in aven as structure, not as a document. Read
`~/.claude/includes/aven-conventions.md` for the mapping; this skill assumes it.

## 0. New, or a resume?

```sh
aven project list
aven list --project <key> --all --json      # resume: what exists
aven list --project <key> --status inbox    # resume: what the user wrote
```

Read the user's goals list if they have one for context, never as something to
edit. On a resume, **fold the project's inbox in first** — the user's own input
outranks your agenda — then gap-fill rather than re-interview.

Choose an existing aven project as the grouping container, or create one when
needed. A project may hold several independent epics and needs no repo. The
epic owns its repo through `repo=<absolute-path>` metadata; record the intended
path while scoping, before scaffolding. Epics may share a repo. Aven project
path mappings only provide cwd inference and are added after the repo exists:

```sh
aven project create <name> --prefix <PREFIX>
```

## 1. Critique before capturing

Stress-test the premise before interrogating: the closest existing solution
(including another aven project — `aven search -A`), the hidden hard part, the
failure-prone assumption, and the cheapest experiment that would disprove the
premise. Prefer that experiment, or a small end-to-end slice, as the first
checkpoint. Let the critique change what you ask next.

## 2. Interrogate by uncertainty

Use `AskUserQuestion`, at most three meaningful questions per round, each with a
recommendation and real trade-offs. **Write every settled answer into aven
immediately** — no batching behind "shall I apply?"; the answer is the go-ahead.
Keep going until the user is satisfied, checking back in ("does this cover it?").

**The project epic** — one epic for this repo or learning track, holding its
scope and, as children, every POC, checkpoint and unit: `aven add "<name>" --epic --metadata
kind=project --metadata track=project|learning --metadata language=<flake>
--metadata repo=<absolute-path> --project <key> --status backlog`,
description sections in this order, as they settle:

- `## Problem` (project) or `## Motivation` (learning)
- `## Goals` — measurable. For learning, a capability ("implement a TLS
  handshake from the RFC and explain each message"), not a topic; offer two or
  three phrasings at different ambition levels.
- `## Non-goals` — push for at least two explicit exclusions.
- `## Prerequisites` (learning) — what the user already knows, so the curriculum
  doesn't start three units too early.
- `## Constraints`, `## Architecture`, `## Interfaces` (project, as needed for
  the current POC — not speculative infrastructure).

`language` names a fragment in `~/Projects/flakes/` (`<language>.flake.nix`); a
track wanting something without one is a legitimate answer, but say a fragment
must be written before scaffolding. Decisions, ruled-out approaches and
assumptions are notes on the project epic.

### Project: POCs and checkpoints

aven cannot nest epics, so POCs and checkpoints are both plain tasks in the
project epic (`aven epic add <task> <project-epic>`).

- **POC** — task, `kind=poc poc=P<n>`, sections `## Objective`, `## Scope`
  (POC-specific exclusions too), and once planned `## Acceptance` (an integrated,
  end-to-end scenario — completing checkpoints does not prove integration) and
  `## Verification`. It depends on each of its checkpoints (`aven dep add
  <poc> <checkpoint>`), so it closes last, on its own `Evidence:` note. Later
  POCs may stay `backlog` (draft) with only objective and scope; don't pretend
  their implementation is decided.
- **Checkpoint** — task, `kind=checkpoint cp=CP-<n> poc=P<n>` (the `poc` value
  names its POC within the same epic), sections `## Deliverables`,
  `## Acceptance` (pass/fail),
  `## Verification` (reproducible: commands, fixtures, expected output).
  Prerequisites are `aven dep add`; order of listing is not dependency.
  Prefer a narrow vertical slice that exposes the architectural risk over a
  horizontal subsystem checklist.
- **Open question** — task `kind=question` that `dep`-blocks what it gates.
  Park remaining uncertainty this way rather than expanding interrogation
  indefinitely.

Never manufacture evidence; it is recorded only after a demonstration runs. If
an answer changes settled scope, cancel the superseded checkpoint with a note
naming its replacement and redirect its dependents.

### Learning: the curriculum

Not before goals, prerequisites and non-goals are settled — units guessed early
get thrown away. Each unit is a task in the project epic, `kind=unit
unit=U<n>`, sections `## Theory`, `## Build`, `## Milestone`, `## Checkpoint` (a
question the user answers without notes), chained with `dep add` in order. A
track with independent strands tags each unit `topic=<letter>` and chains
units within their strand.

- Every unit ends in something built; "understand X" cannot be checked.
- Order by dependency, not by textbook tradition.
- Naive before optimised: the literal implementation comes first and survives
  as a differential-test oracle.
- Safety, security and concurrency invariants belong in the unit that
  introduces the thing, not a cleanup unit at the end.
- Five to eight units for most tracks.

## 3. Finish a scoping pass

```sh
aven-lint --epic <ref>
```

Resolve substantive gaps rather than filling placeholders. Leave a note on the
project epic beginning `Handoff:`, naming the current POC and checkpoint (or
unit) and an executable next action — the latest such note is the handoff. Present the acceptance
scenario, first slice, boundaries, decisive choices and open questions, and get
sign-off unless it was already given this session.

## 4. Scaffold the repo — only when asked, and only through the gate

**The gate.** Refuse, and say why, unless all hold:

- `aven-lint --epic <ref>` reports no errors;
- the project epic exists with goals and non-goals;
- project: at least one POC in `todo`/`active` with at least one checkpoint;
  learning: at least one unit;
- the destination directory does not exist.

Destination: the epic's `repo` path, normally
`~/Projects/project/<name>` or `~/Projects/learning/<name>`.
Scope and lint this epic independently of other epics in the same project.
POC, checkpoint and unit IDs are local to the epic (and topic for units).

```sh
REPO=~/Projects/<project|learning>/<name>
FRAGMENTS=<this skill's directory>/assets/gitignore
mkdir -p "$REPO"
cat "$FRAGMENTS/base.gitignore" "$FRAGMENTS/<language>.gitignore" > "$REPO/.gitignore"  # omit the second if absent
command cp -f ~/Projects/flakes/<language>.flake.nix "$REPO/flake.nix"
echo "use flake" > "$REPO/.envrc"
git -C "$REPO" init
aven edit <ref> --metadata "repo=$REPO"
aven project path add <key> "$REPO"
```

`cp` is aliased to `cp -iv` here, and `cp -f` does not override that — use
`command cp -f`.

- **`README.md`** — `# <Title>`, one or two sentences on what it is, then
  installation/usage/prerequisites as warranted. Draw on Problem and
  Interfaces; never restate goals, POCs or checkpoints — they live in aven.
- **`CLAUDE.md`** — learning tracks only: `@~/.claude/includes/assisted-learning.md`.
  Project repos need none; the conventions are global.

**Do not commit.** The initial commit is the user's — say so. Report the repo
path, what was scaffolded, and that `aven list` inside it now resolves to the
project.
