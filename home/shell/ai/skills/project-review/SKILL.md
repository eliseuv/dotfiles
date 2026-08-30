---
name: project-review
description: Critically review a graduated project repo, guided by its own DIRECTIONS.md, for shortcomings, vulnerabilities and scope drift, fold in tagged backlog entries, and propose additions to its to-do list. Use when the user wants to audit, review or find issues in a project that has already graduated out of the vault, so the findings feed its to-do list.
---

# project-review

A point-in-time audit of a graduated project repo, not a diff-based review —
`/security-review` covers pending branch changes before merge; this covers the
repo as it stands today, and turns what it finds into to-do items rather than
a merge gate. This writes into `DIRECTIONS.md`'s `## To do` — the
project-repo counterpart to `/learning-review`, which does the same job for
learning repos' `ROADMAP.md`.

**This pass is guided by `DIRECTIONS.md`, not just informed by it.** Whatever
the user wrote there — a feature to build, a module to look hard at, a
worry to chase down — is the actual agenda for this audit, not one more item
competing with the checklist below. An empty `## To do` means an unguided
pass: fall back to the general sweep in step 2, same as before this
distinction existed.

**This is a read, critique and propose skill. It never edits source code,
config, dependencies, or anything under version control except
`DIRECTIONS.md`, `.claude/PROJECT.md`'s frontmatter and `## Log`, `README.md`
(narrowly — only the description of a `## To do` item this pass is removing
because it's confirmed shipped, never a rewrite of unrelated content), and
vault-side `Backlog.md`.** A vulnerability found here becomes a to-do item
for the user to schedule — not a patch applied on the spot, however tempting
a one-line fix looks mid-audit.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
```

## 0. The gate

This only runs against a graduated **project** repo — not a vault seed
(`/project-iterate` instead) and not a learning repo (`/learning-review`
instead).

```sh
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" gate review project "$NAME"
```

Every `error:` line is a hard stop — report it plainly and do not proceed
(not tracked under this name, tracked under the wrong bucket, still a seed,
no `.claude/PROJECT.md`, or no `vault_ref:`).

**A `warn:` about `.claude/PROJECT.md`'s body** means fix just that heading
to `## Log` in place before continuing — leave the content beneath it
untouched, this is a heading fix, not a content migration.

**A `warn:` about a missing `DIRECTIONS.md`** means this repo predates the
current file split — migrate it on the spot before continuing:
- If `ROADMAP.md` or `SPECIFICATION.md`/`PLAN.md` is present (an older
  split): scaffold `DIRECTIONS.md` from
  `$TEMPLATES_DIR/project-directions.md`, and merge its sections down —
  `## In scope`/`## Milestones`/`## Direction` (whatever subset the old
  file has) into `## To do`; `## Out of scope`/`## Deferred` into
  `## Not doing`. Move `## About` and any custom sections into `README.md`
  if they aren't already reflected there (merge with existing hand-written
  prose, don't overwrite it), then delete the old file.
- If nothing is present (pre-split case): scaffold `DIRECTIONS.md` empty,
  and move whatever's in `.claude/PROJECT.md` beyond frontmatter/`## Log`
  into `DIRECTIONS.md`/`README.md` following the same split.

Content only in either case — don't rewrite or summarize while moving it, and
don't add a `## Log` entry for the move itself (that's a tooling action, not
a fact about the project). Then proceed with the review as normal.

## 1. Read DIRECTIONS.md first — it sets this pass's agenda

Read `DIRECTIONS.md`'s `## To do` and `## Not doing` before anything else,
including before the gate-check output has settled in. This is not backlog
material to hold for later — it's the brief for step 2. A line that reads
like an audit instruction ("look hard at the auth module") gets read
closely, same as a line that's just outstanding feature work. If `## To do`
is empty, note that and proceed to an unguided general sweep.

Then pull tagged backlog entries — these supplement `## To do`, they don't
replace it:

```sh
python3 "$VM" backlog list --tag "$NAME"
```

Hold both `## To do`'s items and the backlog entries for step 3. Drain each
once its fate is decided — a backlog entry via the tool, a `DIRECTIONS.md`
line by removing it directly from the file:

```sh
python3 "$VM" backlog remove "<title>"
```

Do this before proposing anything of your own — same rule as every other
`*-iterate`/`*-review` skill: the user's captured thoughts outrank your
suggestions.

## 2. Read the repo, then audit it — DIRECTIONS.md leads, the checklist fills in

Read `DIRECTIONS.md`, `.claude/PROJECT.md`, and `README.md` in full first —
what's still outstanding, what's explicitly excluded, what the project
currently claims to be, and `.claude/PROJECT.md`'s `## Log` history — so the
audit measures against what the project committed to, not against your own
idea of what it should be.

