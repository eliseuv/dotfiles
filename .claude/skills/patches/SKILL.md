---
name: patches
description: Add, review and remove temporary workarounds for upstream breakage in this dotfiles repo (modules/{nixos,home}/patches/, indexed in PATCHES.md). Use when working around a nixpkgs/upstream bug, after a flake.lock update, when evaluation warns "patch <id> may be obsolete", or when the user asks to review, check or clean up patches or workarounds.
---

# patches

Workarounds for upstream breakage (nixpkgs unstable, Home Manager, upstream
programs) are kept apart from the configuration they bend, so they can be
found and removed. The mechanism:

- **One module per patch**: `modules/nixos/patches/<id>.nix` or
  `modules/home/patches/<id>.nix`, auto-imported. The file name is the id.
- **Metadata**: the module sets `my.patches.<id>` (declared in
  `modules/shared/patches.nix`) under the same `mkIf` as its fix: `description`,
  `upstream`, `removeWhen`, `added`, `status.{checked,note}`, optional
  `staleWhen` and `locations`.
- **Index**: `PATCHES.md` at the root is generated from the metadata of every
  configuration (`lib/patches.nix`). Never edit it by hand: run `just patches`.
- **Check**: `just patches-check` (the flake check `patches-index`) fails on a
  stale `PATCHES.md`, a patch file active on no configuration, a
  `my.patches` id without a file, or a `locations` file missing its
  `PATCH(<id>)` marker.
- **Staleness**: a `staleWhen` that evaluates true makes evaluation warn
  `patch <id> may be obsolete`.

The flake only sees tracked files: `git add` (or `git add -N`) a new patch file
before `just patches`, or it is silently absent from the index.

## Add a patch

1. **Confirm it's a workaround.** It should exist because of an upstream
   defect and be meant to go away. Permanent configuration choices are not
   patches.
2. **Pick an id**: kebab-case, naming the affected thing and the problem
   (`rtkit-rttime-hyprland-dpms`, `zotero-firefox-esr`).
3. **Write the module** with the narrowest gate: the feature option the problem
   belongs to (`config.my.desktop.hyprland.enable`), not a broad one. Put the
   fix and `my.patches.<id>` inside the same `mkIf`. A comment on the fix says
   why it works.
4. **Fill the metadata from facts only.**
   - `upstream`: real issue/PR URLs you have seen; empty if none is known.
     Never guess a link.
   - `removeWhen`: a condition someone can check (a PR in the locked
     nixpkgs, a version, a log line that stops appearing). "When fixed
     upstream" is not enough.
   - `status.note`: what was observed, with dates.
   - `staleWhen`: add one when removal can be detected at evaluation time.
     Examples: `lib.versionAtLeast pkgs.foo.version "1.2"`, or
     `(builtins.tryEval pkgs.foo.drvPath).success` for a package that
     currently refuses to evaluate.
5. **In-place changes.** When part of the change can't live in the module (a
   package removed from a list elsewhere), mark each such spot with a
   `PATCH(<id>)` comment and list the file in `locations`.
6. **Verify and commit.**
   - `git add -N` the module, `just patches`, `just patches-check`.
   - Evaluate an affected configuration to see the fix takes effect.
   - Commit the module, the in-place edits and `PATCHES.md` together:
     `[patches] add <id>`.

## Review patches

Run after a `flake.lock` update, on an obsolescence warning, or when asked.
For each entry in `PATCHES.md`:

1. **Upstream state.** Check every link:
   `gh issue view <n> -R <owner/repo> --json state,closedAt,comments` and
   `gh pr view <n> -R <owner/repo> --json state,mergedAt,mergeCommit`. A closed
   issue or PR often points to a different fix (a superseding PR); follow it,
   and update `upstream` when the real fix differs from the recorded one.
2. **Is a merged nixpkgs fix in the lock?** Take the locked rev
   (`jq -r .nodes.nixpkgs.locked.rev flake.lock`, or the `nixpkgs-stable` /
   `nixpkgs-master` node the patch concerns), then run
   `gh api repos/NixOS/nixpkgs/compare/<merge commit>...<locked rev> --jq .status`.
   `ahead` or `identical` means the lock contains the fix; `behind` or
   `diverged` means it doesn't yet.
3. **Evaluate what the condition names**: versions
   (`nix eval '.#homeConfigurations."evf@GLaDOS".pkgs.<pkg>.version'`),
   whether a package evaluates, option values.
4. **Runtime bugs.** For a crash or kernel/driver interaction, evaluation
   proves nothing. Read the journal for the symptom that `removeWhen` names.
5. **Record.** Rewrite `status` with today's date and only what you observed;
   the previous note survives in git. If nothing changed but the date, still
   update `checked`. Correct `removeWhen` if it turns out to be uncheckable or
   wrong.
6. **Regenerate and commit.** Run `just patches` and `just patches-check`, then
   commit the reviewed modules and `PATCHES.md`: `[patches] review <id>`, or
   `[patches] review` for a batch of status-only updates.

Never invent a next step or a status. If the state can't be determined (no
upstream link, no access), say so in the note.

## Remove a patch

Remove only when `removeWhen` is verifiably met.

- **Verifiable by evaluation** (fix in the lock, version reached, package
  evaluates): remove it.
  1. Delete the module.
  2. Revert every in-place change listed in `locations`, including the
     `PATCH(<id>)` marker.
  3. Run `just patches` and `just patches-check`.
  4. Evaluate every configuration listed under "Active on" (`just eval-all`
     covers all of them).
  5. Commit: `[patches] drop <id>`, with what you observed that justified it.
- **Runtime bugs, or anything the user has to judge** (a security trade-off
  such as permitting an insecure package): don't delete. Present the evidence,
  what removal changes and the symptom to re-test after switching, and ask
  first.
- **After removing**: tell the user to switch (system and/or home, depending
  on the patch's directory) and what to watch for.

A patch that depends on another (e.g. diagnostics kept for an open bug) names
it in `removeWhen`. Remove them in that order.

## Rules

- One patch per commit. Never fold patch changes into unrelated commits.
- Keep aven task refs out of commits, `PATCHES.md` and metadata.
- `PATCHES.md` is generated: a hand edit fails the check.
- Keep README's description of the mechanism accurate if the mechanism itself
  changes (`lib/patches.nix`, `modules/shared/patches.nix`).
