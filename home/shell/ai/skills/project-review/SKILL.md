---
name: project-review
description: Critically review a graduated project repo for shortcomings, vulnerabilities and scope drift, fold in tagged backlog entries, and propose additions to its roadmap. Use when the user wants to audit, review or find issues in a project that has already graduated out of the vault, so the findings feed its roadmap.
---

# project-review

A point-in-time audit of a graduated project repo, not a diff-based review —
`/security-review` covers pending branch changes before merge; this covers the
repo as it stands today, and turns what it finds into roadmap items rather than
a merge gate. Project repos have no separate roadmap file, so this writes into
`.claude/PROJECT.md`'s `## Roadmap` — the project-repo counterpart to
`/roadmap-iterate`, which does the same job for learning repos' `ROADMAP.md`.

**This is a read, critique and propose skill. It never edits source code,
config, dependencies, or anything under version control except
`.claude/PROJECT.md`, `README.md`'s mirrored sections, and vault-side
`Backlog.md`.** A vulnerability found here becomes a roadmap item for the user
to schedule — not a patch applied on the spot, however tempting a one-line fix
looks mid-audit.

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
```

## 0. The gate

This only runs against a graduated **project** repo — not a vault seed
(`/project-iterate` instead) and not a learning repo (`/roadmap-iterate`
instead; those track `ROADMAP.md`, not `.claude/PROJECT.md`'s `## Roadmap`).

```sh
git rev-parse --show-toplevel >/dev/null 2>&1 || echo "not a git repo — stop"
NAME="$(basename "$(git rev-parse --show-toplevel)")"
python3 "$VM" projects | grep "^$NAME\b"
```

- No match: stop, the repo isn't tracked by the vault under this name.
- Match is `... learning ...`: wrong skill — point at `/roadmap-iterate`.
- Match is `... project seed`: something is inconsistent — a repo shouldn't
  exist for a seed. Say so and stop rather than guessing.
- Match is `... project repo`: continue.

```sh
test -f .claude/PROJECT.md || echo "no .claude/PROJECT.md — stop"
grep -q '^vault_ref:' .claude/PROJECT.md || echo "no vault_ref: — not graduated via project-develop, stop"
```

If any check fails, explain plainly which one and stop — do not proceed against
an arbitrary repo just because it has a README.

## 1. Pull in what has accumulated

Same rule as every other `*-iterate`/`*-review` skill: the user's captured
thoughts outrank your own findings, and get folded into the discussion first,
not appended after.

```sh
python3 "$VM" backlog list --tag "$NAME"
```

Hold these for step 3. Drain each once its fate is decided:

```sh
python3 "$VM" backlog remove "<title>"
```

## 2. Read the repo, then audit it

Read `.claude/PROJECT.md` and `README.md` in full first — what the project
claims to be, its stated scope (`## Scope`'s out-of-scope/deferred lines), and
its `## Log` history — so the audit measures against what the project
committed to, not against your own idea of what it should be.

Then work the repo itself. **Read-only** — no edits, no formatter runs, no
`cargo fix`, nothing that touches source. Check:

**Security-sensitive code paths**
- Auth/authorization: does behavior match what `## Scope` claims (e.g. "no
  auth" stated but a header check exists anyway, or vice versa)
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
- `grep -rn "TODO\|FIXME\|XXX"` across source — triage each as a real roadmap
  item or noise to remove
- Dead code, duplicated logic that has already drifted between copies

**Architecture and scope drift**
- Does the code match what `README.md`/`PROJECT.md` claim — features described
  as built that aren't, or built features never documented
- Scope creep: functionality present that `## Scope`'s out-of-scope list
  explicitly excludes
- Dependency risk: read `flake.nix` — a channel pin aging badly, a package with
  a known abandonment, anything pulled in for one narrow use a stdlib call
  would cover

Take notes as you go. Do not stop at the first finding.

## 3. Present findings critically

Group findings — vulnerabilities, shortcomings, scope drift — separately from
extension proposals and from the folded-in backlog entries, but bring all
three into one discussion; they compete for the same roadmap.

Work through it with `AskUserQuestion` in rounds — real alternatives (fix now,
defer, or accept the risk and record it in `## Scope`) with trade-offs, one
recommended, not a neutral menu. Be critical of your own proposals too:

- A finding that only matters at a scale the project doesn't operate at is
  noise — say so, don't roadmap it to look thorough.
- An extension idea with no user behind it is speculative scope — flag it
  plainly rather than folding it in quietly.
- A genuine vulnerability is **security debt to schedule**, not something to
  leave implicit — silence here is worse than an over-long roadmap.
- Keep going until the user has made a call on everything raised, not just the
  first pass' worth.

## 4. Write the roadmap

**Every accepted item is written immediately** — no batching behind a final
"shall I write these?" Both files, same edit:

- `.claude/PROJECT.md`: if `## Roadmap` doesn't exist, create it as the last
  content section, immediately before `## Log` (`## Log` always stays last).
  Items are plain bullets — no dates, no checkboxes — same convention
  `project-develop` establishes.
- `README.md`: mirror the same bullets into its own `## Roadmap`. **Match only
  the exact top-level `## Roadmap` heading — never a `###`-level "Roadmap"
  subsection nested inside a feature section** (a feature can keep its own
  done/pending checklist; that is a different, narrower list and must be left
  untouched). If README has no top-level `## Roadmap` yet, add one at the end
  of the document, after the sections that mirror `PROJECT.md`'s other
  headings — README carries no `## Log` to stay ahead of.

```sh
python3 "$VM" touch .claude/PROJECT.md
```

Add one `## Log` entry recording the review's outcome: what got added to the
roadmap and why, any vulnerability that was flagged, anything explicitly ruled
out and why. A fact about the project — not "ran project-review" or "audited
the code."

Drain every backlog entry that got folded in:

```sh
python3 "$VM" backlog remove "<title>"
```

## 5. Report

Summarize: how many roadmap items were added and their headline, any
vulnerability flagged and its disposition (scheduled / accepted as documented
risk / dismissed and why), and confirm `PROJECT.md` and `README.md` stayed
consistent.
