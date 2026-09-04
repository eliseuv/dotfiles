---
name: project-review
description: Critically review a graduated project repo, guided by DIRECTIONS.md — critique it for gaps, contradictions and vague items, suggest decompositions and extensions, audit the repo for shortcomings and vulnerabilities, fold in tagged backlog entries, and write accepted findings into its to-do list. Use when the user wants to audit, review or find issues in a project that has already graduated out of the vault, so the findings feed its to-do list.
---

# project-review

A point-in-time audit of a graduated project repo, not a diff-based review —
`/security-review` covers pending branch changes before merge; this covers the
repo as it stands today, and turns what it finds into to-do items rather than
a merge gate. This writes into `DIRECTIONS.md`'s `## To do` — the
project-repo counterpart to `/learning-review`.

`DIRECTIONS.md`'s `## To do` is an asynchronous conversation, not a flat
backlog — `/project-implement` treats it as user → agent input to build; this
skill is where the agent reads closely and talks back. **This pass is guided
by it, not just informed by it** — whatever's written, from a one-line task
to a phased roadmap, is the actual agenda for step 2, not one more item
competing with the checklist. An empty `## To do` means an unguided pass:
fall back to the general sweep in step 2.

**This is a read, critique and propose skill. It never edits source code,
config, dependencies, or anything under version control except
`DIRECTIONS.md`, `.claude/PROJECT.md`'s frontmatter and `## Log`, `README.md`
(narrowly — only the description of a `## To do` item this pass is removing
because it's confirmed shipped), and vault-side `Backlog.md`.** A
vulnerability found here becomes a to-do item to schedule, not a patch
applied on the spot, however tempting a one-line fix looks mid-audit.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
```

## 0. The gate

This only runs against a graduated **project** repo — not a vault seed
(`/project-init` instead) and not a learning repo (`/learning-review`
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

The gate's file warnings distinguish two different situations — read which
one you got before acting:

- **`DIRECTIONS.md` but no `PROJECT_SPEC.md`** — the repo predates the spec
  format. Migrate on the spot: `vaultmeta spec -f PROJECT_SPEC.md init <name>`,
  then fold `## To do` into `R-`/`M-` items and `## Not doing` into `NG-`
  items, leaving `DIRECTIONS.md` holding only free prose the user has not
  had folded in yet.
- **`PROJECT_SPEC.md` but no `DIRECTIONS.md`** — the spec is migrated but the
  user has nowhere to write. Scaffold the file from
  `$TEMPLATES_DIR/project-directions.md` and continue. If the spec still has
  a `## 1. Directions` section, read it out *before* creating the file and
  write its content across — with both present `spec directions` refuses,
  because it cannot tell which holds the real input.
- **Neither, or only `ROADMAP.md`/`SPECIFICATION.md`/`PLAN.md`** — the repo
  predates the split entirely. Scaffold both: `init` a spec, fold whatever
  the old file or `.claude/PROJECT.md` holds beyond frontmatter/`## Log` into
  items, move `## About` and custom sections into `README.md` (merging with
  existing prose, not overwriting), then delete the old file.

Content only in every case — don't rewrite or summarize while moving it, and
don't add a `## Log` entry for the move itself (that's a tooling action, not
a fact about the project). Then proceed with the review as normal.

Once a repo carries a spec, this pass's findings become typed items in it and
`DIRECTIONS.md` is drained to empty; the `## To do` / `## Not doing` language
below still describes repos that have not been migrated yet. See
`$TEMPLATES_DIR/Project/directions-vs-readme.md` for which file takes what.

## 1. Read DIRECTIONS.md as a conversation, then talk back

Read `DIRECTIONS.md`'s `## To do` and `## Not doing` before anything else,
including before the gate-check output has settled in — this is the brief
for steps 2 and 3, not backlog material to hold for later. If `## To do` is
empty, note that and proceed to an unguided general sweep.

Read each item as the user's half of an ongoing conversation, not just an
agenda: note gaps or contradictions; items vague or big enough to warrant a
decomposition sketch (the phased, sub-headed style already used in mature
`DIRECTIONS.md` files is the model — sketch it here, don't write it yet,
that's step 4's job once accepted); and extensions an item implies but
doesn't state. Hold these for steps 2 and 3 — this step reads and thinks, it
doesn't act.

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

## 2. Audit the repo — DIRECTIONS.md leads, the checklist fills in

Read `DIRECTIONS.md`, `.claude/PROJECT.md`, and `README.md` in full first —
what's outstanding, what's excluded, what the project claims to be, and
`.claude/PROJECT.md`'s `## Log` history — so the audit measures against what
the project committed to, not your own idea of what it should be.

