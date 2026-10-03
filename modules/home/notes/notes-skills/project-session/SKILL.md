---
name: project-session
description: Orient at the start of a graduated project session by surfacing its current POC, available checkpoints, blockers, handoff and user Directions. Read-only; use before implementation or review.
---

# project-session

Resolve the vault and configuration:

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" gate review project "$NAME"
```

Report and stop on gate errors. Otherwise read these compact queries:

```sh
python3 "$VM" spec directions
python3 "$VM" spec handoff
python3 "$VM" spec status
python3 "$VM" spec ls P --columns id,status,title,objective
python3 "$VM" spec ready
python3 "$VM" spec blocked
```

Use get only for the current POC/checkpoint when more detail is needed. Do not read
PROJECT_SPEC.md whole to orient. Read vault Goals.md for broader context; do not
infer activity from updated dates or look for the retired epic subsystem.

Report the current POC's intended demonstration, active/verifying checkpoint,
available next slice, explicit blockers, and unprocessed user input. Recommend the
first available checkpoint in the current POC without treating order as dependency.
If the checkpoint queue is empty, inspect verifying POCs and active/planned POCs
whose live checkpoints are all done. Their integrated acceptance demo may be the
next action; do not report the project complete from an empty queue alone.
On version 1, ready shows legacy work; note that project-review should migrate it
before checkpoint implementation. Existing R/M in version 2 are historical only.

Stop after orientation. No edits, branches, migrations, implementation or channel
draining happen in this skill.
