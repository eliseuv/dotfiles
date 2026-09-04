#!/usr/bin/env bash
# Assertions for spec.py.
#
# Every bug found during the design session produced plausible-looking output
# while being wrong — a dropped field, an inverted relation, a status one letter
# off. So each check here compares against an exact expected value; nothing is
# left for a human to eyeball.
#
# Usage: scripts/selftest.sh    (exit 0 = all passed, 1 = failures)

set -u

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)
spec_py=$script_dir/spec.py
example_spec=$script_dir/../references/EXAMPLE_PROJECT_SPEC.md

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

passed=0
failed=0

report_pass() {
    passed=$((passed + 1))
    printf '  ok    %s\n' "$1"
}

report_fail() {
    failed=$((failed + 1))
    printf '  FAIL  %s\n' "$1"
    printf '        expected: %s\n' "$2"
    printf '        actual:   %s\n' "$3"
}

assert_eq() {  # label expected actual
    if [ "$2" = "$3" ]; then report_pass "$1"; else report_fail "$1" "$2" "$3"; fi
}

assert_contains() {  # label needle haystack
    case "$3" in
        *"$2"*) report_pass "$1" ;;
        *) report_fail "$1" "output containing '$2'" "$3" ;;
    esac
}

assert_absent() {  # label needle haystack
    case "$3" in
        *"$2"*) report_fail "$1" "output without '$2'" "$3" ;;
        *) report_pass "$1" ;;
    esac
}

section() { printf '\n%s\n' "$1"; }

spec() { python3 "$spec_py" "$@"; }

# Each test gets its own directory so a mutation in one cannot mask a bug in
# the next. Exports SPEC_FILE, which every later spec call picks up.
new_spec() {  # name
    local dir=$work/$1
    mkdir -p "$dir"
    export SPEC_FILE=$dir/PROJECT_SPEC.md
    if ! spec init "$1" >/dev/null; then
        printf 'selftest: init failed for %s — cannot continue\n' "$1" >&2
        exit 2
    fi
}

field_of() {  # id key -> the field's rendered value
    spec get "$1" | sed -n "s/^- $2: //p" | head -1
}

ids_of() {  # reads a --json array on stdin -> space-separated ids
    python3 -c 'import json,sys; print(" ".join(r["id"] for r in json.load(sys.stdin)))'
}

# Writes an answer under a question's ANSWER marker the way the human would:
# by hand, in the file, with no involvement from spec.py.
answer() {  # question-id text
    python3 - "$SPEC_FILE" "$1" "$2" <<'PY'
import sys

path, qid, text = sys.argv[1], sys.argv[2], sys.argv[3]
lines = open(path, encoding="utf-8").read().split("\n")
start = next(i for i, l in enumerate(lines) if l.startswith(f"### {qid} "))
marker = next(i for i in range(start, len(lines))
              if lines[i].strip() in ("> ANSWER:", "ANSWER:"))
parts = text.split("\n")
lines[marker:marker + 1] = ["> ANSWER: " + parts[0]] + ["> " + p for p in parts[1:]]
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
}

# Builds the minimal spec the smoke sequence and several later tests need:
# one goal, one non-goal, one requirement covering the goal, one first
# milestone covering the requirement, one question blocking the requirement.
seed_blocked_spec() {
    spec add G "goal" --set metric="measurable thing" >/dev/null
    spec add NG "explicitly out of scope" >/dev/null
    spec add R "requirement" --set acceptance="passes X" 'covers=[G-1]' >/dev/null
    spec add M "first milestone" --set 'covers=[R-1]' order=1 >/dev/null
    spec add Q "blocking question?" --set 'blocks=[R-1]' >/dev/null
}


section "bundle layout — spec.py finds its own assets/ and references/"
# Regression guard for the flat layout, where '..' from scripts/ resolved
# outside the bundle and both of these died with FileNotFoundError.
new_spec layout
seeded=$(cat "$SPEC_FILE")
assert_contains "init seeds the Goals item marker" "<!-- items: G -->" "$seeded"
assert_contains "init substitutes the project name" "project: layout" "$seeded"
assert_absent "init leaves no unsubstituted placeholder" "{{" "$seeded"
grammar_out=$(spec grammar 2>&1)
assert_eq "grammar exits 0 with no --template" 0 "$?"
assert_contains "grammar prints the format reference" "PROJECT_SPEC.md grammar" "$grammar_out"


section "default status per kind"
# Regression: defaults came from sorted(STATUSES[kind])[0], so requirements
# were born 'accepted' and milestones 'active' — both plausible, both wrong.
new_spec defaults
for kind in G NG C R D A Q RK M; do
    spec add "$kind" "title for $kind" >/dev/null
