---
name: project-review
description: Review a graduated project against its POC outcomes and demonstrable checkpoints, guided by user Directions. Audit scope, architecture, evidence and implementation gaps; migrate old specifications and write accepted findings into PROJECT_SPEC.md without changing application code.
---

# project-review

This is a read, critique and propose pass. Directions leads the agenda; tagged
backlog entries supplement it. An empty channel means a general review.

Writes are limited to PROJECT_SPEC.md (including migration backup), Directions
(draining user input only), tracking frontmatter/Log, README descriptions of
capabilities confirmed shipped, and vault Backlog entries handled by this pass.
Do not patch application code, dependencies or configuration while reviewing.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" gate review project "$NAME"
```

Stop on gate errors: wrong tracking bucket, missing tracking/vault_ref, or still a
seed (use project-init). A tracking body warning permits only the indicated heading
repair. Read the shared `$TEMPLATES_DIR/Project/directions-vs-readme.md` rules and
the project-init grammar/rubric under `$VAULT_DIR/.claude/skills/project-init/references/`.

## Compatibility and missing channels

Version 1: preview `spec migrate --to 2`, inspect its mapping and gaps, then apply.
The tool preserves R/M records and writes a `.v1.bak`; do not overwrite or delete
that backup. It creates conservative checkpoints from milestones and uncovered
requirements, without inventing verification or dependencies. Confirm explicit
release/phase boundaries as successive POCs. Preserve old completion as history;
new verifying checkpoints still need actual evidence before done. Fill only gaps
that existing scope or user answers establish.

Missing spec: initialize version 2 using the vault template, with category,
language and original started date from tracking. Preserve all existing planning
content, reasoning, exclusions and shipped history in item bodies or legacy prose.
Goals derive from what the README says the project is, not just outstanding tasks.
Translate phases into POCs only where they describe distinct demonstrable outcomes;
otherwise make them checkpoints. Turn uncertainty into Q/A and settled alternatives
into D records. Missing acceptance or verification stays draft, never fabricated.

Missing Directions: read any seed section before creating the standalone file,
remove the section, then carry its exact content into the new file. If Directions
already exists, remove the empty section introduced by init before calling channel
commands. Both channels together are an error. Never guess which input to discard.
These channel movements preserve user text; they do not authorize agent proposals.

## Read the user's agenda, then audit

```sh
python3 "$VM" spec directions
python3 "$VM" spec inbox
python3 "$VM" spec pending
python3 "$VM" spec handoff
python3 "$VM" spec status
python3 "$VM" spec ls P
python3 "$VM" spec ready
python3 "$VM" spec blocked
python3 "$VM" spec ls NG
python3 "$VM" backlog list --tag "$NAME"
```

Read README, tracking Log and vault Goals.md. Use get for relevant checkpoints and
POCs, including draft and blocked work; ready alone is not the full review scope.
Legacy R/M records remain queryable for rationale but are never the active queue.

Process answered questions into durable items before resolving them. Address every
Directions line first: inspect the named subsystem, test whether requested behavior
already exists, and expose vague scope or contradictory assumptions. Then audit
correctness, security-sensitive boundaries, discarded errors, TODOs, duplicated or
dead code, dependency risks, non-goal drift and mismatches with acceptance.

Review POC structure too: cheapest falsifying experiment, a useful first vertical
slice, explicit dependencies, realistic verification, missing integrated demos,
and claims of done unsupported by evidence. Future drafts should stay lightweight;
do not require speculative architecture simply to fill a template.

## Discuss and record

Present answers to Directions before other findings. Use structured questions with
real choices and a recommendation where user judgment materially changes scope.
Write each accepted finding immediately; authorization already given need not be
reconfirmed. Map new work to a CP in the appropriate POC (or a new draft POC for a
separate outcome); scope boundaries to NG or P.scope; choices to D; risks to RK;
premises to A; unresolved decisions to Q with explicit P/CP blockers.

A completed implementation discovered during review is not automatically done:
run or inspect actual acceptance evidence, recording it, or leave the checkpoint
verifying. POC completion additionally needs its integrated scenario. Update README
only for the confirmed capability, not as a broad rewrite.

Decompose by superseding, retaining original content and redirecting live
prerequisites/blockers. Never edit legacy R/M records. Work that fails a proof
can lead to revised scope or a retired checkpoint; do not label it successful.

Drain accounted-for Directions as items are recorded. Keep unresolved user input
visible rather than deleting it to satisfy a warning. Remove tagged Backlog entries
only once every tagged destination has received its share.

## Finish

Validate, touch tracking through the tool, and rewrite Handoff naming P/CP IDs,
blockers and the next executable action. Log project decisions/outcomes, never
"ran review" or "migrated the file". Report guided versus unguided review, how user
input resolved, accepted checkpoint/POC changes, demonstrated capabilities, risks,
and unresolved migration or verification gaps. Do not change code in this pass.