Then work the repo itself. **Read-only** — no edits, no formatter runs, no
`cargo fix`, nothing that touches source.

**If step 1 found anything in `## To do`, start there.** Go as deep as each
item calls for — a named module gets read end to end, not sampled; a
second-guessed decision gets an actual answer, not a restatement of the
tension; a plain feature request gets checked against the code to see if
it's already done. This is the part of the audit the user actually asked
for, and it takes priority over the checklist below in both order and
depth.

**Then run the general sweep** — the default audit, and the whole audit when
`## To do` was empty. Use it too for anything the to-do list didn't cover, so
a guided pass doesn't quietly skip the rest of the repo:

**Security-sensitive code paths**
- Auth/authorization: does behavior match what `README.md` documents (e.g.
  "no auth" stated but a header check exists anyway, or vice versa), and is
  anything present that `## Not doing` explicitly excludes
- Input parsing/deserialization: untrusted input reaching a parser,
  deserializer, or format-detector without validation
- Secrets handling: credentials, tokens, connection strings in source,
  committed config, or `.envrc`, rather than an untracked `.env`/flake
- Injection surfaces: SQL built by string concatenation instead of parameter
  binding; shell commands built from unsanitized input
- Unsafe/unchecked casts: `unwrap()`/`expect()` reachable from external input
  rather than a real invariant; `unsafe` blocks without a safety comment
- SQL construction: raw DDL/DML fragments — confirm they're fixed constants,
  not built from runtime values

**Code quality and correctness**
- Error handling gaps: results discarded, errors swallowed silently, panics on
  paths that should degrade instead
- Test coverage gaps: core business logic untested versus thin coverage on
  trivial code
- `grep -rn "TODO\|FIXME\|XXX"` across source — triage each as a real to-do
  item or noise to remove
- Dead code, duplicated logic that has already drifted between copies

**Architecture and scope drift**
- Milestone completion drift: a `## To do` item whose functionality is
  already fully present in the code, and not yet described in `README.md`
- Scope creep: functionality present that `## Not doing` explicitly excludes
- Dependency risk: read `flake.nix` — a channel pin aging badly, a package with
  a known abandonment, anything pulled in for one narrow use a stdlib call
  would cover

Take notes as you go. Do not stop at the first finding.

## 3. Present findings critically

Lead with the answers to `## To do` — that's what this pass was for, and the
user should see it resolved before anything else, including any item you
found is already fully implemented (propose confirming it done: remove from
`## To do`, describe it in `README.md`). Then group the rest: vulnerabilities,
shortcomings and scope drift from the general sweep, separately from
extension proposals and from the folded-in backlog entries — but bring
everything into one discussion; it all competes for the same to-do list.

Work through it with `AskUserQuestion` in rounds — real alternatives (fix now,
defer, or accept the risk and record it in `## Not doing`) with trade-offs,
one recommended, not a neutral menu. Be critical of your own proposals too:

- A `## To do` item that resolves to "already done, code already handles
  this" is still an answer — confirm it and move on, don't manufacture a
  finding to justify the pass.
- A finding that only matters at a scale the project doesn't operate at is
  noise — say so, don't add it to look thorough.
- An extension idea with no user behind it is speculative scope — flag it
  plainly rather than folding it in quietly.
- A genuine vulnerability is **security debt to schedule**, not something to
  leave implicit — silence here is worse than an over-long to-do list.
- Keep going until the user has made a call on everything raised, not just the
  first pass' worth.

## 4. Write it back

**Every accepted item is written immediately** — no batching behind a final
"shall I write these?"

- `DIRECTIONS.md`: append accepted new work to `## To do`; accepted
  exclusions to `## Not doing`.
- For each `## To do` item confirmed shipped: remove it from `DIRECTIONS.md`,
  and write or update its description in `README.md` (a new section if none
  fits, otherwise the existing one). This is the one case `README.md` gets
  touched — narrowly, for that item's description, never a broader rewrite.

```sh
python3 "$VM" touch .claude/PROJECT.md
```

Add one `## Log` entry to `.claude/PROJECT.md` recording the review's outcome:
what `## To do` asked and how it resolved, what got added and why, any
vulnerability that was flagged, anything explicitly ruled out and why. A fact
about the project — not "ran project-review" or "audited the code."

Drain every backlog entry that got folded in:

```sh
python3 "$VM" backlog remove "<title>"
```

## 5. Report

State up front whether this was a guided pass (`## To do` had content) or an
unguided one (it was empty), and if guided, how each item resolved before
anything else. Then summarize: how many items were added to `## To do`/`##
Not doing` and their headline, any items promoted from `## To do` into
`README.md`'s description, and any vulnerability flagged and its disposition
(scheduled / accepted as documented risk / dismissed and why).