done
assert_eq "G defaults to proposed"     proposed    "$(field_of G-1 status)"
assert_eq "NG defaults to accepted"    accepted    "$(field_of NG-1 status)"
assert_eq "C defaults to proposed"     proposed    "$(field_of C-1 status)"
assert_eq "R defaults to draft"        draft       "$(field_of R-1 status)"
assert_eq "D defaults to proposed"     proposed    "$(field_of D-1 status)"
assert_eq "A defaults to unconfirmed"  unconfirmed "$(field_of A-1 status)"
assert_eq "Q defaults to open"         open        "$(field_of Q-1 status)"
assert_eq "RK defaults to open"        open        "$(field_of RK-1 status)"
assert_eq "M defaults to planned"      planned     "$(field_of M-1 status)"


section "repeated and multi-value --set"
# Regression: argparse nargs='*' without action='extend' made each --set
# overwrite the previous one, silently dropping covers/acceptance on add.
new_spec sets
spec add G "goal" --set metric=m >/dev/null
spec add R "req" --set acceptance="passes X" --set 'covers=[G-1]' --set status=specified >/dev/null
assert_eq "first of three repeated --set survives"  "passes X"  "$(field_of R-1 acceptance)"
assert_eq "second of three repeated --set survives" "[G-1]"     "$(field_of R-1 covers)"
assert_eq "third of three repeated --set survives"  "specified" "$(field_of R-1 status)"
spec add R "req two" --set acceptance="passes Y" 'covers=[G-1]' status=specified >/dev/null
assert_eq "multi-value --set keeps the first pair" "passes Y"  "$(field_of R-2 acceptance)"
assert_eq "multi-value --set keeps the last pair"  "specified" "$(field_of R-2 status)"
spec set R-1 status=accepted acceptance="passes Z" >/dev/null
assert_eq "set applies the first assignment"  accepted   "$(field_of R-1 status)"
assert_eq "set applies the second assignment" "passes Z" "$(field_of R-1 acceptance)"
assert_eq "set leaves untouched fields alone" "[G-1]"    "$(field_of R-1 covers)"


section "blocked — reverse map from questions to their targets"
# Regression: this checked an item's own 'blocks' field instead of building the
# reverse map, so it reported nothing blocked on a spec where a question
# blocked the entire first milestone. validate shared the bug.
new_spec blocked
seed_blocked_spec
assert_eq "exactly the question's target is blocked" "R-1" "$(spec --json blocked | ids_of)"
assert_contains "blocked names the blocking question" "Q-1" "$(spec blocked)"
assert_eq "the unanswered question is pending" "Q-1" "$(spec --json pending | ids_of)"
assert_eq "nothing is in the inbox yet" "" "$(spec --json inbox | ids_of)"
answer Q-1 "yes, do it the simple way."
assert_eq "answering clears the block" "" "$(spec --json blocked | ids_of)"
assert_eq "answering empties pending" "" "$(spec --json pending | ids_of)"
assert_eq "answering fills the inbox" "Q-1" "$(spec --json inbox | ids_of)"


section "smoke sequence — the documented end-to-end flow"
new_spec smoke
seed_blocked_spec
validate_out=$(spec validate 2>&1)
assert_eq "validate fails while the first milestone is blocked" 1 "$?"
assert_contains "validate names the blocked requirement" "R-1" "$validate_out"
assert_contains "validate names the blocking question" "Q-1" "$validate_out"
assert_contains "validate names the first milestone" "M-1" "$validate_out"
answer Q-1 $'yes, do it the simple way.\nSecond line of the answer.'
inbox_out=$(spec inbox)
assert_contains "inbox shows the answer text" "do it the simple way" "$inbox_out"
assert_contains "inbox shows what the question blocks" "R-1" "$inbox_out"
assert_contains "multi-line answers are captured whole" "Second line" "$(spec --json inbox)"
spec add D "how" --set 'options=[a,b]' chosen=a 'from=[Q-1]' status=accepted \
    --body "Simple way costs less to reverse." >/dev/null
spec resolve Q-1 --into D-1 >/dev/null
assert_eq "resolve marks the question answered" answered "$(field_of Q-1 status)"
assert_eq "resolve records where the answer went" "D-1" "$(field_of Q-1 resolved_into)"
assert_eq "resolved questions leave the inbox" "" "$(spec --json inbox | ids_of)"
spec validate >/dev/null 2>&1
assert_eq "validate passes once the question is folded in" 0 "$?"


