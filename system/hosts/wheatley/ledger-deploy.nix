# Auto-deploys ledger-web whenever a new commit is pushed to
# ~/Services/ledger (see ledger-web.nix and pkgs/ledger-web/default.nix).
#
# `receive.denyCurrentBranch = updateInstead` (set once, manually, on that
# repo) already makes a push update its working tree. What's missing is
# that ledger-src is a git+file:// flake input pinned in flake.lock, so the
# push alone doesn't change what's built — see README.md's "Deploying
# Local Services" for the full manual pipeline this automates.
#
# A post-receive hook (installed below, since .git/hooks isn't a tracked
# path) touches a trigger file; a systemd.path unit watches it and runs
# the same three-stage pipeline `just deploy-service` does by hand, split
# across privilege boundaries so no sudo/password is ever needed:
#   1. evf: bump the ledger-src lock (`just update ledger-src`)
#   2. root: build + activate (`nh os switch .` — already root, so nh
#      never shells out to sudo)
#   3. evf: tag the generation, push, sync home-manager, gc
#      (`just after-switch`)
#
# Steps 1 and 3 run as evf via `su` (root needs no password to switch
# user) with SSH_AUTH_SOCK pointed at evf's gpg-agent ssh-support socket,
# which stays alive headless because evf has `loginctl linger` enabled.
# Caveat: that key's passphrase cache (12h TTL, see home/auth/gpg.nix)
# can go cold with no session to unlock it, in which case step 3's push
# fails (visible via `systemctl status ledger-deploy`) even though the
# build/activate/service-restart already succeeded.
{ config, pkgs, ... }:
let
  dotfilesPath = config.dotfiles.path;
  ledgerRepo = "/home/evf/Services/ledger";
  triggerDir = "/run/ledger-deploy";
  triggerFile = "${triggerDir}/trigger";

  postReceiveHook = pkgs.writeShellScript "ledger-post-receive" ''
    mkdir -p ${triggerDir}
    date > ${triggerFile}
  '';

  deployScript = pkgs.writeShellScript "ledger-deploy" ''
    set -euo pipefail

    # Resolved at runtime: NixOS assigns a normal user's uid at
    # activation, not statically at eval time.
    sshAuthSock="/run/user/$(${pkgs.coreutils}/bin/id -u evf)/gnupg/S.gpg-agent.ssh"

    /run/wrappers/bin/su -s /bin/sh -c \
      "cd ${dotfilesPath} && SSH_AUTH_SOCK=$sshAuthSock ${pkgs.just}/bin/just update ledger-src || true" \
      evf

    cd ${dotfilesPath} && ${pkgs.nh}/bin/nh os switch .

    /run/wrappers/bin/su -s /bin/sh -c \
      "cd ${dotfilesPath} && SSH_AUTH_SOCK=$sshAuthSock ${pkgs.just}/bin/just after-switch" \
      evf
  '';
in
{

  systemd.tmpfiles.rules = [
    "d ${triggerDir} 0755 evf users -"
  ];

  system.activationScripts.ledgerDeployHook = ''
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
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${deployScript}";
    };
  };

}
