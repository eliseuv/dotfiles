---
name: capture
description: Capture a fleeting thought without developing it - a task, something to build or learn, or anything tied to a project goes into aven's inbox; a claim, question or connection to think about goes into the ideas inbox. Use when the user wants to jot down, capture, save or note a thought for later, including one worked out in the current session.
---

# capture

File a thought. Nothing else.

**This skill never asks questions.** The user is mid-thought about something
else. Do not interrogate, do not propose, do not offer to develop the entry, do
not search for overlap. File it and stop.

## 1. Pick the destination — decide, do not ask

- **Idea** — the user calls it an idea, or it is a claim, question, observation
  or connection to think about, with no deliverable and no project named.
- **Task** — everything else: something to do, build or learn, anything tied to
  a project, anything you cannot place. When in doubt, it is a task: triage can
  still turn a task into an idea, while a task misfiled as an idea is never
  found again.

## 2. Split the thought

- **title** — a short noun phrase, under ~60 characters, recognisable in a list
  six weeks from now. Not a summary sentence.
- **description** — the rest, only if there is more than a title's worth. If
  the user dictated it, keep their phrasing. If they asked to save something
  **worked out in this session**, distill what the session concluded — the
  claim or question and the one or two points of reasoning that made it worth
  keeping, in a few sentences. Not a transcript, and nothing they did not agree
  with.
- **context** — one line, only if there is real circumstance ("came up while
  …", or what the session was about). Never invent one.

## 3. File it

**Task.** Pick the project only on an unambiguous match:

- cwd is inside a repo mapped to an aven project → aven infers it; pass nothing.
- the thought plainly names a project from `aven project list` → `--project <key>`.
- otherwise, or if it could be either of two → no project. Triage resolves it.

```sh
aven add "<title>" --status inbox [--project <key>] --description-stdin <<'EOF'
<description>

Context: <context>
EOF
```

Omit the description entirely when there is nothing beyond the title.

**Idea.** Append to `~/Documents/ideas/Inbox.md`, newest first under its H1:

```markdown
## <title>
- <today, from `date +%F`>
<description>
```

## 4. Report

One line: where it went, the title, and the ref or project if any. Surface any
warning aven printed, without acting on it. Then stop — no next steps.
