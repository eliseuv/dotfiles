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
| Scope (goal, non-goals, success metric) | epic `kind=scope`, description sections `## Goals`, `## Non-goals` |
| Proof of concept | epic `kind=poc poc=P1`, sections `## Objective`, `## Scope`, `## Acceptance`, `## Verification` |
| Checkpoint | task `kind=checkpoint cp=CP-3`, child of its POC epic, sections `## Deliverables`, `## Acceptance`, `## Verification` |
| Prerequisite | `aven dep add <checkpoint> <prerequisite>` |
| Open question | task `kind=question` that blocks what it gates (`dep add`) |
| Evidence | note beginning `Evidence:`, appended before the checkpoint goes `done` |
| Handoff | the latest note on the active POC epic — `aven context` shows it |
| Learning unit | task `kind=unit`, child of an epic `kind=curriculum`; build and milestone in the description, progress as notes |
| Goal spanning projects | epic `kind=goal`; children may belong to any project |

## Status meanings

- `inbox` — captured, not looked at. Only triage moves things out of it.
- `backlog` — accepted but not planned; for a POC or checkpoint, a **draft**
  (structure not yet required).
- `todo` / `active` — planned or in progress; the full section set is required.
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
- No repo is created for a project without a scope epic and a POC with at least
  one checkpoint, and a clean `aven-lint --project <key>`.
- Keep task refs out of commits, PRs and anything external.
