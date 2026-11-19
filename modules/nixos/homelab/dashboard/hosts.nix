# Host pages: a page per host tile whose machine runs dotfiles-switch,
# showing its generations, what changed between them, and whether it runs
# what master builds.
#
# What master builds comes from dotfiles-eval.service: on a timer, it fetches
# master from GitHub, as dotfiles-switch does, and evaluates each page host's
# system there. It runs as the primary user, in their checkout: wheatley's
# config fetches the ledger-web source from their home (pkgs/ledger-web).
# The commit goes to a ref of its own rather than origin/master, so a fetch
# here can't race a switch's for the ref lock. Evaluation only, no build: a
# host is up to date when its current system is the store path master
# evaluates to, so a commit that changes nothing else changes nothing here.
#
# The rest comes from each host, through svcctl (controls.nix), whose
# host_pages.py runs host-report (services/_host-report.nix) here for this
# host, and for others logs in to their remote-control forced command
# (services/remote-control.nix) as it does for its buttons. It caches what it
# got, so a host that's off still shows its last report. That API is
# read-only and open like svcctl's status, the dashboard's reach (LAN +
# tailnet); the pages' switch button is svcctl's, behind its login.
{
  config,
  lib,
  pkgs,
  hostSpecs,
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

  machineOf = import ./_machines.nix { inherit config lib hostSpecs; };
  # Tile name -> the machine it stands for (_machines.nix).
  machines = lib.mapAttrs (_: service: machineOf service.dashboard.host) (
    lib.filterAttrs (
      _: service: service.dashboard != null && service.dashboard.host != null
    ) config.homelab.services
  );
  tileName = name: config.homelab.services.${name}.dashboard.name;
  # Hosts that keep generation reports, i.e. run dotfiles-switch.
  paged = lib.filterAttrs (_: machine: machine.page) machines;
  pageHosts = lib.unique (lib.mapAttrsToList (_: machine: machine.host) paged);

  tailnetAddress = host: config.homelab.network.tailnet.${host} or null;
  # Host -> {tile, hosts, user, switch, mdns, tailnet}.
  pages = lib.mapAttrs' (
    name: machine:
    lib.nameValuePair machine.host {
      tile = tileName name;
      hosts = machine.sshTargets;
      user = machine.sshUser;
      inherit (machine) switch;
      mdns = "${lib.toLower machine.host}.local";
      tailnet = tailnetAddress machine.host;
    }
  ) paged;
  # Machines that can't run host-report: svcctl reads only their uptime, over
  # SNMP.
  snmpMachines = lib.filterAttrs (_: machine: machine.snmp != null) machines;
  snmpSecrets = lib.unique (lib.mapAttrsToList (_: machine: machine.snmp) snmpMachines);
  snmpHosts = lib.mapAttrs' (
    name: machine:
    lib.nameValuePair machine.host {
      tile = tileName name;
      hosts = [ machine.address ];
      user = machine.sshUser;
      switch = false;
      snmp = true;
      mdns = machine.address;
      tailnet = tailnetAddress machine.host;
    }
  ) snmpMachines;

  svg = import ./_svg.nix;
  # Static; host.js reads the host from the query string.
  page = pkgs.linkFarm "host-page" {
    "index.html" = pkgs.writeText "index.html" (
      builtins.replaceStrings
        [ "@favicon@" "@iris@" "@repo@" ]
        [
          (svg.iris "#ff9a00")
          (svg.iris "black")
          (lib.removeSuffix ".git" upstream)
        ]
        (builtins.readFile ./host-page/index.html)
    );
    "host.js" = ./host-page/host.js;
    "host.css" = ./host-page/host.css;
    "facility.css" = ./facility.css;
    "facility.js" = ./facility.js;
  };

  hostReport = lib.getExe (
    import ../../services/_host-report.nix {
      inherit pkgs;
      inherit (config.my.services.dotfilesSwitch) revisionsDir;
    }
  );

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

    assertions = [
      {
        assertion = lib.length pageHosts == lib.length (lib.attrNames paged);
        message = "homelab.services.*.dashboard.host: one tile per host with a page";
      }
      {
        assertion = lib.length snmpSecrets <= 1;
        message = "homelab.externalHosts.*.snmp: svcctl takes one SNMP client config, shared by every SNMP machine";
      }
    ];

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

    homelab.svcctl.hostPages = {
      hosts = pages // snmpHosts;
      eval_file = evalFile;
      host_report = hostReport;
    };

    sops.secrets = lib.genAttrs snmpSecrets (_: {
      owner = "svcctl";
    });

    # Merged into svcctl's unit (controls.nix): snmpget for the SNMP tiles,
    # and somewhere to keep reports and diffs; net-snmp's engine state goes in
    # its runtime directory.
    systemd.services.svcctl = {
      path = [ pkgs.net-snmp ];
      environment = lib.optionalAttrs (snmpSecrets != [ ]) {
        SVCCTL_SNMP_CONF = config.sops.secrets.${lib.head snmpSecrets}.path;
      };
      serviceConfig = {
        StateDirectory = "svcctl";
      };
    };

    services.nginx.virtualHosts.dashboard.locations."/hosts/".alias = "${page}/";

    systemd.timers.dotfiles-eval = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "10min";
      };
    };

  };

}
