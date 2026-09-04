---
name: project-init
description: Turn a rough or half-formed project idea into a complete, machine-queryable PROJECT_SPEC.md through adversarial critique and iterative interrogation of the user. Use this whenever someone describes something they want to build but hasn't specified it — "I want to build X", "help me scope this project", "I've got an idea for a tool", "let's plan out this service" — even when they don't use the words "spec" or "specification". Also use it to resume or extend an existing PROJECT_SPEC.md, to process answers the user has written into one, or when any project work needs a spec that doesn't exist yet. Do not use it for adding a single feature to an already-specified project; amend the spec directly instead.
---

# project-init

Produce a `PROJECT_SPEC.md` that is complete enough for an implementation agent
to work from unsupervised, and structured enough to serve afterwards as the
asynchronous channel between that agent and the user.

Two things make this different from writing a design doc:

- **The output is a protocol, not prose.** Stable IDs, per-item status enums, an
  append-only decision trail. A session can die mid-sentence and the next one
  loses nothing. Read `references/PROTOCOL.md` — it governs everything after
  this skill hands off.
- **Completion is checkable.** `python3 "$VM" spec validate` implements
  `references/RUBRIC.md`. The interrogation loop ends when the rubric passes,
  not when you feel you have asked enough.

## Bundled files

| Path | Read it when |
|---|---|
| `references/GRAMMAR.md` | Before hand-editing the spec, or if a parse looks wrong. |
| `references/PROTOCOL.md` | Session start and end; give it to implementation agents. |
| `references/RUBRIC.md` | When deciding whether to keep interrogating. |
| `references/EXAMPLE_PROJECT_SPEC.md` | When you want to see a finished, passing spec. |
| `assets/TEMPLATE.md` | The out-of-vault default. Inside the vault, `spec init` uses `$TEMPLATES_DIR/Project/specification.md`. |

The engine lives in the vault, like every other tool these skills use. Set it
up once and drop the `-f` flag everywhere:

```sh
VM="$NOTES_VAULT/vaultmeta/vaultmeta.py"
eval "$(python3 "$VM" env | sed 's/^/export /')"
export SPEC_FILE=./PROJECT_SPEC.md
spec() { python3 "$VM" spec "$@"; }
```

`python3 "$VM" spec --help` lists every subcommand. The engine's own tests are
`vaultmeta/spec-selftest.sh` — run them before and after changing `spec.py`.

## First: is this a new spec or a resume?

If `PROJECT_SPEC.md` already exists, this is a resume. Skip to **Resuming**.

## Phase 1 — Adversarial pass

Before asking anything, attack the idea. The user brought a rough idea because
they want it stress-tested, and the most valuable thing you can do arrives in
the first sixty seconds — before either of you is invested in the current shape.

State plainly:

- **Does this already exist?** Search if you can. Naming the closest existing
  tool and why it does or doesn't fit is worth more than any question you could
  ask instead.
- **Is the hard part the part they think it is?** Usually not. In a static
  analyzer the parser feels hard and is solved; the interprocedural dataflow
  feels like an extension and is the actual project.
- **What unstated assumption sinks this?** Say it even if it's uncomfortable.
- **What's the cheapest thing that would falsify the premise?** If a two-hour
  experiment could kill the project, that experiment is the real first
  milestone, not scaffolding.

Be direct. Hedged critique is useless — it costs the same to read and changes
nothing. If the idea survives, the user's confidence is now earned rather than
assumed. If it doesn't, you saved them weeks.

Then stop and let them respond before interrogating. They may reframe the whole
project here, which invalidates every question you were about to ask.

## Phase 2 — Skeleton immediately

```bash
python3 "$VM" spec init "project-name"
```

Write the Problem section and whatever goals and constraints the user already
gave you, with `unknown` where you don't know:

```bash
spec add G "Detect use-after-move on records with managed fields" --set metric=unknown
```

State becomes durable on turn one. A dropped session now costs nothing.

## Phase 3 — Interrogation loop

