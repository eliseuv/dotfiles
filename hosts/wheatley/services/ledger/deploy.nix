# Auto-deploys ledger-web whenever a new commit is pushed to
# ~/Services/ledger (see web.nix and pkgs/ledger-web/default.nix).
#
# `receive.denyCurrentBranch = updateInstead` (set once, manually, on that
# repo) already makes a push update its working tree. What's missing is
# that ledger-web's source is pinned to a commit in
# pkgs/ledger-web/pin.json, so the push alone doesn't change what's built — see README.md's "Deploying
# Local Services" for the full manual pipeline this automates.
#
# A post-receive hook (installed below, since .git/hooks isn't a tracked
# path) records main's revision and a request ID; a systemd.path unit watches it and runs
# the same three-stage pipeline `just deploy-service` does by hand, split
# across privilege boundaries so no sudo/password is ever needed:
#   1. evf: bump the ledger-web pin (`just pin-service ledger-web`)
#   2. root: build + activate (`nh os switch .` — already root, so nh
#      never shells out to sudo)
#   3. evf: tag the generation, push, sync home-manager, gc
#      (`just after-switch`)
#
# Steps 1 and 3 run as evf via `su` (root needs no password to switch
# user) with SSH_AUTH_SOCK pointed at evf's gpg-agent ssh-support socket,
# which stays alive headless because evf has `loginctl linger` enabled.
# Caveat: that key's passphrase cache (12h TTL, see modules/home/core/auth/gpg.nix)
# can go cold with no session to unlock it, in which case step 3's push
# fails, deployment reports a bookkeeping warning after checking app health.
{ config, pkgs, ... }:
let
  dotfilesPath = config.my.dotfiles.path;
  user = config.my.host.primaryUser;
  ledgerRepo = "${config.users.users.${user}.home}/Services/ledger";
  triggerDir = "/run/ledger-deploy";
  triggerFile = "${triggerDir}/trigger";

  postReceiveHook = pkgs.writeShellScript "ledger-post-receive" ''
    set -euo pipefail
    while read -r _oldrev newrev ref; do
      if [ "$ref" = refs/heads/main ] && [[ "$newrev" != 0000000000000000000000000000000000000000 ]]; then
        request=$(cat /proc/sys/kernel/random/uuid)
        printf '%s %s\n' "$newrev" "$request" > ${triggerFile}.tmp
        mv ${triggerFile}.tmp ${triggerFile}
      fi
    done
  '';

  deployScript = pkgs.writeShellScript "ledger-deploy" ''
    set -euo pipefail

    read -r rev request < ${triggerFile}
    phase=pin
    write_status() {
      ${pkgs.jq}/bin/jq -n --arg rev "$rev" --arg request "$request" \
        --arg state "$1" --arg phase "$phase" \
        '{rev: $rev, request: $request, state: $state, phase: $phase}' \
        > ${triggerDir}/status.json.tmp
      chmod 644 ${triggerDir}/status.json.tmp
      mv ${triggerDir}/status.json.tmp ${triggerDir}/status.json
    }
    on_exit() {
      local rc=$?
      if [ "$rc" -ne 0 ]; then write_status failed; fi
    }
    trap on_exit EXIT
    write_status running

    # Pin exactly the revision associated with this request. A newer push
    # is picked up by the path watcher after this invocation finishes.
    actual=$(/run/wrappers/bin/su -s /bin/sh -c '${pkgs.git}/bin/git -C ${ledgerRepo} rev-parse HEAD' ${user})
    if [ "$actual" != "$rev" ]; then
      echo "Ledger checkout changed before deployment; refusing to pin a different revision" >&2
      exit 1
    fi

    # Resolved at runtime: NixOS assigns a normal user's uid at
    # activation, not statically at eval time.
    sshAuthSock="/run/user/$(${pkgs.coreutils}/bin/id -u ${user})/gnupg/S.gpg-agent.ssh"

    /run/wrappers/bin/su -s /bin/sh -c \
      "cd ${dotfilesPath} && SSH_AUTH_SOCK=$sshAuthSock ${pkgs.just}/bin/just pin-service ledger-web" \
      ${user}

    test "$(${pkgs.jq}/bin/jq -r .rev ${dotfilesPath}/pkgs/ledger-web/pin.json)" = "$rev"
    phase=activate
    write_status running
    cd ${dotfilesPath} && ${pkgs.nh}/bin/nh os switch .

    phase=health
    write_status running
    healthy=false
    for _attempt in $(seq 1 30); do
      if ${pkgs.systemd}/bin/systemctl is-active --quiet ledger-web.service && \
        ${pkgs.curl}/bin/curl --fail --silent --max-time 5 \
          http://127.0.0.1:${toString config.homelab.services.ledger.port}/api/accounts \
          | ${pkgs.jq}/bin/jq -e 'type == "array"' >/dev/null; then
        healthy=true
        break
      fi
      sleep 2
    done
    "$healthy"

    phase=bookkeeping
    write_status running
    if /run/wrappers/bin/su -s /bin/sh -c \
      "cd ${dotfilesPath} && SSH_AUTH_SOCK=$sshAuthSock ${pkgs.just}/bin/just after-switch" \
      ${user}; then
      write_status succeeded
    else
      echo "Ledger is healthy, but after-switch failed; see journalctl -u ledger-deploy" >&2
      write_status succeeded-with-warning
    fi
  '';
in
{

  systemd.tmpfiles.rules = [
    "d ${triggerDir} 0755 ${user} users -"
  ];

  system.activationScripts.ledgerDeployHook = ''
    /run/wrappers/bin/su -s /bin/sh -c '${pkgs.git}/bin/git -C ${ledgerRepo} config receive.denyCurrentBranch updateInstead' ${user}
    /run/wrappers/bin/su -s /bin/sh -c '${pkgs.git}/bin/git -C ${ledgerRepo} config receive.denyNonFastForwards true' ${user}
    /run/wrappers/bin/su -s /bin/sh -c '${pkgs.git}/bin/git -C ${ledgerRepo} config receive.denyDeletes true' ${user}
    install -Dm755 ${postReceiveHook} ${ledgerRepo}/.git/hooks/post-receive
  '';

  systemd.paths.ledger-deploy = {
    description = "Watch for pushes to ~/Services/ledger";
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathModified = triggerFile;
  };

  systemd.services.ledger-deploy = {
    description = "Deploy ledger-web from the latest push";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    # `nh os switch` (step 2, run directly as root below rather than via
    # `su`) shells out to a bare `nix`. Steps 1 and 3 go through `su`,
    # which pulls in PAM's fuller PATH for evf, but this unit's own PATH
    # is systemd's bare default (coreutils/findutils/grep/sed/systemd) —
    # no `nix` on it — so `nh` fails with a cryptic "No output from nix
    # --version command" instead of "command not found".
    path = [ config.nix.package ];
    # Activation may replace this unit while it is running; let it finish
    # its health check and report the result to the waiting client.
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${deployScript}";
    };
  };

}