section "resolve refuses to close an unanswered question"
new_spec resolve_guard
spec add Q "unanswered?" --set 'blocks=[]' >/dev/null
spec resolve Q-1 >/dev/null 2>&1
assert_eq "resolve without an answer exits 2" 2 "$?"
assert_eq "the question stays open" open "$(field_of Q-1 status)"
spec resolve Q-1 --force >/dev/null 2>&1
assert_eq "--force closes it anyway" answered "$(field_of Q-1 status)"


section "exit codes distinguish a failed check from a bad invocation"
# Callers branch on this: 1 means the spec has holes, 2 means the command was
# wrong. Collapsing them would make `validate || ask_the_human` fire on typos.
new_spec exit_codes
spec validate >/dev/null 2>&1
assert_eq "validate exits 1 when the rubric fails" 1 "$?"
spec get G-99 >/dev/null 2>&1
assert_eq "a missing item exits 2" 2 "$?"
spec add ZZ "unknown kind" >/dev/null 2>&1
assert_eq "a kind with no section marker exits 2" 2 "$?"


section "line-surgical mutation preserves hand-written prose"
# The whole design rests on spec.py never reserializing the document. A
# reserializing writer would eat everything below silently.
new_spec prose
prose_marker="PROSE-SENTINEL: a human wrote this paragraph by hand."
python3 - "$SPEC_FILE" "$prose_marker" <<'PY'
import sys

path, marker = sys.argv[1], sys.argv[2]
lines = open(path, encoding="utf-8").read().split("\n")
at = next(i for i, l in enumerate(lines) if l.startswith("## ") and "Problem" in l)
lines[at + 1:at + 1] = ["", marker]
open(path, "w", encoding="utf-8").write("\n".join(lines))
PY
spec add G "goal" --set metric=m --body "BODY-SENTINEL: rationale prose." >/dev/null
spec add R "req" --set acceptance=a 'covers=[G-1]' >/dev/null
spec set G-1 status=accepted >/dev/null
spec set G-1 metric="a much better metric" >/dev/null
spec log "an entry" >/dev/null
after=$(cat "$SPEC_FILE")
assert_contains "section prose survives four mutations" "$prose_marker" "$after"
assert_contains "item body survives mutations to its own fields" "BODY-SENTINEL" "$after"
assert_eq "the edited field took the new value" "a much better metric" "$(field_of G-1 metric)"
assert_eq "prose paragraph is not duplicated" 1 "$(grep -c "$prose_marker" "$SPEC_FILE")"


section "IDs are never reused"
new_spec ids
spec add G "one" --set metric=m >/dev/null
spec add G "two" --set metric=m >/dev/null
spec add G "three" --set metric=m >/dev/null
spec set G-2 status=dropped >/dev/null
assert_eq "next ID is max+1, not a gap fill" "G-4" "$(spec add G "four" --set metric=m)"
assert_eq "dropping an item does not renumber the rest" "G-1 G-2 G-3 G-4" "$(spec --json ls G | ids_of)"


section "superseding retains the abandoned branch"
new_spec supersede
spec add D "old way" --set 'options=[a,b]' chosen=a --body "Why we first chose a." >/dev/null
spec set D-1 status=superseded >/dev/null
spec add D "new way" --set 'options=[a,b]' chosen=b 'supersedes=[D-1]' status=accepted \
    --body "Why b won in the end." >/dev/null
assert_eq "both decisions remain listed" "D-1 D-2" "$(spec --json ls D | ids_of)"
assert_contains "the abandoned rationale is still readable" "Why we first chose a" "$(spec get D-1)"
assert_eq "the replacement points back" "[D-1]" "$(field_of D-2 supersedes)"
assert_eq "mentions finds the superseding item" "D-2" "$(spec --json ls --mentions D-1 | ids_of)"


section "validate — structural integrity"
new_spec dup_id
spec add G "goal" --set metric=m >/dev/null
printf '\n### G-1 — a hand-pasted duplicate\n- status: proposed\n- metric: m\n' >> "$SPEC_FILE"
out=$(spec validate 2>&1)
assert_eq "duplicate IDs fail validate" 1 "$?"
assert_contains "duplicate IDs are named as such" "duplicate ID" "$out"

new_spec bad_status
spec add G "goal" --set metric=m status=bogus >/dev/null
out=$(spec validate 2>&1)
assert_eq "a status outside the enum fails validate" 1 "$?"
assert_contains "the offending status is quoted back" "bogus" "$out"