Use `ask_user_input_v0`. Tappable options beat typed prose for the user, and the
answers come back in a form you can write straight into fields.

**Depth-first by leverage.** Never ask about a component whose existence isn't
settled. Order: problem → goals → non-goals → hard constraints → architecture →
requirements → milestones. One early answer invalidates a dozen late questions;
asking them in the wrong order wastes the user's most expensive resource, which
is their attention, not their time.

**Propose, don't interview.** Do not ask open-ended questions you could answer
yourself with a defensible default. Offer an opinionated recommendation with its
rationale and let the user confirm or override:

> For rule configuration I'd default to a single YAML file with per-rule
> severity overrides — matches what SonarQube users already expect, and it keeps
> the engine free of a merge layer. Alternative is per-project TOML.

A user correcting a wrong default gives you more information per round-trip than
a user answering a blank question, and it costs them a tap instead of a
paragraph. Three questions per turn maximum; one is often better.

**Write after every turn, before the next question.** The conversation is
disposable; the file isn't.

```bash
spec set G-1 metric="zero false negatives on the 40-case corpus" status=accepted
spec add D "Rule config format" --set options=[yaml,toml,json] --set chosen=yaml \
  --body "Matches SonarQube conventions; avoids a merge layer in the engine."
```

**Silence is an assumption, not a blocker.** If the user skips something, record
an `A-` item with `confidence` and `impact_if_wrong` and move on. Stalling the
whole pipeline on a question the user didn't think was important is the failure
mode that kills async workflows.

**Cap at roughly eight rounds.** Then stop asking and park the remainder as `Q-`
items for the async channel to carry. A spec with six open questions and a green
rubric is more useful than a perfect spec that took a fortnight to extract.

**Watch for the reframe.** If an answer contradicts something already written,
say so explicitly and supersede the old item rather than quietly editing it. The
user needs to see that their answer had consequences.

## Phase 4 — Exit

```bash
spec validate
```

Fix errors — most are mechanical (a goal without a metric, a milestone covering
nothing). If a fix needs the user, that's one more round. Then:

1. Update the handoff block (`spec handoff --set ...`).
2. Present a summary: goals, non-goals, the two or three decisions that most
   shape the build, open questions, first milestone. Not the whole file.
3. Ask for sign-off. Only then `spec set-meta`-equivalent: edit `status:` in the
   frontmatter to `ready`.
4. Tell the user how to operate the channel, which is two sentences: **answers
   go under the `> ANSWER:` markers; anything else you want to say goes in
   `## 1. Directions`, in whatever shape you like, whenever you like.** Nothing
   else is required of them — not item syntax, not answering at all.

## Resuming

```bash
spec handoff && spec status && spec directions && spec inbox && spec blocked
```

Read `## 1. Directions` first and make it the pass's agenda. It is what the user
wrote unprompted, in whatever shape suited them, and it outranks anything you
were about to propose. Fold each line into a typed item and drain it:

```bash
spec add R "..." --set acceptance=... 'covers=[G-2]'
spec directions --set "<whatever is left>"   # or --clear
```

Never write into Directions yourself — it is the user's side of the table.

Process the inbox second — each answered question becomes a `D-` or `R-` item
with `from: [Q-n]`, then `spec resolve Q-n --into D-m`. Closing a question
without folding its answer into a durable item is the one failure mode that
silently destroys the whole scheme: the answer scrolls out of context and the
next session asks it again.

Then continue the loop from wherever `validate` says the holes are.

## Querying instead of reading

The spec grows past what you want in context. Query it:

```bash
spec ls Q --status open              # what's outstanding
spec ls R --where status=specified   # ready to implement
spec ls --unresolved                 # anything with an empty field
spec ls --mentions G-2               # what depends on this goal
spec get D-4                         # one item, verbatim
spec --json ls R --columns id,status,acceptance
```

Reading the whole file to answer "what's blocked" is the wrong instinct — it
costs a hundred times the tokens and goes stale the moment you write to it.
`--json` goes *before* the subcommand — `spec --json ls R`, not
`spec ls R --json`.
