---
name: project-session
description: Orient at the start of an ad-hoc session in a graduated project repo - surface the handoff, outstanding queue, and anything blocked or freshly written into DIRECTIONS.md. Use when starting or resuming work in a graduated project repo, before writing any code.
---

# project-session

The session-start counterpart to `/project-review` and `/project-implement`:
read-only orientation, not a revision or build pass. It runs the same
`vaultmeta spec` queries this vault's own `CLAUDE.md` recommends for
orienting in a few hundred tokens, as an explicit, repeatable trigger.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
```

## 0. The gate

```sh
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" gate review project "$NAME"
```

Every `error:` line is a hard stop - report it plainly and do not proceed.

## 1. Read five things, nothing else

```sh
python3 "$VM" spec handoff
python3 "$VM" spec status
python3 "$VM" spec blocked
python3 "$VM" spec directions
python3 "$VM" spec ls R --status specified --columns id,title,acceptance
```

Do not read `PROJECT_SPEC.md` whole - it's queried for a reason.

## 2. Report and stop

One short summary: what the last session's handoff says, the current status
line, anything blocked on an open question, anything sitting unprocessed in
`DIRECTIONS.md` (or the spec's `## 1. Directions` if still a vault seed), and
what's specified but not yet implemented. Do not edit any file, create a
branch, or implement anything - that's `/project-implement`'s job. Then wait
for the user's direction.