new_spec dangling
spec add G "goal" --set metric=m >/dev/null
spec add R "req" --set acceptance=a 'covers=[G-99]' >/dev/null
out=$(spec validate 2>&1)
assert_eq "a dangling cross-reference fails validate" 1 "$?"
assert_contains "the dangling target is named" "G-99" "$out"


section "validate — rubric checks"
new_spec rubric
spec add G "goal without a metric" >/dev/null
out=$(spec validate 2>&1)
assert_eq "a goal with no metric fails" 1 "$?"
assert_contains "the missing metric is named" "metric" "$out"
spec set G-1 metric="now measurable" >/dev/null
out=$(spec validate 2>&1)
assert_eq "an empty Non-Goals section fails" 1 "$?"
assert_contains "unbounded scope is called out" "Non-Goals" "$out"
spec add NG "out of scope" >/dev/null
spec add R "req" --set 'covers=[G-1]' >/dev/null
out=$(spec validate 2>&1)
assert_eq "a requirement with no acceptance fails" 1 "$?"
assert_contains "the missing acceptance is named" "acceptance" "$out"
spec set R-1 acceptance="passes X" >/dev/null
spec add M "milestone covering nothing" >/dev/null
out=$(spec validate 2>&1)
assert_eq "a milestone covering nothing fails" 1 "$?"
spec set M-1 'covers=[R-1]' order=1 >/dev/null
spec validate >/dev/null 2>&1
assert_eq "the completed spec passes" 0 "$?"
spec add RK "an unmitigated risk" >/dev/null
out=$(spec validate 2>&1)
assert_eq "a warning alone still exits 0" 0 "$?"
assert_contains "the warning is reported" "mitigation" "$out"
spec validate --strict >/dev/null 2>&1
assert_eq "--strict turns that warning into a failure" 1 "$?"


section "dropped and superseded items are exempt from the rubric"
new_spec exempt
spec add G "live goal" --set metric=m >/dev/null
spec add NG "out of scope" >/dev/null
spec add G "abandoned goal with no metric" --set status=dropped >/dev/null
spec add D "abandoned decision with no options" --set status=superseded >/dev/null
out=$(spec validate 2>&1)
assert_eq "incomplete dropped items do not block validate" 0 "$?"
assert_absent "the dropped goal is not reported" "G-2" "$out"


section "handoff and status"
new_spec handoff
# Template guidance is an HTML comment, not placeholder text, so a spec that
# has never been handed off reads as empty and warns. An earlier template
# seeded '- **Last session:** —', which made this check unfireable.
out=$(spec validate 2>&1)
assert_contains "a never-written handoff warns" "Handoff section is empty" "$out"
spec handoff --set "- **Last session:** wrote the selftest.
- **Now blocked on:** nothing.
- **Next action:** install the skill and check it triggers." >/dev/null
assert_contains "handoff reads back what was written" "wrote the selftest" "$(spec handoff)"
out=$(spec validate 2>&1)
assert_absent "a filled handoff no longer warns" "Handoff section is empty" "$out"
spec add G "goal" --set metric=m >/dev/null
spec add Q "pending?" --set 'blocks=[]' >/dev/null
status_out=$(spec status)
assert_contains "status reports the project name" "handoff" "$status_out"
assert_contains "status counts the goals" "Goals" "$status_out"
assert_contains "status counts what awaits the human" "awaiting human:     1" "$status_out"


section "directions — the user's free-prose channel"
new_spec directions
# Minimally valid, so validate's exit code reflects Directions alone.
spec add G "goal" --set metric=m >/dev/null
spec add NG "out of scope" >/dev/null
spec handoff --set "- **Next action:** none." >/dev/null
spec validate >/dev/null 2>&1
assert_eq "the baseline spec passes" 0 "$?"
assert_eq "a fresh spec has empty directions" "(empty)" "$(spec directions)"
out=$(spec validate 2>&1)
assert_absent "empty directions do not warn" "Directions has" "$out"
spec directions --add "wire up the CFG spike before committing dates" >/dev/null
spec directions --add "second thought: two weeks feels optimistic" >/dev/null
assert_contains "--add keeps the first line" "CFG spike" "$(spec directions)"
assert_contains "--add appends the second" "two weeks feels optimistic" "$(spec directions)"
assert_eq "both lines are counted as undrained" 2 \
    "$(spec --json status | python3 -c 'import json,sys; print(json.load(sys.stdin)["directions_undrained"])')"
