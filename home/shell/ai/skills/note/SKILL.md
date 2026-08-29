---
name: note
description: Capture a fleeting thought into the notes vault backlog, with optional context. The entry point to the vault - use when the user wants to jot down, capture, or note an idea, task, or thought for later without developing it now.
---

# note

Capture a thought into `Backlog.md`. Nothing else.

**This is the only vault skill that does not ask questions.** Capture has to be
frictionless — the user is mid-thought about something else. Do not interrogate,
do not propose, do not offer to develop the entry, do not read other vault files
to check for overlap. File it and stop.

## Steps

1. Resolve the tool once:

   ```sh
   VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
   ```

2. Split the user's thought into:
   - **title** — a short noun phrase, roughly under 60 characters, specific
     enough to recognise in a list six weeks from now. Not a summary sentence.
   - **description** — the rest of the thought, if there is more than a title's
     worth. Keep the user's own phrasing; do not expand or improve it.
   - **ctx** — only if the user actually supplied circumstance ("came up while
     …", "from the ledger work"). Never invent one.

3. Infer a tag **only on an unambiguous match**:

   ```sh
   python3 "$VM" projects
   ```

   If the thought plainly names one of these projects, pass `--tag <name>`. If it
   names none, or could mean two of them, pass no tag. Do not guess, and do not
   ask.

4. File it:

   ```sh
   python3 "$VM" backlog add "<title>" --description "<description>" --ctx "<ctx>" --tag <name>
   ```

   Omit any flag you have no value for.

5. Report in one line: the title it filed under, and the tag if there was one.
   Surface any warning the tool printed (near-duplicate title, unknown tag)
   plainly, but do not act on it — the user can run `/backlog-review` later.

Then stop. Do not suggest next steps.