Then work the repo itself. **Read-only** — no edits, no formatter runs, no
`cargo fix`, nothing that touches source.

**If step 1 found anything in `## To do`, start there.** Go as deep as each
item calls for — a named module gets read end to end, not sampled; a
second-guessed decision gets an actual answer; a plain feature request gets
checked against the code to see if it's already done. This is what the user
asked for, and it takes priority over the checklist below in both order and
depth.

**Then run the general sweep** — the default audit, and the whole audit when
`## To do` was empty. Use it too for anything the to-do list didn't cover, so
a guided pass doesn't quietly skip the rest of the repo:

**Security-sensitive code paths**
- Auth/authz behavior matches `README.md`, and nothing crosses `## Not doing`
- Untrusted input reaching a parser, deserializer, or format-detector
  unvalidated
- Secrets — credentials, tokens, connection strings — in source, committed
  config, or `.envrc`, rather than an untracked `.env`/flake
- SQL/shell built by concatenation instead of parameter binding or
  sanitization
- `unwrap()`/`expect()`/`unsafe` reachable from external input without a
  real invariant or safety comment

**Code quality and correctness**
- Errors discarded or swallowed instead of handled; panics where the code
  should degrade instead
- Core business logic untested versus thin coverage on trivial code
- `grep -rn "TODO\|FIXME\|XXX"` across source, triaged as real work or noise
- Dead code, and duplicated logic that's already drifted between copies

**Architecture and scope drift**
- A `## To do` item already fully implemented but not yet in `README.md`
- Functionality present that `## Not doing` explicitly excludes
- `flake.nix` dependency risk — an aging pin, an abandoned package, or one
  narrow use a stdlib call would cover

Take notes as you go. Do not stop at the first finding.

## 3. Present findings critically

Lead with `## To do`'s answers — that's what this pass was for, including
any item found already fully implemented (propose confirming it done: remove
from `## To do`, describe it in `README.md`). Then step 1's conversation
critique — each gap, decomposition candidate, and extension, against the
item it came from. Then the rest: vulnerabilities, shortcomings and scope
drift from the general sweep, and the folded-in backlog entries — but bring
everything into one discussion; it all competes for the same to-do list.

Work through it with `AskUserQuestion` in rounds — real alternatives (fix
now, defer, or accept the risk and record it in `## Not doing`) with
trade-offs, one recommended, not a neutral menu. Be critical of your own
proposals too:

- A `## To do` item that resolves to "already done, code already handles
  this" is still an answer — confirm it and move on, don't manufacture a
  finding to justify the pass.
- A gap, decomposition, or extension from step 1: resolve a gap on the spot
  if the audit found the answer, otherwise ask; offer a decomposition
  sketch for acceptance rather than assuming it's wanted; fold an extension
  into its source item, add it as new, or flag it as speculative scope.
- A finding that only matters at a scale the project doesn't operate at is
  noise — say so, don't add it to look thorough.
- A genuine vulnerability is **security debt to schedule**, not something to
  leave implicit — silence here is worse than an over-long to-do list.
- Keep going until the user has made a call on everything raised, not just
  the first round's worth.

## 4. Write it back

**Every accepted item is written immediately** — no batching behind a final
"shall I write these?"

- `DIRECTIONS.md`: append accepted new work and extensions to `## To do`;
  accepted exclusions to `## Not doing`. An accepted decomposition replaces
  its line with the breakdown, phased and sub-headed like mature
  `DIRECTIONS.md` files; a resolved gap gets its wording fixed in place.
- For each `## To do` item confirmed shipped: remove it from `DIRECTIONS.md`,
  and write or update its description in `README.md` (a new section if none
  fits, otherwise the existing one). This is the one case `README.md` gets
  touched — narrowly, for that item's description, never a broader rewrite.

```sh
python3 "$VM" touch .claude/PROJECT.md
```

Add one `## Log` entry to `.claude/PROJECT.md` recording the review's outcome:
what `## To do` asked and how it resolved, what got added, decomposed, or
extended and why, any vulnerability that was flagged, anything explicitly
ruled out and why. A fact about the project — not "ran project-review" or
"audited the code."

Drain every backlog entry that got folded in:

```sh
python3 "$VM" backlog remove "<title>"
```

## 5. Report

State up front whether this was a guided pass (`## To do` had content) or an
unguided one (it was empty), and if guided, how each item resolved before
anything else. Then summarize: how many items were added to `## To do`/`##
Not doing`, how many were decomposed, any promoted from `## To do` into
`README.md`'s description, and any vulnerability flagged and its disposition
(scheduled / accepted as documented risk / dismissed and why).