out=$(spec validate 2>&1)
assert_contains "undrained directions warn" "Directions has 2 undrained" "$out"
assert_eq "undrained directions are a warning, not an error" 0 "$(spec validate >/dev/null 2>&1; echo $?)"
# The guidance comment must survive every mutation, or the user loses the only
# explanation of what the section is for.
spec directions --set "- only this one survives" >/dev/null
assert_eq "--set replaces the content" "- only this one survives" "$(spec directions)"
assert_contains "--set preserves the guidance comment" "Yours, not the agent's" "$(cat "$SPEC_FILE")"
spec directions --clear >/dev/null
assert_eq "--clear empties it" "(empty)" "$(spec directions)"
assert_contains "--clear preserves the guidance comment" "Yours, not the agent's" "$(cat "$SPEC_FILE")"
out=$(spec validate 2>&1)
assert_absent "a drained section stops warning" "Directions has" "$out"
# Prose sections are not item sections: nothing here should ever parse as one.
spec directions --set "- R-99 looks wrong to me" >/dev/null
assert_eq "directions content never becomes an item" "G-1 NG-1" "$(spec --json ls | ids_of)"
spec validate >/dev/null 2>&1
assert_eq "an ID mentioned in prose is not a dangling reference" 0 "$?"


section "query filters"
new_spec queries
spec add G "goal one" --set metric=m status=accepted >/dev/null
spec add G "goal two" --set metric=unknown >/dev/null
spec add R "req one" --set acceptance=a 'covers=[G-1]' status=specified >/dev/null
spec add R "req two" --set acceptance=b 'covers=[G-1]' status=draft >/dev/null
assert_eq "--status filters to one value" "R-1" "$(spec --json ls R --status specified | ids_of)"
assert_eq "--not-status excludes" "R-1" "$(spec --json ls R --not-status draft | ids_of)"
assert_eq "--where matches a scalar field" "R-2" "$(spec --json ls R --where acceptance=b | ids_of)"
assert_eq "--where matches inside a list field" "R-1 R-2" "$(spec --json ls R --where covers=G-1 | ids_of)"
assert_eq "--mentions finds referrers" "R-1 R-2" "$(spec --json ls --mentions G-1 | ids_of)"
assert_eq "--unresolved finds null-valued fields" "G-2" "$(spec --json ls G --unresolved | ids_of)"
assert_eq "multiple kinds can be listed at once" "G-1 G-2 R-1 R-2" "$(spec --json ls G R | ids_of)"
assert_eq "--columns restricts the output" "R-1 specified" "$(spec ls R --status specified --columns id,status | tail -1 | tr -s ' ')"
spec add G "with prose" --set metric=m --body "BODY-TEXT here." >/dev/null
assert_absent "bodies are omitted by default" "BODY-TEXT" "$(spec --json ls G)"
assert_contains "--body includes them" "BODY-TEXT" "$(spec --json ls G --body)"


section "grammar edge cases"
new_spec edges
spec add G "a title — with an em-dash" --set metric="ratio a:b under 0.5 — measured on CI" >/dev/null
assert_eq "an em-dash in the title parses" "a title — with an em-dash" \
    "$(spec --json ls G | python3 -c 'import json,sys; print(json.load(sys.stdin)[0]["title"])')"
assert_eq "a colon and em-dash inside a value survive" "ratio a:b under 0.5 — measured on CI" \
    "$(field_of G-1 metric)"
spec add G "null-ish" --set metric=TBD >/dev/null
assert_eq "TBD parses as unresolved" "G-2" "$(spec --json ls G --unresolved | ids_of)"
spec add R "list field" --set acceptance=a 'covers=[G-1, G-2]' >/dev/null
assert_eq "a multi-element list round-trips" "[G-1, G-2]" "$(field_of R-1 covers)"


section "CRLF input"
new_spec crlf
spec add G "goal" --set metric=m >/dev/null
spec add NG "out of scope" >/dev/null
python3 - "$SPEC_FILE" <<'PY'
import sys

path = sys.argv[1]
data = open(path, "rb").read().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")
open(path, "wb").write(data)
PY
assert_eq "a CRLF file still parses" "G-1" "$(spec --json ls G | ids_of)"
spec validate >/dev/null 2>&1
assert_eq "a CRLF file still validates" 0 "$?"
spec set G-1 status=accepted >/dev/null
assert_eq "a CRLF file is still writable" accepted "$(field_of G-1 status)"


section "the bundled example spec"
example_out=$(SPEC_FILE=$example_spec spec validate 2>&1)
assert_eq "EXAMPLE_PROJECT_SPEC.md passes clean" 0 "$?"
assert_contains "with no warnings either" "ok — spec passes the rubric" "$example_out"


printf '\n%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" -eq 0 ]
