---
name: project-implement
description: Implement selected demonstrable checkpoints in a graduated project's current POC, verify their acceptance scenarios, and record evidence on a local branch. Reads PROJECT_SPEC.md and user Directions; does not perform a general audit.
---

# project-implement

Build selected checkpoint work, not an unsolicited audit. Respect instructions
and authorization already given in the session rather than asking for them again.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" gate review project "$NAME"
```

Gate errors stop this skill. A missing spec or version 1 spec requires a deliberate
project-review migration first. A missing Directions file is a warning; report it
and use the existing spec. Read `$TEMPLATES_DIR/Project/directions-vs-readme.md`
for ownership and completion rules.

## Select demonstrable work

```sh
python3 "$VM" spec directions
python3 "$VM" spec handoff
python3 "$VM" spec ls P --columns id,status,title,objective
python3 "$VM" spec ready
python3 "$VM" spec blocked
python3 "$VM" spec ls NG
```

Use explicit user selection when given. Otherwise offer available checkpoints and
raw Directions input with the structured input tool, recommending the first
available slice in the current POC. Include active/verifying work to resume.
Do not offer blocked work or silently activate draft POCs. If nothing is available,
report the blockers or empty queue; do not invent new work.

For selected raw input, settle its acceptance, verification and POC membership,
write a CP item before coding, then drain only the represented line. Move a global
exclusion only when explicitly authorized; otherwise surface the scope conflict.
Query each selected CP and its parent P, goals, relevant decisions and dependencies.
Run `spec validate` before coding; resolve structural or acceptance gaps in the
selected work rather than building against an invalid specification.

## Preflight and implement

Inspect git status. Preserve unrelated user edits; isolate the work in a branch or
worktree where needed. Ask only if a concrete overlap cannot be resolved safely.
For clean repos create a unique `implement/<date>-<checkpoint>` branch. Date comes
from the system. Keep the branch local unless pushing is explicitly authorized.

A checkpoint too large for a coherent demonstration can be superseded by smaller
CP slices. Preserve the original wording, use supersedes links, and redirect live
dependencies and question blockers to the replacements. Implement the authorized
slice(s), without treating an unfinished remainder as complete.

When the first checkpoint starts, set the project lifecycle to in-progress and
its POC to active; then set the checkpoint active. Read existing code, follow repository conventions and
implement only the scoped slice. Run the repository's normal checks (prefer its
check recipe/devshell), plus the checkpoint's verification procedure. Fixture
inputs, expected outputs and observed results must establish acceptance. Compiling
or passing unrelated tests does not establish a broader exit demo.

If checks fail, resolve failures within scope or stop remaining work and report.
Never force a commit through failing checks. If implementation is ready but its
demo fails or cannot run, leave CP verifying, document the gap and executable next
action, and do not claim completion.

## Evidence and handoff

Record observed evidence with a test, artifact or run reference, then set done:

```sh
python3 "$VM" spec set CP-n 'evidence=<observed result; reproducible reference>' status=done
```

Never invent evidence or weaken acceptance to obtain a green state. After all live
checkpoints in a POC complete, set P verifying and execute its integrated acceptance workflow.
Only its successful result warrants evidence and done on P. Do not automatically
start the next draft POC.

Update README usage for delivered behavior and tracking Log for project facts;
date/touch through the tool. Validate the spec. Commit each completed checkpoint
(or authorized coherent slice) with its code, spec and README/tracking updates.
No Co-Authored-By trailer. Do not commit unrelated changes.

Rewrite Handoff with the POC/checkpoint, blockers and executable next action.
Report branch, delivered demonstrations, evidence, incomplete verification and
remaining slices. State that the branch is local. Directions retains unselected
input; this skill does not drain it wholesale.
