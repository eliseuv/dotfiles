---
name: project-review
description: Critically review a graduated project repo, guided by DIRECTIONS.md — critique it for gaps, contradictions and vague items, suggest decompositions and extensions, audit the repo for shortcomings and vulnerabilities, fold in tagged backlog entries, and write accepted findings into PROJECT_SPEC.md as typed items. Use when the user wants to audit, review or find issues in a project that has already graduated out of the vault, so the findings feed its spec.
---

# project-review

A point-in-time audit of a graduated project repo, not a diff-based review —
`/security-review` covers pending branch changes before merge; this covers the
repo as it stands today, and turns what it finds into typed items in
`PROJECT_SPEC.md` rather than a merge gate. The project-repo counterpart to
`/learning-review`.

`DIRECTIONS.md` is an asynchronous conversation, not a flat backlog —
`/project-implement` treats it as user → agent input to build; this skill is
where the agent reads closely and talks back. **This pass is guided by it, not
just informed by it** — whatever's written, from a one-line task to a phased
roadmap, is the actual agenda for step 2, not one more item competing with the
checklist. An empty `DIRECTIONS.md` means an unguided pass: fall back to the
general sweep in step 2.

**This is a read, critique and propose skill. It never edits source code,
config, dependencies, or anything under version control except
`PROJECT_SPEC.md`, `DIRECTIONS.md` (draining only — never writing into it),
`.claude/PROJECT.md`'s frontmatter and `## Log`, `README.md` (narrowly — only
the description of a requirement this pass confirms shipped), and vault-side
`Backlog.md`.** A vulnerability found here becomes a typed item to schedule, not
a patch applied on the spot, however tempting a one-line fix looks mid-audit.

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

The file warnings distinguish three situations. Read which one you got:

- **`PROJECT_SPEC.md` but no `DIRECTIONS.md`** — the spec is migrated but the
  user has nowhere to write. Scaffold the file from
  `$TEMPLATES_DIR/project-directions.md` and continue. If the spec still carries
  a `## 1. Directions` section, read it out *before* creating the file and write
  its content across — with both present `spec directions` refuses, because it
  cannot tell which holds the real input.
- **`DIRECTIONS.md` but no `PROJECT_SPEC.md`** — the repo predates the spec
  format. Migrate it on the spot, per section 0a, then continue.
- **Neither, or only `ROADMAP.md`/`SPECIFICATION.md`/`PLAN.md`** — the repo
  predates the file split entirely. Same migration, with the old file and
  `.claude/PROJECT.md`'s body as the source instead of `DIRECTIONS.md`.

## 0a. Migrating a pre-spec repo

Only when the gate said so. This is content movement, not rewriting: don't
summarize or improve while migrating, and don't add a `## Log` entry for the
migration itself — that's a tooling action, not a fact about the project.

```sh
python3 "$VM" spec -f PROJECT_SPEC.md init "$NAME" --title "<Project Title>"
python3 "$VM" spec meta --set category=<from .claude/PROJECT.md> language=<from flake.nix>
```

Then, in this order:

1. **Goals from `README.md`, not from the to-do list.** The to-do list says what
   is left; the README says what the thing is. Most metrics will be `unknown` —
   that is what `spec ls --unresolved` is for, and inventing a measurable
   criterion the user never agreed to is worse than leaving the hole visible.
2. **`## Not doing` → `NG-` items, bodies preserved verbatim.** This is where
   the real reasoning lives — why a path was rejected, what was tried and
   reverted. Paraphrasing it loses the migration's whole value.
3. **`## To do` → `R-` items**, with `acceptance` where it is derivable from the
   item's own wording and `unknown` where it is not.
4. **Phases → `M-` items.** Both encodings are in the wild: `###` phase headings
   and inline `Phase N —` bullets. Phases a prose preamble records as already
   finished ("Phase 1 is done — see README") become `M-` at `status: done`, with
   the requirements they delivered at `status: implemented`.
