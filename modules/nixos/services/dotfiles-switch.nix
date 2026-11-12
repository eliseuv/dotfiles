# dotfiles-switch.service: pull and switch, for the homelab dashboard
# (started locally by svcctl on wheatley, or over SSH through
# services/remote-control.nix). Pulls origin/master, rebasing any local
# commits onto it, builds and activates this host's system, then switches the
# primary user's home through the Justfile, as them, and every other user's
# of this host from root, through sudo. Like `just system-switch` it tags the
# generation, but only tries to push the tag: commit-gen pushes the branch
# too, and either needs a GitHub credential the unit usually lacks. Unlike it,
# it doesn't collect garbage.
#
# Builds, git and Home Manager run as the primary user in their own checkout;
# only activation and becoming the other users run as root, through systemd's
# `+` prefix rather than sudo, so the user gains no passwordless sudo from
# this.
#
# Each run keeps its status in its StateDirectory, for the dashboard
# (_switch-status.nix reads it): the stage it got to, its result, the reason
# it failed and the generation's tag.
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

  # Runs one step of the unit as stage `name` of this run's status, keeping
  # its stderr for the finish step to find the reason in should it fail. A
  # step may name the reason itself, in $STATE_DIRECTORY/reason. The `+`
  # steps run it as root: status.json is replaced, never written in place,
  # so its owner doesn't matter.
  stage = pkgs.writeShellScript "dotfiles-switch-stage" ''
    set -uo pipefail
    name=$1
    shift
    dir=$STATE_DIRECTORY
    status=$(jq --compact-output --arg run "$INVOCATION_ID" \
      'select(.invocation == $run)' "$dir/status.json" 2>/dev/null)
    if [ -z "$status" ]; then
      rm -f "$dir/reason"
      status=$(jq --null-input --compact-output --arg run "$INVOCATION_ID" \
        --argjson now "$(date +%s)" '{invocation: $run, started_at: $now}')
    fi
    jq --null-input --argjson status "$status" --arg stage "$name" \
      '$status + {stage: $stage}' > "$dir/status.json.new"
    mv --force "$dir/status.json.new" "$dir/status.json"
    rm -f "$dir/stderr"
    # stdout straight through, stderr through tee.
    exec 3>&1
    "$@" 2>&1 1>&3 3>&- | tee "$dir/stderr" >&2
    exit "''${PIPESTATUS[0]}"
  '';

  pull = pkgs.writeShellScript "dotfiles-switch-pull" ''
    set -euo pipefail
    fail() {
      echo "dotfiles-switch: $1" >&2
      echo "$1" > "$STATE_DIRECTORY/reason"
      exit 1
    }
    # Another branch would be rebased onto master and built; switching
    # branches unattended could strand its work instead.
    branch=$(git symbolic-ref --quiet --short HEAD) || fail "detached HEAD, not on master"
    [ "$branch" = master ] || fail "on branch $branch, not master"
    # Uncommitted changes become a commit of their own, kept after the switch
    # for the user to amend or squash, so the build is always of a commit.
    # Untracked files stay as they are: the flake doesn't see them anyway.
    # --no-verify: an unattended snapshot mustn't fail on a hook.
    if ! git diff --quiet || ! git diff --cached --quiet; then
      git add --update
      git commit --quiet --no-verify \
        --message "wip: uncommitted changes at dashboard switch on ${config.my.host.name}"
      echo "dotfiles-switch: committed uncommitted changes as $(git rev-parse --short HEAD)"
    fi
    git fetch ${upstream} master:refs/remotes/origin/master
    # Unlike the Justfile's pull, a failed rebase is fatal: carrying on would
    # build whatever happened to be checked out. Abort so the checkout isn't
    # left mid-rebase for the next run (or the user) to trip over; the local
    # commits, the one above included, are back as they were.
    if ! git rebase --quiet origin/master >&2; then
      conflicts=$(git diff --name-only --diff-filter=U | paste -sd, -)
      # Nothing to abort when the rebase refused to start (an untracked file
      # in the way, say).
      git rebase --abort 2>/dev/null || true
      [ -n "$conflicts" ] || fail "rebase onto origin/master failed, aborted"
      fail "rebase onto origin/master conflicts in $conflicts, aborted"
    fi
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

  # The pull committed any uncommitted changes, so HEAD is what was built.
  record = pkgs.writeShellScript "dotfiles-switch-record" ''
    set -euo pipefail
    system=$(basename "$(readlink -f ${systemLink})")
    git rev-parse HEAD > ${revisionsDir}/"''${system%%-*}"
  '';

  # After every run, successful or not: tags the generation when the system
  # built in this run is the profile, which a failed activation can leave it
  # as too, and tries to push only the tag. Without an agent or a key the push
  # usually fails; the tag stays local until the next `git push --follow-tags`
  # from here. Then completes the run's status.
  finish = pkgs.writeShellScript "dotfiles-switch-finish" ''
    set -uo pipefail
    dir=$STATE_DIRECTORY
    tag=""
    built=$(readlink -f ${systemLink} 2>/dev/null)
    if [ -n "$built" ] && [ "$(readlink -f /nix/var/nix/profiles/system)" = "$built" ] \
      && tagged=$(${lib.getExe pkgs.just} tag-gen); then
      read -r tag outcome <<<"$tagged"
      echo "dotfiles-switch: $tag $outcome"
      GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10" \
        timeout 60 git push --quiet origin "refs/tags/$tag" \
        || echo "dotfiles-switch: couldn't push $tag, kept local" >&2
    fi

    result=''${SERVICE_RESULT:-unknown}
    message=""
    if [ "$result" != success ]; then
      # The step's own reason, else the first error nix or git gave (an
      # evaluation error's first `error:` line is bare; its cause follows,
      # indented), else just how it ended.
      message=$(cat "$dir/reason" 2>/dev/null)
      [ -n "$message" ] || message=$(grep --max-count=1 --extended-regexp \
        '^[[:space:]]*(error|fatal): .+' "$dir/stderr" 2>/dev/null | sed 's/^[[:space:]]*//')
      [ -n "$message" ] || message="$result (''${EXIT_STATUS:-?})"
    fi
    status=$(jq --compact-output --arg run "$INVOCATION_ID" \
      'select(.invocation == $run)' "$dir/status.json" 2>/dev/null)
    [ -n "$status" ] || status=$(jq --null-input --compact-output --arg run "$INVOCATION_ID" '{invocation: $run}')
    jq --null-input --argjson status "$status" --arg result "$result" \
      --arg message "''${message:0:500}" --arg tag "$tag" --argjson now "$(date +%s)" \
      '$status + {result: $result, message: ($message | if . == "" then null end), tag: ($tag | if . == "" then null end), finished_at: $now}' \
      > "$dir/status.json.new"
    mv --force "$dir/status.json.new" "$dir/status.json"
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
        # For the Justfile's tag-gen, and the tag push.
        config.system.build.nixos-rebuild
        pkgs.hostname
        pkgs.nvd
        pkgs.openssh
        pkgs.ripgrep
        pkgs.sd
      ];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        WorkingDirectory = repo;
        RuntimeDirectory = "dotfiles-switch";
        # The run's status, for _switch-status.nix; read by remote-control
        # and svcctl.
        StateDirectory = "dotfiles-switch";
        StateDirectoryMode = "0755";
        # Run in order, stopping at the first failure.
        # record before activating: a failed activation has already made
        # the new system the profile, and often the running one.
        ExecStart = [
          "${stage} pull ${pull}"
          "${stage} build ${build}"
          "${stage} record ${record}"
          "+${stage} activate ${activate}"
          "${stage} home ${lib.getExe pkgs.just} home-switch-self"
        ]
        ++ lib.optional (otherUsers != [ ]) "+${stage} home-others ${homeSwitchOthers}";
        # `-`: tagging never turns a switch into a failure.
        ExecStopPost = "-${finish}";
      };
    };

  };

}
