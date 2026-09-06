---
name: backlog-review
description: Review the notes vault backlog - give an overview grouped by project and theme, flag entries that are vague, stale, duplicated or superseded, and propose merges, rewrites, tags and drops. Use when the user wants to survey, triage, clean up or make sense of their backlog.
---

# backlog-review

Survey `Backlog.md` and improve it. This is a triage pass, not a development
pass — nothing here creates seeds. If an entry is ready to develop, say so and
point at `/backlog-develop`.

## Gather first

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
python3 "$VM" backlog list --json
python3 "$VM" projects --json
```

For any tagged entry whose project is a repo, check whether that project is still
live before recommending anything about it:

```sh
python3 "$VM" external-index && cat "$(python3 "$VM" path EXTERNAL_INDEX_FILE)"
```

The index is grouped by epic, so entries tagged at different members of one epic
belong together in the overview even though their tags differ — group by epic
first, then by project. An entry tagged at the epic itself is about the ambition
rather than any one member.

Judge staleness from **Last commit**, not from `updated:` — that field records
when tracking was migrated on most of these repos.

## Present the overview

Group **by tag first** — one cluster per project, then the untagged entries — and
within each cluster by theme, oldest first. An entry tagged at more than one
project appears in each of its clusters. Keep it scannable: a line per entry,
not a paragraph.

Then give an actual assessment. Be specific and be critical; a review that
approves of everything is worthless. Look for:

- **Vague entries** — a title nobody could act on, no description, no context.
  Say what question would have to be answered to make it actionable.
- **Stale entries** — old, untouched, and no longer interesting. Propose dropping
  them; an honest empty backlog beats a long dishonest one.
- **Duplicates and near-duplicates** — propose which one survives and what the
  merged entry should say.
- **Superseded entries** — the thing was already built, or the project it belongs
  to is `done`, or a later entry replaced it.
- **Missing tags** — untagged entries that plainly belong to an existing project.
  This is the highest-value fix: tagging routes an entry into that project's
  `*-iterate` instead of stranding it as a would-be new seed.
- **Orphaned tags** — tagged at a project that no longer exists or has graduated
  and gone `done`.
- **Ripe entries** — well-formed and worth developing now. Name the path you
  think each one belongs on (Idea, Learning, or Project) and why.

## Then act

Put the proposed changes to the user with `AskUserQuestion` — grouped, not one
question per entry. Multi-select where the choices are independent (which entries
to drop, which tags to add).

Apply each accepted change immediately, as it is accepted, through `vaultmeta` —
never by hand-editing `Backlog.md`:

- **drop** → `python3 "$VM" backlog remove "<title>"`
- **retag** → `python3 "$VM" backlog update "<title>" --tag <name> [<name2> ...]`
  (replaces the entry's whole tag set; `--clear-tag` to untag entirely).
- **retitle** → `python3 "$VM" backlog update "<title>" --title "<new title>"`.
- **rewrite** → `python3 "$VM" backlog update "<title>" --description "<new text>"`.
- **merge** → pick the entry that survives, update it once with the merged
  content and the **oldest** capture date of its inputs, then remove the rest:
  ```sh
  python3 "$VM" backlog update "<survivor title>" \
    --description "<merged text>" --captured <oldest-date>
  python3 "$VM" backlog remove "<absorbed title>"   # once per absorbed entry
  ```
  Update the survivor before removing the others — if a remove fails partway,
  the survivor already carries everything and nothing has been lost.

`update` reports each change as `field: old -> new`; read that back to the user
as confirmation rather than re-describing what you just asked them to approve.

Close with a two-line summary: what the backlog looks like now, and which entries
are worth developing next.