5. **An entry that is really a question is not a requirement.** "Which crates —
   settle while building", "floating-point tolerance — needs a real construction
   to calibrate": these are deferred judgments, not work. Per `PROTOCOL.md`, a
   question that blocks nothing is an assumption — make them `A-` items with
   `confidence` and `impact_if_wrong`. Filing them as requirements is how a spec
   fills with things nobody can ever mark accepted.
6. **An entry that is really a decision record becomes a `D-` item**, with the
   rejected option and its reason, not an `NG-`. A to-do bullet that describes
   something tried and reverted, with the reason it was reverted, is a decision
   wearing the wrong hat.
7. **Leave `DIRECTIONS.md` holding only what has not been folded in** — after a
   full pass, nothing. `.claude/PROJECT.md` and `README.md` are untouched by
   migration.

Finish with `spec validate`. A freshly migrated spec will have holes; that is
expected and visible. It must not have *errors* — if it does, the mapping is
wrong, not the rubric.

## 1. Read DIRECTIONS.md as a conversation, then talk back

Read it before anything else, including before the gate-check output has
settled in — this is the brief for steps 2 and 3, not backlog material to hold
for later. If it is empty, note that and proceed to an unguided general sweep.

```sh
python3 "$VM" spec directions
python3 "$VM" spec inbox      # questions the user has answered since last pass
python3 "$VM" spec pending    # questions still waiting on them
```

Read each line as the user's half of an ongoing conversation, not just an
agenda: note gaps or contradictions; items vague or big enough to warrant a
decomposition sketch (sketch it here, don't write it yet — that's step 4's job
once accepted); and extensions an item implies but doesn't state.

**Process the inbox before proposing anything of your own.** Each answered
question becomes a durable item and is then closed:

```sh
python3 "$VM" spec add D "<what got settled>" --set 'options=[a,b]' chosen=a 'from=[Q-3]'
python3 "$VM" spec resolve Q-3 --into D-7
```

Closing a question without folding its answer into an item is the one failure
mode that quietly destroys the whole scheme: the answer scrolls out of context
and the next pass asks it again.

Then pull tagged backlog entries — these supplement `DIRECTIONS.md`, they don't
replace it:

```sh
python3 "$VM" backlog list --tag "$NAME"
python3 "$VM" backlog remove "<title>"   # once its fate is decided
```

Do all of this before proposing anything of your own — same rule as every other
`*-review` skill: the user's captured thoughts outrank your suggestions.

## 2. Audit the repo — DIRECTIONS.md leads, the checklist fills in

Orient through the spec rather than reading it whole:

```sh
python3 "$VM" spec handoff
python3 "$VM" spec status
python3 "$VM" spec ls NG --columns id,title
python3 "$VM" spec ls R --status specified --columns id,title,acceptance
```

Read `README.md` and `.claude/PROJECT.md`'s `## Log` in full — what the project
claims to be, and its history — so the audit measures against what the project
committed to, not your own idea of what it should be.

Then work the repo itself. **Read-only** — no edits, no formatter runs, no
`cargo fix`, nothing that touches source.

**If step 1 found anything in `DIRECTIONS.md`, start there.** Go as deep as each
item calls for — a named module gets read end to end, not sampled; a
second-guessed decision gets an actual answer; a plain feature request gets
checked against the code to see if it's already done. This is what the user
asked for, and it takes priority over the checklist below in both order and
depth.

**Then run the general sweep** — the default audit, and the whole audit when
`DIRECTIONS.md` was empty. Use it too for anything the user's notes didn't
cover, so a guided pass doesn't quietly skip the rest of the repo:

**Security-sensitive code paths**
- Auth/authz behavior matches `README.md`, and nothing crosses an `NG-` item
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
- An `R-` at `status: specified` that the code already satisfies — confirm it
  `implemented` rather than leaving it queued
- Functionality present that an `NG-` item explicitly excludes
- A requirement whose `acceptance` the code contradicts
- `flake.nix` dependency risk — an aging pin, an abandoned package, or one
  narrow use a stdlib call would cover

Take notes as you go. Do not stop at the first finding.

## 3. Present findings critically

