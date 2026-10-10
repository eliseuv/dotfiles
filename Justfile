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

# Record the commit the newest system was built from, for the homelab
# dashboard's host pages (as dotfiles-switch.service does; see
# modules/nixos/services/dotfiles-switch.nix). Before commit-gen, which stops
# at uncommitted changes, so a switch from a dirty tree is still recorded, as
# such. A no-op on hosts without the directory (no dotfilesSwitch).
[private]
record-gen:
    #!/usr/bin/env bash
    set -euo pipefail
    dir=/var/lib/dotfiles-revisions
    [ -d "$dir" ] || exit 0
    system=$(basename "$(readlink -f /nix/var/nix/profiles/system)")
    rev=$(git rev-parse HEAD)
    git diff --quiet HEAD || rev="$rev-dirty"
    echo "$rev" > "$dir/${system%%-*}"

# Prompt for sudo up front and keep the timestamp fresh for as long as this
# `just` process lives, so the elevation inside `nh os switch` and `gc` (which
# can land well past sudo's 5 min timeout on a long build) doesn't prompt again.
[private]
sudo-keepalive:
    @sudo -v
    @while kill -0 $PPID 2>/dev/null; do sudo -n -v; sleep 60; done &

gc keep='4': sudo-keepalive
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

after-switch: record-gen commit-gen home-switch gc

system-test: sudo-keepalive && home-switch
    nh os test .

system-switch: sudo-keepalive && after-switch
    git diff -U0 '*.nix'
    nh os switch .

system-boot: sudo-keepalive && after-switch
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

# Accept password logins over ssh for a while, so a new client can
# `ssh-copy-id` this host; Ctrl-C ends it early. sshd_config is a
# read-only store path, so rather than rebuild, the regular sshd is
# stopped and a foreground one takes its place with password auth
# overridden on the command line (which wins over the config file).
# KillMode=process keeps existing sessions alive across the stop, so this
# is safe to run over ssh; the trap brings the regular sshd back however
# this exits.
ssh-allow-password duration='5m':
    #!/usr/bin/env bash
    set -euo pipefail
    sudo -v
    trap 'sudo systemctl start sshd.service' EXIT
    sudo systemctl stop sshd.service
    echo "ssh-allow-password: accepting passwords for {{duration}}, Ctrl-C to stop early"
    status=0
    sudo timeout {{duration}} "$(command -v sshd)" -D -e -f /etc/ssh/sshd_config \
        -o PasswordAuthentication=yes -o KbdInteractiveAuthentication=yes || status=$?
    # 124: timed out, 130/143: interrupted; both are the intended way out.
    case "$status" in 0|124|130|143) ;; *) exit "$status" ;; esac
