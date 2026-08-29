---
name: backlog-develop
description: Take an entry from the notes vault backlog and develop it into a seed on one of the three paths - Idea, Learning or Project - or route it into an existing project it belongs to. Use when the user wants to develop, promote, flesh out or act on a backlog entry.
---

# backlog-develop

Turn one backlog entry into something that can actually be worked on. The entry
leaves `Backlog.md` either way — this file is a capture buffer, not a history.

## 1. Pick the entry

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
python3 "$VM" backlog list --json
```

If the user named an entry, use it. Otherwise offer the entries with
`AskUserQuestion`, oldest and best-formed first.

## 2. Branch on the tag

Check what the tag refers to:

```sh
python3 "$VM" projects --json
```

**Tagged at a project that exists** — this is almost certainly an *addition*, not
a new seed. Confirm that reading with the user before writing anything, then:

- the project is still a **vault seed** (`state: seed`) → invoke
  `learning-iterate` or `project-iterate` for that slug, handing it this entry as
  the material to fold in.
- the project has **graduated** (`state: repo`) → append the entry to that repo's
  `.claude/PROJECT.md` under `## Roadmap`, as a single bullet in the section's
  existing style. Do not add a `## Log` entry for it: the Log records what
  happened to the project, not what was filed about it.

**Untagged, or tagged at something that does not exist** — continue to step 3.

## 3. Establish the path

Interrogate before deciding. The three paths are not interchangeable and the
wrong choice is expensive:

- **Idea** — a claim, an observation, a connection. Something to think about and
  link to other thinking. It has no deliverable and never will. Ideas that stay
  ideas are a legitimate outcome, not a failure.
- **Learning** — the goal is *understanding*. The user writes the code; the
  output is a curriculum and a repo where the agent guides rather than
  implements. Choose this when "I want to know how X works" is the real driver.
- **Project** — the goal is a *deliverable* that gets published. Choose this when
  something specific has to exist at the end and someone else might use it.

The distinction that actually matters: **would you be satisfied if you understood
it but never shipped it?** Yes → Learning. No → Project.

Ask with `AskUserQuestion`, and give your own recommendation with its reasoning
rather than a neutral menu. If the entry is too thin to place, say so and ask the
one question that would settle it — do not file it somewhere to get it out of the
inbox.

## 4. Create the seed

Invoke the matching init skill — `idea-init`, `learning-init`, or `project-init`
— rather than writing the file yourself, so the intake questions stay in one
place. Pass along everything the entry already carries: title, description,
context, and its **capture date**, which becomes the seed's provenance rather
than today's date.

If the vault-level skills are unavailable (you are running outside the vault),
scaffold with `python3 "$VM" new <kind> <slug> --title "..." --captured <date>`
and tell the user to run the matching `*-iterate` from inside the vault.

## 5. Drain the entry

```sh
python3 "$VM" backlog remove "<title>"
```

Do this **last**, once the destination exists — the command prints the entry, so
if anything failed you still have its contents to re-file.

Report where it went in one line.
