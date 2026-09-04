---
spec_version: 1
project: delphi-borrowck
status: drafting
created: 2026-09-03
updated: 2026-09-03
---

# delphi-borrowck

## 0. Handoff

- **Last session:** scoped goals, settled CFG approach (D-1).
- **Now blocked on:** nothing.
- **Next action:** spike CFG construction against SonarDelphi 4.x AST; validate against corpus cases 1-5.

## 1. Directions

<!-- Yours, not the agent's. Write anything here, in any shape, at any time: a
     one-line request, a paragraph of second-guessing, a phased plan. You are
     never obliged to use the item format, and never obliged to answer anything.

     Each session reads this before its own agenda and drains it — every line
     becomes a typed item (a requirement, a non-goal, a question) and is removed
     from here. It accumulates between sessions and empties during them.

     This is the channel for what you bring unprompted. The `> ANSWER:` markers
     on Open Questions are the channel for replies to what the agent asked. -->

## 2. Problem

_What is broken today, for whom, and what it costs them. No solutions here._

## 3. Goals

<!-- items: G -->

### G-1 — Detect use-after-move on managed records
- metric: zero false negatives on 40-case corpus
- status: accepted

### G-2 — Run inside DelphiLint IDE flow
- metric: analysis completes in <2s on save for a 5k-LOC unit
- status: accepted



## 4. Non-Goals

<!-- items: NG -->

### NG-1 — Full memory-safety proof
- status: accepted


## 5. Constraints

<!-- items: C -->

## 6. Glossary

_Terms that mean something specific in this project. Cheap to write, and it
stops two async participants from silently using one word for two things._

## 7. Requirements

<!-- items: R -->

### R-1 — Intraprocedural ownership tracking
- acceptance: passes corpus cases 1-22
- covers: [G-1]
- status: specified

### R-2 — Interprocedural ownership tracking
- acceptance: passes corpus cases 23-40
- covers: [G-1]
- status: accepted

### R-3 — Dangling
- covers: 
- acceptance: z
- status: dropped



## 8. Interfaces

_The externally visible contract: CLI surface, API shapes, file formats, exit
codes. Prose and code blocks, not items — this section is quoted, not queried._

## 9. Decisions

<!-- items: D -->

### D-1 — Build our own CFG rather than fork SonarDelphi
- options: [use-sonar-cfg, build-own, fork]
- chosen: build-own
- from: [Q-1]
- status: accepted

SonarDelphi exposes only the AST. Forking would cost DelphiLint IDE integration; ~2wk of CFG construction is the cheaper trade.


## 10. Assumptions

<!-- items: A -->

### A-1 — SonarDelphi's AST is stable across 4.x
- confidence: medium
- impact_if_wrong: pin version, ~1d
- from: [Q-1]
- status: unconfirmed


## 11. Open Questions

<!-- items: Q -->

### Q-1 — Does SonarDelphi expose a CFG at the plugin API boundary?
- blocks: [R-1, M-1]
- status: answered
- asked: 2026-09-03
- resolved_into: D-1

If not, we build CFG construction ourselves (~2wk) or fork, losing DelphiLint integration.

> ANSWER: No, only the AST is exposed. Build our own CFG —
> two weeks is acceptable, I'd rather not fork.


## 12. Risks

<!-- items: RK -->

### RK-1 — CFG construction overruns the 2wk estimate
- mitigation: timebox; fall back to intraprocedural-only for M-1
- status: open


## 13. Milestones

<!-- items: M -->

### M-1 — Intraprocedural analyzer usable
- covers: [R-1]
- order: 1
- status: active


## 14. Changelog

_Append-only. Newest at the bottom._
- 2026-09-03 — added G-1: Detect use-after-move on managed records
- 2026-09-03 — added G-2: Run inside DelphiLint IDE flow
- 2026-09-03 — added NG-1: Full memory-safety proof
- 2026-09-03 — added R-1: Intraprocedural ownership tracking
- 2026-09-03 — added R-2: Interprocedural ownership tracking
- 2026-09-03 — added M-1: Intraprocedural analyzer usable
- 2026-09-03 — added Q-1: Does SonarDelphi expose a CFG at the plugin API boundary?
- 2026-09-03 — added D-1: Build our own CFG rather than fork SonarDelphi
- 2026-09-03 — resolved Q-1 into D-1
- 2026-09-03 — G-2 metric: ∅ -> analysis completes in <2s on save for a 5k-LOC unit; status: accepted -> accepted
- 2026-09-03 — added A-1: SonarDelphi's AST is stable across 4.x
- 2026-09-03 — added RK-1: CFG construction overruns the 2wk estimate
- 2026-09-03 — R-1 status: accepted -> bogus
- 2026-09-03 — added R-3: Dangling
