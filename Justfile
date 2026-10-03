update *inputs:
    nix flake update {{inputs}} --verbose
    git restore --staged .
    git add flake.lock
    git commit --message "[flake] update {{inputs}}"

update-nix:
    {{just_executable()}} update nixpkgs nixpkgs-master nixpkgs-stable

commit-gen:
    #!/usr/bin/env bash
    set -euo pipefail
    git diff --quiet && git diff --cached --quiet || \
        (echo "commit-gen: uncommitted changes present, commit before switching" >&2 && exit 1)
    gen="$(nixos-rebuild list-generations | rg "True$" | sd '^(\d+)\W+\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\W+([\w\.]+)\W+([\w\.]+).+True$' '$1 NixOS $2 Linux $3')"
    tag="$(hostname)-${gen%% *}"
    if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
        # A switch that lands on the same generation (nothing to activate)
        # re-runs commit-gen; the generation is already tagged, so no-op.
        echo "commit-gen: $tag already exists, generation unchanged, skipping"
        exit 0
    fi
    git tag --annotate "$tag" \
        --message "$(hostname) @ ${gen}" \
        --message "$(ls -dv1 /nix/var/nix/profiles/system-*-link | tail -2 | xargs -r nvd diff)"
    git push --follow-tags

gc keep='4':
    nh clean all --keep {{keep}} --no-gcroots

# Print the derivation path of every system and home configuration. A
# structure-only refactor should leave this output unchanged; diff it
# against a snapshot taken before the change.
# ledger-web is stubbed out: its source is fetched from a repo that only
# exists on wheatley (see README's "Deploying Local Services"), so without
# the stub wheatley can't be evaluated anywhere else.
eval-all:
    #!/usr/bin/env bash
    set -euo pipefail
    nix eval --json .#nixosConfigurations --apply '
      builtins.mapAttrs (_: c:
        let
          stub = { bin = c.pkgs.emptyDirectory; webUi = c.pkgs.emptyDirectory; };
          stubbed =
            if c.options ? homelab.ledger.package then
              c.extendModules { modules = [ { homelab.ledger.package = c.pkgs.lib.mkForce stub; } ]; }
            else
              c;
        in
        stubbed.config.system.build.toplevel.drvPath)' | jq -S .
    nix eval --json .#homeConfigurations --apply 'builtins.mapAttrs (_: c: c.activationPackage.drvPath)' | jq -S .

vpn:
    sudo tailscale up
    tailscale status

home-switch:
    nh home switch .

after-switch: commit-gen home-switch gc

system-test: && home-switch
    nh os test .

system-switch: && after-switch
    git diff -U0 '*.nix'
    nh os switch .

system-boot: && after-switch
    git diff -U0 '*.nix'
    nh os boot .

update-system:
    -{{just_executable()}} update nixpkgs && {{just_executable()}} system-switch
    {{just_executable()}} update-home

update-home:
    -{{just_executable()}} update
    {{just_executable()}} home-switch

# Pin a locally-packaged service (pkgs/<pkg>/pin.json) to the current HEAD
# of the repo it points at, and commit that. No-op when already pinned
# there, so re-running after a partial failure is safe.
pin-service pkg:
    #!/usr/bin/env bash
    set -euo pipefail
    pin="pkgs/{{pkg}}/pin.json"
    url="$(jq -r .url "$pin")"
    rev="$(git -C "${url#file://}" rev-parse HEAD)"
    if [ "$rev" = "$(jq -r .rev "$pin")" ]; then
        echo "pin-service: {{pkg}} already pinned at $rev, skipping"
        exit 0
    fi
    jq --arg rev "$rev" '.rev = $rev' "$pin" > "$pin.tmp"
    mv -f "$pin.tmp" "$pin"
    git restore --staged .
    git add "$pin"
    git commit --message "[pkgs] pin {{pkg}} ${rev:0:7}"

# Pick up a just-pushed commit for a locally-packaged service (see
# pkgs/<pkg>/default.nix and README's "local homebrew projects" pattern)
# and switch this host onto it. Run on the target host itself, after
# `git push <host-remote> <branch>` in the service's own repo. `nh os
# switch` needs a real sudo prompt, so over ssh use `-t` (no askpass
# helper is configured): ssh -t <host> -- 'cd ~/dotfiles && just
# deploy-service <pkg>'.
# Usage: just deploy-service ledger-web
deploy-service pkg:
    {{just_executable()}} pin-service {{pkg}}
    {{just_executable()}} system-switch

# Fetch a Claude Code release manifest (default: latest) for the
# manifestOverride escape hatch in modules/home/core/shell/ai/claude.nix. git-adds it
# because flakes can't see untracked files.
pin-claude-code version='':
    #!/usr/bin/env bash
    set -euo pipefail
    base="https://downloads.claude.ai/claude-code-releases"
    version="{{version}}"
    [ -n "$version" ] || version="$(curl -fsSL "$base/latest")"
    out="modules/home/core/shell/ai/claude-code-manifest.json"
    curl -fsSL "$base/$version/manifest.zst.json" --output "$out"
    git add "$out"
    echo "pin-claude-code: wrote $version to $out; set manifestOverride = ./claude-code-manifest.json"
