# Async protocol

`PROJECT_SPEC.md` is not a document that happens to be shared. It is the
communication channel. The conversation that produced it is disposable; a
session can die mid-sentence and the next one loses nothing, because every
commitment was written down when it was made.

This file is written for *any* agent touching the spec, not just `project-init`.
An implementation agent picking up the project weeks later should read this and
know how to behave.

## The invariant

**Nothing is settled until it is in the file.** An agreement that exists only in
a chat transcript does not exist. Write after every exchange, not at the end.

## Session start

```bash
python3 "$VM" spec handoff        # what was happening
python3 "$VM" spec status         # counts, what's waiting
python3 "$VM" spec directions     # what the human wrote unprompted
python3 "$VM" spec inbox          # answers the human left for you
python3 "$VM" spec blocked        # what you must not start
```

Five commands, a few hundred tokens, and you know the state of a project you
have never seen. Do not read the whole file to orient — read it when you need
prose (Problem, Interfaces, a specific item's rationale).

## Two channels in, and why there are two

The human writes to you in two places, and they carry different traffic:

| | `## 1. Directions` | `> ANSWER:` on a `Q-` item |
|---|---|---|
| Carries | what the human brought unprompted | replies to what you asked |
| Shape | free prose, any format, any time | prose under a marker you placed |
| Obligation | none — may sit empty forever | none — silence becomes an `A-` item |
| Drained by | folding each line into a typed item | `resolve Q-n --into D-m` |

Read Directions **first**, before the inbox and before your own agenda. It is
the human's half of an ongoing conversation, and it outranks anything you were
planning to propose — same rule the vault's review skills already follow.

Then drain it. Each line becomes a typed item, and comes out of the section:

```bash
python3 "$VM" spec directions                       # read it
python3 "$VM" spec add R "..." --set acceptance=... # fold one line in
python3 "$VM" spec directions --set "<what's left>" # or --clear if nothing is
```

It accumulates between sessions and empties during them. A non-empty Directions
block at session end means you left the human's input on the floor; `validate`
warns for exactly that reason.

**Do not ask the human to use item syntax here.** The whole point is that this
channel costs them nothing — a protocol that demands discipline from the human
end gets abandoned in a fortnight, and then you have no channel at all.

**Never write into Directions yourself.** It is the human's side of the table.
Putting your own proposals there makes it impossible for them to tell their
thoughts from yours, and the channel stops being worth reading first.

### The channel follows the project

Same channel, two homes, depending on where the project has got to:

| Stage | Where Directions lives |
|---|---|
| a vault seed — the spec is the only file there is | `## 1. Directions` inside it |
| graduated into a repo | `DIRECTIONS.md` beside `PROJECT_SPEC.md` |

`spec directions` resolves this for you, so never branch on the lifecycle
yourself and never read either by hand. Graduation moves the content out and
deletes the section; **read the section out before creating the file**, because
once both exist the command refuses to read either — it cannot tell which holds
the real input, and guessing would strand the other. `validate` reports having
both as an error for the same reason.

Process the inbox second. Each answered question either:

- **settles a choice** → create a `D-` item with `from: [Q-n]`, recording the
  options that were rejected and why;
- **adds behaviour** → create or amend an `R-` item;
- **changes scope** → amend `G-`, `NG-`, or `C-`.

Then `spec resolve Q-n --into D-m`. Resolving without folding the answer into
a durable item is the one failure mode that quietly destroys the whole scheme:
the answer scrolls out of context and the next session asks again.

## Session end

Rewrite the handoff. Three lines, present tense, concrete:

```bash
python3 "$VM" spec handoff --set "- **Last session:** specified R-8..R-11 (rules engine), added D-4 (YAML rule format).
- **Now blocked on:** Q-7 (CFG availability) — R-12 and all of M-2 wait on it.
- **Next action:** if Q-7 comes back 'must-build', spike a CFG builder against SonarDelphi's AST before committing M-2 dates."
```

"Next action" should be executable by someone with no memory of the session.
"Continue working on the analyzer" is a failed handoff.

## Asking a question

A question is expensive — it costs a human round-trip measured in hours or days.
Spend one only when the answer changes what you would build, and say so in the
`blocks` field. If nothing is blocked, it is not a question; it is an assumption.

```bash
python3 "$VM" spec add Q "Should rule severity be configurable per-project?" \
  --set blocks=[R-8] \
  --body "Per-project config means the rules engine needs a merge layer over
defaults (~200 LOC). Fixed severities keep it flat. Cheaper to decide now than
to retrofit."
```

Give the human enough context to answer in one pass: what turns on it, what each
option costs, and a recommendation. A question that requires a clarifying
question in reply has doubled the latency of the whole pipeline.

## Silence is an answer

Do not stall on an unanswered question when you can proceed under a stated
assumption. Convert it and keep moving:

```bash
python3 "$VM" spec add A "Rule severities are fixed, not per-project" \
  --set confidence=medium --set impact_if_wrong="retrofit merge layer, ~2d" \
  --set from=[Q-8]
```

The assumption is addressable, so it is cheap to overturn later — the human can
scan `spec ls A --status unconfirmed` and refute one line. This is the whole
reason assumptions are first-class items rather than hedging in prose: an
unstated assumption fails silently at integration time, a stated one fails at
review time.

Only genuinely blocking questions should stop work. `blocked` should be short.

## Superseding

Never delete. Set `status: superseded` and add `supersedes: [D-3]` on the
replacement. The abandoned branch is the most valuable content in the file after
six weeks, because it is the thing a fresh agent will otherwise propose again.

## Who writes what

| | Human | Agent |
|---|---|---|
| `## 1. Directions` | yes, freely | reads and drains it, never writes into it |
| Answers under `> ANSWER:` | yes | never |
| `status` fields | may | yes |
| New `Q-` items | rarely | yes |
| New `R-`/`D-`/`A-` items | may | yes |
| Handoff | may | yes, every session |
| Changelog | — | automatic via `spec` |

The human has no obligations at all: Directions may sit empty, questions may go
unanswered (silence becomes an `A-` item and work continues). Everything is
optional for them and mandatory for the agent. Keep it that way — a protocol
that demands discipline from the human end will be abandoned in a fortnight.

The one rule the agent must not break: **never write into Directions.** It is
the human's side of the table. Putting your own proposals there makes it
impossible for them to tell their thoughts from yours, and the section stops
being worth reading first.

## Validation gate

`spec validate` before ending any session, and before flipping
`status: drafting` to `ready`. Exit code 1 means the spec has holes that will
turn into questions later, when they cost more. See RUBRIC.md for what it checks
and why each check earns its place.