Lead with the answers to `DIRECTIONS.md` — that's what this pass was for,
including any item found already fully implemented. Then step 1's conversation
critique — each gap, decomposition candidate, and extension, against the item it
came from. Then the rest: vulnerabilities, shortcomings and scope drift from the
general sweep, and the folded-in backlog entries — but bring everything into one
discussion; it all competes for the same spec.

Work through it with `AskUserQuestion` in rounds — real alternatives (fix now,
defer, or accept the risk and record it) with trade-offs, one recommended, not a
neutral menu. Be critical of your own proposals too:

- An item that resolves to "already done, code already handles this" is still an
  answer — confirm it and move on, don't manufacture a finding to justify the
  pass.
- A gap, decomposition, or extension from step 1: resolve a gap on the spot
  if the audit found the answer, otherwise ask; offer a decomposition
  sketch for acceptance rather than assuming it's wanted; fold an extension
  into its source item, add it as new, or flag it as speculative scope.
- A finding that only matters at a scale the project doesn't operate at is
  noise — say so, don't add it to look thorough.
- A genuine vulnerability is **security debt to schedule**, not something to
  leave implicit — silence here is worse than an over-long queue.
- Keep going until the user has made a call on everything raised, not just
  the first round's worth.

## 4. Write it back

**Every accepted finding is written immediately** — no batching behind a final
"shall I write these?" Each one has a type:

| The finding | Becomes |
|---|---|
| new work | `R-` with `acceptance`, `covers` a goal |
| an exclusion | `NG-`, with the reasoning in its body |
| a choice that got settled | `D-` with `options` and `chosen` |
| a risk taken knowingly | `RK-` with `status: accepted` and a `mitigation` |
| an unstated premise the work rests on | `A-` with `confidence`, `impact_if_wrong` |
| confirmed shipped | `spec set R-n status=implemented`, plus `README.md` |
| **needs the user, who isn't here** | **`Q-` with `blocks`** |

That last row is the one the old to-do list could not express. A finding that
needs a decision no longer has to be asked synchronously or dropped:

```sh
python3 "$VM" spec add Q "Should rule severity be configurable per-project?" \
  --set 'blocks=[R-8]' \
  --body "Per-project config means a merge layer over defaults (~200 LOC). Fixed
severities keep it flat. Cheaper to decide now than to retrofit."
```

The user answers under the `> ANSWER:` marker whenever they get to it, and the
next pass picks it up via `spec inbox`. Spend a question only when the answer
changes what would be built, and say so in `blocks` — `/project-implement` will
refuse to build anything a question blocks. If nothing is blocked, it isn't a
question; it's an assumption.

A decomposition accepted in step 3 supersedes rather than replaces:

```sh
python3 "$VM" spec set R-3 status=superseded
python3 "$VM" spec add R "<slice>" --set acceptance="..." 'supersedes=[R-3]'
```

For each requirement confirmed shipped, write or update its description in
`README.md` — a new section if none fits, otherwise the existing one. This is
the one case `README.md` gets touched: narrowly, for that item's description,
never a broader rewrite.

**Then drain and hand off.** `DIRECTIONS.md` empties as its lines become items:

```sh
python3 "$VM" spec directions --clear     # or --set "<what's left>"
python3 "$VM" touch .claude/PROJECT.md
python3 "$VM" spec handoff --set "- **Last session:** ...
- **Now blocked on:** ...
- **Next action:** ..."
```

A non-empty `DIRECTIONS.md` at the end of a review pass means the user's input
was left on the floor — the exact failure this whole design exists to prevent.
`spec validate` warns about it; don't finish with that warning showing.

Add one `## Log` entry to `.claude/PROJECT.md` recording the review's outcome:
what the user's notes asked and how each resolved, what got added, decomposed or
extended and why, any vulnerability flagged, anything explicitly ruled out. A
fact about the project — not "ran project-review" or "audited the code".

## 5. Report

State up front whether this was a guided pass (`DIRECTIONS.md` had content) or
an unguided one, and if guided, how each line resolved before anything else.
Then summarize: how many items were added and of which kinds, how many were
decomposed, any confirmed shipped and promoted into `README.md`, any question
left for the user to answer asynchronously, and any vulnerability flagged with
its disposition (scheduled / accepted as documented risk / dismissed and why).
