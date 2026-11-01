# dotfiles-switch.service: pull and switch, for the homelab dashboard
# (started locally by svcctl on wheatley, or over SSH through
# services/remote-control.nix). Pulls origin/master, rebasing any local
# commits onto it, builds and activates this host's system, then switches the
# primary user's home through the Justfile, as them, and every other user's
# of this host from root, through sudo. Unlike
# `just system-switch` it neither tags the generation (commit-gen pushes,
# which would need a GitHub credential on every host) nor collects garbage.
#
# Builds, git and Home Manager run as the primary user in their own checkout;
# only activation and becoming the other users run as root, through systemd's
# `+` prefix rather than sudo, so the user gains no passwordless sudo from
# this.
#
# Each switch records the commit it built in `revisionsDir`, keyed by the
# system's store hash, for the dashboard's host pages (_host-report.nix); the
# Justfile's record-gen does the same for switches by hand. Kept out of the
# system itself (system.configurationRevision would do that) so a commit that
# doesn't change the config doesn't change the system either.
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
  # RuntimeDirectory: owned by `user`, gone after each run.
  systemLink = "/run/dotfiles-switch/system";
  inherit (config.my.services.dotfilesSwitch) revisionsDir;

  pull = pkgs.writeShellScript "dotfiles-switch-pull" ''
    set -euo pipefail
    git diff --quiet && git diff --cached --quiet || {
      echo "dotfiles-switch: uncommitted changes in ${repo}, refusing" >&2
      exit 1
    }
    git fetch ${upstream} master:refs/remotes/origin/master
    # Unlike the Justfile's pull, a failed rebase is fatal: carrying on would
    # build whatever happened to be checked out. Abort so the checkout isn't
    # left mid-rebase for the next run (or the user) to trip over.
    git rebase origin/master || {
      git rebase --abort
      echo "dotfiles-switch: rebase onto origin/master failed, aborted" >&2
      exit 1
    }
  '';

  build = pkgs.writeShellScript "dotfiles-switch-build" ''
    set -euo pipefail
    nix build --out-link ${systemLink} \
      ".#nixosConfigurations.${config.my.host.name}.config.system.build.toplevel"
  '';

  # What `nh os switch` does once it has built.
  activate = pkgs.writeShellScript "dotfiles-switch-activate" ''
    set -euo pipefail
    # `+` keeps the unit's environment, user's HOME included; nix-env warns.
    export HOME=/root
    system=$(readlink -f ${systemLink})
    nix-env --profile /nix/var/nix/profiles/system --set "$system"
    exec "$system/bin/switch-to-configuration" switch
  '';

  # The pull refused uncommitted changes, so HEAD is what was built.
  record = pkgs.writeShellScript "dotfiles-switch-record" ''
    set -euo pipefail
    system=$(basename "$(readlink -f ${systemLink})")
    git rev-parse HEAD > ${revisionsDir}/"''${system%%-*}"
  '';

  # The Justfile's home-switch-others, for the service. The users come from
  # the same host list lib/ generates homeConfigurations from, so root never
  # evaluates the flake: libgit2 refuses a repo another user owns unless
  # root's git config lists it in safe.directory, which only shared hosts set
  # (core/dotfiles.nix). Each user evaluates it as themselves, through their
  # Home Manager safe.directory. A store script rather than `just`, so root
  # runs nothing from the checkout.
  otherUsers = lib.remove user config.my.host.users;
  homeSwitchOthers = pkgs.writeShellScript "dotfiles-switch-home-others" ''
    set -euo pipefail
    for other in ${lib.escapeShellArgs otherUsers}; do
      # Lets Home Manager restart their services and write dconf live when
      # they are logged in.
      runtime=/run/user/$(id -u "$other")
      session=()
      [ -d "$runtime" ] && session=(XDG_RUNTIME_DIR="$runtime" DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus")
      echo "dotfiles-switch: home of $other"
      /run/wrappers/bin/sudo -u "$other" -H env PATH="$PATH" "''${session[@]}" \
        ${lib.getExe pkgs.nh} home switch ${repo} --configuration "$other@${config.my.host.name}"
    done
  '';
in
{

  config = lib.mkIf config.my.services.dotfilesSwitch.enable {

    # Written by the primary user (here and by hand), read by anyone:
    # host-report runs as remote-control, or as hostctl on the dashboard host.
    systemd.tmpfiles.rules = [ "d ${revisionsDir} 0755 ${user} - -" ];

    systemd.services.dotfiles-switch = {
      description = "Pull the dotfiles and switch to them";
      # Switching would otherwise restart the very unit doing the switch.
      restartIfChanged = false;
      path = [
        config.nix.package
        # `sh` for just's recipes.
        pkgs.bash
        pkgs.coreutils
        pkgs.git
        pkgs.jq
        pkgs.nh
      ];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        WorkingDirectory = repo;
        RuntimeDirectory = "dotfiles-switch";
        # Run in order, stopping at the first failure.
        ExecStart = [
          pull
          build
          "+${activate}"
          record
          "${lib.getExe pkgs.just} home-switch-self"
        ]
        ++ lib.optional (otherUsers != [ ]) "+${homeSwitchOthers}";
      };
    };

  };

}
