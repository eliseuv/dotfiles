---
name: note
description: Capture a fleeting thought into the notes vault, with optional context - an idea into the idea inbox, anything else into the backlog. The entry point to the vault - use when the user wants to jot down, capture, save or note an idea, task, or thought for later without developing it now, including one worked out in the current session.
---

# note

Capture a thought into the vault. Nothing else.

**This is the only vault skill that does not ask questions.** Capture has to be
frictionless — the user is mid-thought about something else. Do not interrogate,
do not propose, do not offer to develop the entry, do not read other vault files
to check for overlap. File it and stop.

## Steps

1. Resolve the tool once:

   ```sh
   VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
   ```

2. Pick the destination. Decide; do not ask:
   - **Idea inbox** — the user calls it an idea, or it is a claim, question,
     observation or connection to think about, with no deliverable and no
     project named.
   - **Backlog** — everything else: a task, something to build or learn,
     anything tied to a project, anything you cannot place. When in doubt, use
     the backlog; `backlog-develop` can still route it to the Idea path, while a
     task misfiled as an idea is never found again.

3. Split the thought into:
   - **title** — a short noun phrase, roughly under 60 characters, specific
     enough to recognise in a list six weeks from now. Not a summary sentence.
   - **description** — the rest of the thought, if there is more than a title's
     worth. If the user dictated it, keep their phrasing; do not expand or
     improve it. If they asked to save something **worked out in this session**
     ("note that", "save this idea"), distill what the session concluded: the
     claim or question, and the one or two points of reasoning that made it
     worth keeping, in a few sentences. Not a transcript, and nothing the user
     did not agree with.
   - **ctx** — only if there is real circumstance: something the user said
     ("came up while …"), or, for a session capture, one line naming what the
     session was about. Never invent one.

4. Backlog only: infer tags **only on an unambiguous match**:

   ```sh
   python3 "$VM" projects
   ```

   If the thought plainly names one or more of these projects, pass `--tag
   <name> [<name2> ...]` — all of them, not just the first. If it names none, or
   is unsure which of two it means (as opposed to plainly meaning both), pass no
   tag. Do not guess, and do not ask. Inbox entries take no tags.

5. File it:

   ```sh
   python3 "$VM" inbox add "<title>" --description "<description>" --ctx "<ctx>"
   python3 "$VM" backlog add "<title>" --description "<description>" --ctx "<ctx>" --tag <name> [<name2> ...]
   ```

   Omit any flag you have no value for.

6. Report in one line: where it went, the title, and the tag if there was one.
   Surface any warning the tool printed (near-duplicate title, unknown tag)
   plainly, but do not act on it.

Then stop. Do not suggest next steps.
