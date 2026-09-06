---
name: learning-session
description: Orient at the start of an ad-hoc session in a graduated learning repo - surface where the curriculum stands and what's next. Use when starting or resuming work in a graduated learning repo, before writing any code.
---

# learning-session

The session-start counterpart to `/learning-review`: read-only orientation,
not a revision pass. It surfaces exactly what
`Templates/Learning/assisted-learning.md` already tells every session to
check first, as an explicit, repeatable trigger rather than something that
only happens if that import loaded correctly.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
```

## 0. The gate

```sh
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" gate review learning "$NAME"
```

Every `error:` line is a hard stop - report it plainly and do not proceed.

## 1. Read three things, nothing else

- `ROADMAP.md`'s `## Progress at a glance`
- The `In progress` unit's `### Build`, `### Milestone`, `### Progress notes`
  (if nothing is `In progress` yet, use the first `Not started` unit instead)
- `ROADMAP.md`'s `## Direction`

Do not read the whole roadmap - it's written for the curriculum, not a
session.

## 2. Report and stop

One short summary: which unit is in play, what's already built, what the
milestone/checkpoint ahead is, and anything sitting in `## Direction`. Do not
edit any file - this is orientation, not `/learning-review` or end-of-session
bookkeeping. Then wait for the user's direction.
