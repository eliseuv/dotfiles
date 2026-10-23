# Central git hub: every host uses `git@wheatley:<name>.git` as origin, and
# wheatley forwards pushes on to GitHub for the repos that have a GitHub
# remote.
#
# A dedicated `git` user, as in remote-control.nix: each authorized key is
# pinned to a forced command, so a key can't open a shell or run anything
# else. The command (`wrapper`) accepts only:
#   - git-receive-pack / git-upload-pack on a validated path under `root`,
#     creating the bare repo on the first receive-pack (git can't create on
#     push by itself), and
#   - `github-set <repo> <url>` / `github-unset <repo>`, which manage the
#     repo's `github` remote. A repo without one is simply not forwarded.
#
# Forwarding is asynchronous, so a slow or unreachable GitHub never delays a
# push from a host: the post-receive hook drops a marker into the queue
# directory, a path unit sees it, and a oneshot service pushes. A rejected
# push (GitHub diverged) fails the unit, which `systemctl --failed` shows.
# Pushes are never forced and never prune: refs deleted here stay on GitHub,
# and anything merged on GitHub (a PR) is fetched by hand in the bare repo,
# e.g. `git fetch github main:main`.
#
# GitHub auth is the `git-hub/github-key` secret in secrets/hosts/<host>.yaml.
# GitHub allows a deploy key on one repo only, so a key shared by every
# forwarded repo has to be an account (or machine-user) key.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.services.gitHub;
  user = "git";
  queueDir = "/var/lib/git-hub/queue";
  git = lib.getExe pkgs.git;

  # Components may not start with a dot, which also rules out `..`.
  repoPattern = "^[A-Za-z0-9_-][A-Za-z0-9._-]*(/[A-Za-z0-9_-][A-Za-z0-9._-]*)*$";
  githubUrlPattern = "^git@github\\.com:[A-Za-z0-9_-][A-Za-z0-9._-]*/[A-Za-z0-9_-][A-Za-z0-9._-]*\\.git$";

  # Via core.hooksPath (set in the wrapper's environment) rather than copied
  # into each repo, so a rebuild updates the hook everywhere.
  hooksDir = pkgs.linkFarm "git-hub-hooks" [
    {
      name = "post-receive";
      path = pkgs.writeShellScript "git-hub-post-receive" ''
        set -eu
        ${git} config --get remote.github.url >/dev/null || exit 0
        # Repo path relative to root, with / flattened to @ for a file name.
        name=$(${pkgs.coreutils}/bin/realpath --relative-to=${cfg.root} "$PWD")
        : > "${queueDir}/$(printf '%s' "$name" | ${pkgs.coreutils}/bin/tr / @)"
      '';
    }
  ];

  wrapper = pkgs.writeShellScript "git-hub-wrapper" ''
    set -eu
    export PATH=${lib.makeBinPath [ pkgs.git pkgs.coreutils ]}
    export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=${hooksDir}
    cd ${cfg.root}

    refuse() {
      echo "git-hub: refused: $*" >&2
      exit 1
    }

    # Accepts `name`, `name.git` and `/name.git`; sets $repo (relative, always
    # ending in .git).
    parse_repo() {
      repo=''${1#/}
      repo=''${repo%/}
      [[ $repo == *.git ]] || repo=$repo.git
      [[ $repo =~ ${repoPattern} ]] || refuse "bad repository name"
    }

    read -r verb arg1 arg2 extra <<<"''${SSH_ORIGINAL_COMMAND:-}"
    [ -z "$extra" ] || refuse "too many arguments"

    case "$verb" in
    git-upload-pack | git-receive-pack)
      # git single-quotes the path: git-receive-pack 'name.git'. Stripped by
      # hand, never evaluated: the string is client-controlled.
      quoted=''${arg1#\'}
      parse_repo "''${quoted%\'}"
      if [ ! -d "$repo" ]; then
        [ "$verb" = git-receive-pack ] || refuse "no such repository: $repo"
        mkdir -p "$(dirname "$repo")"
        git init --quiet --bare --initial-branch=main "$repo"
      fi
      exec "$verb" "$repo"
      ;;
    github-set)
      parse_repo "$arg1"
      [ -d "$repo" ] || refuse "no such repository: $repo"
      [[ ''${arg2:-} =~ ${githubUrlPattern} ]] || refuse "url must be git@github.com:<owner>/<repo>.git"
      git -C "$repo" remote remove github 2>/dev/null || true
      git -C "$repo" remote add github "$arg2"
      ;;
    github-unset)
      parse_repo "$arg1"
      [ -d "$repo" ] || refuse "no such repository: $repo"
      git -C "$repo" remote remove github
      ;;
    *)
      refuse "''${SSH_ORIGINAL_COMMAND:-<none>}"
      ;;
    esac
  '';

  knownHosts = pkgs.writeText "git-hub-known-hosts" ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
  '';

  forward = pkgs.writeShellScript "git-hub-forward" ''
    set -u
    export PATH=${lib.makeBinPath [ pkgs.git pkgs.openssh pkgs.coreutils ]}
    export GIT_SSH_COMMAND="ssh -i ${config.sops.secrets."git-hub/github-key".path} -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${knownHosts}"
    failed=0
    for marker in ${queueDir}/*; do
      [ -e "$marker" ] || continue
      # Removed before pushing, so a push landing meanwhile re-queues the repo.
      rm -f "$marker"
      repo=$(basename "$marker" | tr @ /)
      echo "pushing $repo"
      git -C ${cfg.root}/"$repo" push github 'refs/heads/*:refs/heads/*' 'refs/tags/*:refs/tags/*' || {
        echo "push of $repo failed" >&2
        failed=1
      }
    done
    exit $failed
  '';
in
{

  config = lib.mkIf cfg.enable {

    # sshd runs the forced command through the login shell, so this user needs
    # a real one (the wrapper uses bash); `restrict` and the forced command are
    # what keep it inert.
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = cfg.root;
      useDefaultShell = true;
      openssh.authorizedKeys.keys = map (key: ''restrict,command="${wrapper}" ${key}'') cfg.authorizedKeys;
    };
    users.groups.${user} = { };

    sops.secrets."git-hub/github-key".owner = user;

    systemd.tmpfiles.rules = [
      "d ${cfg.root} 0750 ${user} ${user} -"
      "d ${queueDir} 0750 ${user} ${user} -"
    ];

    systemd.paths.git-hub-forward = {
      description = "Watch for pushes to forward to GitHub";
      wantedBy = [ "multi-user.target" ];
      pathConfig.DirectoryNotEmpty = queueDir;
    };

    systemd.services.git-hub-forward = {
      description = "Push repos received by the git hub on to GitHub";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        ExecStart = forward;
      };
    };

  };

}
