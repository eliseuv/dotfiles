# Work tracking with aven

Aven is the single source of truth for anything with a lifecycle: captured
thoughts, project scope, proofs of concept, checkpoints, learning curricula and
goals. Repos carry code and an agent-maintained `README.md`, nothing else for
tracking. Ideas — permanent prose with no lifecycle — live as plain markdown in
`~/Documents/ideas`, outside aven.

Structure is expressed with aven's own primitives plus a `kind` metadata key.
`aven-lint` checks the rules below; run it after changing a project's structure.

## The mapping

| Concept | In aven |
|---|---|
| Captured, untriaged thought | task, `status=inbox` — in the project inferred from cwd, else unassigned |
| Project or learning track | aven project; mapped to a repo path only once the repo exists |
| Project epic (scope and all planned work) | the one epic of the aven project, `kind=project track=project\|learning language=<flake>`; sections `## Goals` (measurable), `## Non-goals`, and as needed `## Problem`/`## Motivation`, `## Prerequisites`, `## Constraints`, `## Architecture`, `## Interfaces`. Every POC, checkpoint and unit is its child |
| Decision, ruled-out approach, assumption, risk | note on the project epic |
| Proof of concept | task `kind=poc poc=P1`, child of the project epic, sections `## Objective`, `## Scope`, `## Acceptance` (the integrated scenario), `## Verification`; depends on each of its checkpoints, so it closes last |
| Checkpoint | task `kind=checkpoint cp=CP-3 poc=P1`, child of the project epic, sections `## Deliverables`, `## Acceptance`, `## Verification` |
| Prerequisite | `aven dep add <checkpoint> <prerequisite>` |
| Open question | task `kind=question` that blocks what it gates (`dep add`) |
| Evidence | note beginning `Evidence:`, appended before a checkpoint or POC goes `done` |
| Handoff | the latest note beginning `Handoff:` on the project epic — `aven context` shows it |
| Learning unit | task `kind=unit unit=U2`, child of a `track=learning` project epic, sections `## Theory`, `## Build`, `## Milestone`, `## Checkpoint`; progress as notes; units chained in order with `dep add`. A track with parallel strands tags each unit `topic=<letter>` and chains within the strand |
| Goal spanning projects | epic `kind=goal`; children may belong to any project |

## Status meanings

- `inbox` — captured, not looked at. Only triage moves things out of it.
- `backlog` — accepted but not planned; for a POC or checkpoint, a **draft**
  (structure not yet required).
- `todo` / `active` — planned or in progress; the full section set is required.
  Implemented-but-unverified stays `active`, with a note saying what is missing.
- `done` — finished, with observed evidence. `canceled` — dropped; say why in a note.

Project status is derived, not stored: paused means its open tasks are deferred
with `--available-at`; frozen means it has no open tasks.

## Channels

- **User → agent**: the user runs `aven add "..."` from inside a repo, landing
  in that project's inbox. Never create inbox tasks on the user's behalf unless
  asked — mixing your proposals in makes their input unreadable.
- **Agent → user**: `README.md` — a brief presentation and usage instructions.
  Keeping it accurate is part of finishing work. It never restates scope, POCs
  or checkpoints; those live in aven.

## Rules

- Notes record facts about the subject — decisions, scope settled, approaches
  ruled out, evidence. Never tooling actions ("migrated", "added metadata").
- Never invent a next step. If a project has none recorded, say so.
- One epic per aven project. aven cannot nest epics, so POCs are tasks, not
  epics; a checkpoint names its POC through `poc=` metadata.
- No repo is created without a project epic with goals and non-goals, a planned
  POC with at least one checkpoint (or at least one unit), and a clean
  `aven-lint --project <key>`. The `scope` skill owns that gate.
- Skills: `capture` (never asks), `triage` (drains the inbox), `scope` (settles
  structure, scaffolds repos), `audit` (reviews a project against its repo).
- Keep task refs out of commits, PRs and anything external.
