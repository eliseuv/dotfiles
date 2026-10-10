# Host pages: a page per host for tiles with `dashboard.page`, showing its
# generations, what changed between them, and whether it runs what master
# builds.
#
# What master builds comes from dotfiles-eval.service: on a timer, it fetches
# master from GitHub, as dotfiles-switch does, and evaluates each page host's
# system there. It runs as the primary user, in their checkout: wheatley's
# config fetches the ledger-web source from their home (pkgs/ledger-web).
# The commit goes to a ref of its own rather than origin/master, so a fetch
# here can't race a switch's for the ref lock. Evaluation only, no build: a
# host is up to date when its current system is the store path master
# evaluates to, so a commit that changes nothing else changes nothing here.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.my.host.primaryUser;
  repo = config.my.dotfiles.path;
  # The repo is public, so fetching anonymously over HTTPS needs no key.
  upstream = "https://github.com/eliseuv/dotfiles.git";
  evalRef = "refs/dotfiles-eval/master";
  # StateDirectory of dotfiles-eval.service, world-readable.
  evalFile = "/var/lib/dotfiles-eval/master.json";

  tiles = lib.filterAttrs (
    _: service: service.dashboard != null && service.dashboard.page != null
  ) config.homelab.services;
  pageHosts = lib.unique (lib.mapAttrsToList (_: service: service.dashboard.page) tiles);

  # Writes {rev, checked_at, evaluated_at, hosts: {<host>: {path} | {error}}}.
  # Skips evaluating when neither master nor the hosts changed.
  evaluate = pkgs.writeShellScript "dotfiles-eval" ''
    set -euo pipefail
    out=${evalFile}
    hosts=${lib.escapeShellArg (builtins.toJSON pageHosts)}
    git fetch --quiet ${upstream} +master:${evalRef}
    rev=$(git rev-parse ${evalRef})
    now=$(date +%s)
    if [ -e "$out" ] && jq -e --arg rev "$rev" --argjson hosts "$hosts" \
      '.rev == $rev and (.hosts | keys) == ($hosts | sort)' "$out" >/dev/null; then
      jq --argjson now "$now" '.checked_at = $now' "$out" > "$out.tmp"
      mv "$out.tmp" "$out"
      exit 0
    fi
    results='{}'
    for host in $(jq -r '.[]' <<<"$hosts"); do
      attr="nixosConfigurations.$host.config.system.build.toplevel.outPath"
      if path=$(nix eval --raw "git+file://${repo}?rev=$rev#$attr" 2>"$RUNTIME_DIRECTORY/err"); then
        results=$(jq --arg host "$host" --arg path "$path" '.[$host] = {$path}' <<<"$results")
      else
        cat "$RUNTIME_DIRECTORY/err" >&2
        error=$(grep -v "^Using saved setting" "$RUNTIME_DIRECTORY/err" | tail -n 5)
        results=$(jq --arg host "$host" --arg error "$error" '.[$host] = {$error}' <<<"$results")
      fi
    done
    jq -n --arg rev "$rev" --argjson now "$now" --argjson hosts "$results" \
      '{$rev, checked_at: $now, evaluated_at: $now, $hosts}' > "$out.tmp"
    mv "$out.tmp" "$out"
  '';
in
{

  config = lib.mkIf (config.my.homelab.enable && pageHosts != [ ]) {

    systemd.services.dotfiles-eval = {
      description = "Evaluate master's system for each dashboard host page";
      path = [
        config.nix.package
        pkgs.coreutils
        pkgs.git
        pkgs.gnugrep
        pkgs.jq
      ];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        WorkingDirectory = repo;
        StateDirectory = "dotfiles-eval";
        StateDirectoryMode = "0755";
        RuntimeDirectory = "dotfiles-eval";
        ExecStart = evaluate;
        # A gigabyte and some seconds of CPU per host; the services here
        # come first.
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    systemd.timers.dotfiles-eval = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "10min";
      };
    };

  };

}
