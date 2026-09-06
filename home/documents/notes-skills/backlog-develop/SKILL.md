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

## 2. Branch on the tags

An entry can carry more than one tag (`tag: #a #b`). Check what each refers to:

```sh
python3 "$VM" projects --json
```

**Tagged at one or more projects that exist** — this is almost certainly an
*addition*, not a new seed. Confirm that reading with the user before writing
anything, then handle every matching tag before draining the entry — graduated
repos first, seed projects last:

- the project has **graduated** (`state: repo`) → a graduated repo has no
  self-pull mechanism, so write directly, but do not remove the entry yet if
  another tag still needs handling:
  ```sh
  python3 "$VM" spec -f <path-from-projects-json>/PROJECT_SPEC.md \
    directions --add "<one-line text>"
  ```
  `directions --add` appends a bullet to that repo's `DIRECTIONS.md` — the
  user's channel into the project — and `/project-review` folds it into the
  spec on its next pass. Do not write it into `PROJECT_SPEC.md` yourself —
  turning prose into typed items is a review pass's job, done with the user
  present. Do not add a `## Log` entry either: the Log records what happened
  to the project, not what was filed about it.
- the project is still a **vault seed** (`state: seed`) → invoke
  `learning-init` or `project-init` for that slug, handing it this entry as
  the material to fold in. Both skills pull and drain their own tagged backlog
  entries on open (`backlog list --tag <slug>` / `backlog remove "<title>"`),
  so **do not remove the entry yourself** — invoking the skill is the drain,
  and step 5 below does not apply to this branch. If a second tag also names a
  still-seed project, its `*-init` invocation will find nothing left to pull
  (the first invocation already removed the entry) — hand it the content
  directly instead of relying on the self-pull.

Once every graduated-repo tag has been written and the (at most one
self-draining) seed-tag invocation has run, remove the entry yourself only if
no seed tag did it for you:
```sh
python3 "$VM" backlog remove "<title>"
```

**Tagged at an epic** (`state: epic`) — the thought is about an ambition
spanning several projects, not about a project. Settle which of two things it is
with the user, then treat it as one more tag to handle in the pass above:

- about the **epic itself** — the ambition shifting, a boundary being drawn, a
  member joining or leaving → invoke `epic-init` for that slug, handing it this
  entry. Like the seed branch, it pulls and drains its own tagged entries, so
  **do not remove the entry yourself** for this tag.
- about **one member** — route it to that member instead, by the branches above.
  `python3 "$VM" epic show <slug>` lists them. Ask which; do not guess, and do
  not fan it out to every member just because it named the group.

**Untagged, or every tag names something that does not exist** — continue to
step 3.

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
and tell the user to run the matching `*-init` from inside the vault — it will
pick the seed up as a resume and fold in anything tagged at it.

## 5. Drain the entry

This applies only to the **new-seed path** (steps 3-4). Each tagged branch in
step 2 already drains the entry itself, one way or the other, as described
there — do not repeat it here for those.

```sh
python3 "$VM" backlog remove "<title>"
```

Do this **last**, once the destination exists — the command prints the entry, so
if anything failed you still have its contents to re-file.

Report where it went in one line.
