---
name: audit
description: Critically review a project or learning track - its aven structure against the actual repository, guided first by what the user wrote into the project's inbox. Audits scope drift, architecture, unsupported done claims, missing evidence and implementation gaps, and writes accepted findings into aven without touching application code. Use when the user wants to review, audit, assess or take stock of a project or learning track.
---

# audit

A read, critique and propose pass. Writes go to aven (tasks, notes, metadata)
and, for capabilities confirmed shipped, `README.md` — **never** application
code, dependencies or configuration. Conventions:
`~/.claude/includes/aven-conventions.md`.

## 1. The user's agenda first

Run from inside the repo; aven infers the project.

```sh
aven list --status inbox            # what the user wrote: this pass's agenda
aven list --all --json               # the whole structure, drafts and done included
aven list --ready
aven list --blocked
aven-lint
```

Read `aven context` on the active POC or curriculum epic (its latest note is
the handoff), on the scope epic, and on any checkpoint or unit you discuss.
Read the README and recent `git log` — that, not `updated_at`, is the activity
signal. An empty inbox means a general review.

A repo with no structure in aven yet (only a project, or plain tasks) gets one
built from what is here: goals from what the README says the project is,
distinct demonstrable outcomes as POCs, phases that aren't outcomes as
checkpoints. Missing acceptance or verification stays draft (`backlog`), never
fabricated. Do this with the user, through `scope`'s interrogation rules.

## 2. Audit

Address every inbox line first: inspect what it names, test whether the
requested behaviour already exists, expose vague scope or contradictory
assumptions. Then:

- **Code**: correctness, security-sensitive boundaries, discarded errors, TODOs,
  dead or duplicated code, dependency risk.
- **Scope**: drift into non-goals; work happening that no checkpoint covers.
- **Structure**: is the first slice the cheapest falsifying experiment; are
  prerequisites explicit; is verification realistic; does each planned POC have
  an integrated acceptance scenario.
- **Claims**: anything `done` without an `Evidence:` note, or whose evidence no
  longer reproduces. Code that runs is not evidence.
- **Learning tracks**: is progress recorded per unit; are units marked done
  only when their `## Checkpoint` question was answered without notes; has the
  curriculum's order survived contact with reality.

Future draft POCs stay lightweight; do not demand speculative architecture.

## 3. Discuss and record

Present answers to the inbox lines before your own findings. Ask with
`AskUserQuestion` where the user's judgment changes scope, a recommendation
first. **Write each accepted finding immediately**:

| Finding | Where it goes |
|---|---|
| New work | checkpoint in the right POC, or a new draft POC for a separate outcome |
| Scope boundary | the POC's `## Scope` or the scope epic's `## Non-goals` |
| Decision, ruled-out approach, assumption, risk | note on the scope epic |
| Unresolved decision | `kind=question` task blocking what it gates |
| Implementation found complete | run its acceptance; record `Evidence:` then `done` — or leave it `active` with a note saying what is missing |
| Superseded checkpoint | cancel with a note naming the replacement; move its dependents |

Each inbox entry leaves `inbox` once represented — moved into the structure, or
canceled with a note saying where it went.

## 4. Finish

```sh
aven-lint
```

Rewrite the handoff as a new note on the active POC or curriculum epic: the
current checkpoint or unit and an executable next action. Update the README
only for capabilities you confirmed. Report findings recorded, entries drained,
and anything left for the user to decide — then ask whether that covers it.
