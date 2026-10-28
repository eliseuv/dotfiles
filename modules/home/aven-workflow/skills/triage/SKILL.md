---
name: triage
description: Work through aven's inbox with the user - survey it grouped by project, flag vague, stale or duplicate entries, then place each one into an existing project's structure, turn it into a new project or learning track, move it to the ideas inbox, or cancel it. Use when the user wants to triage, review, clean up, develop or act on captured entries, or on what they wrote into a project's inbox.
---

# triage

Empty the inbox by deciding where each entry belongs. The inbox is a capture
buffer, not a history: every entry leaves `inbox` status by the end, one way or
another. Conventions live in `~/.claude/includes/aven-conventions.md`.

## 1. Survey

```sh
aven list -A --status inbox --json
```

If the user named an entry or a project, narrow to it. Otherwise present the
inbox grouped by project (unassigned last), and flag before asking anything:

- **vague** — a title that will mean nothing in six weeks
- **stale** — captured long ago and plausibly overtaken; check the project's
  recent `git log` before calling it stale
- **duplicate** — another open task already covers it (`aven search`, across
  `-A`, including done ones)
- **superseded** — the thing it asks for already exists

Propose merges, rewrites and drops for those as one batch with
`AskUserQuestion`.

## 2. Place each entry

Read it with `aven context <ref>`, then decide its destination with the user.
Ask with `AskUserQuestion`, a recommendation first, real trade-offs on each
option. **Apply each answer immediately** — the answer is the go-ahead.

| Destination | What to do |
|---|---|
| Fits an existing project | Move it out of inbox in that project. If the project has POCs, decide with the user whether it is a new checkpoint (give it `kind=checkpoint`, the next free `cp=` ID, its sections, epic membership and deps), scope for a POC (fold into the epic's description and cancel the entry), or a plain task (`backlog`/`todo`). For a learning track, a new or changed unit — restructuring the curriculum is in scope here |
| A new project or learning track | Hand it to the `scope` skill with this entry as its seed material |
| Really an idea | Append it to `~/Documents/ideas/Inbox.md` in capture's format, then cancel the task with a note saying where it went |
| Not worth doing | `--status canceled` and a one-line note saying why |
| Names two projects | Handle each destination before closing the entry |

Things the user wrote from inside a repo arrive here as that project's inbox.
They are directions, not suggestions: they outrank your own agenda for the
project, and a line that contradicts settled scope is a scope conversation to
have, not a reason to drop it.

Push back: on entries that duplicate something already tracked, on vague scope,
on unstated assumptions. Agreeing is not helping.

## 3. Finish

```sh
aven list -A --status inbox
aven-lint -A
```

The inbox should be empty, or hold only what the user explicitly chose to
leave. Fix any lint errors your changes introduced. Report what moved where in
a short list, then ask whether that covers it.
