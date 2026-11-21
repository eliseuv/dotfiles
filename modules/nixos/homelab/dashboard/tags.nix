# Publishes every switch host's generation tags to GitHub. dotfiles-switch
# can't push them (it has no GitHub credential), so it exports each tag's raw
# object (services/dotfiles-switch.nix), and this host collects and pushes
# them. Publishing the exact object keeps the tag's SHA, so the host's own
# later `push --follow-tags` of it is a no-op rather than an `already exists`
# rejection.
#
# Split across two users so neither holds both keys, the way git-hub.nix
# splits receiving from forwarding:
# - tag-collect.service runs as svcctl, which holds the remote-control SSH
#   key: it reads this host's exports directly and every other switch host's
#   through the `tags` verb of its forced command, and queues each tag not yet
#   published. A tag must be named for the host it came from.
# - tag-publish.service runs as git, which holds git-hub/github-key (an
#   account key): a path unit starts it when the queue fills. It recreates
#   each object in a bare repo of its own, checks it is a tag of a commit on
#   GitHub, and pushes only those tag refs, never forced. A tag whose commit
#   isn't on GitHub (a `wip:` commit a switch made and nobody pushed) is
#   skipped and collected again later.
# The queue is emptied on every run, success or not: a kept file would have
# the path unit start the service again at once, in a loop. Whatever wasn't
# published is queued again by the next collection.
#
# Collection runs on a timer, so a host that was off is caught later; after
# this host's own switch (onSuccess/onFailure); and when svcctl sees a
# remote switch it started end (svcctl.py).
{
  config,
  lib,
  pkgs,
  hostSpecs,
  ...
}:
let
  machineOf = import ./_machines.nix { inherit config lib hostSpecs; };
  # Host -> {local, hosts, user} for every tile machine that switches.
  switchHosts = lib.listToAttrs (
    map
      (machine: {
        name = machine.host;
        value = {
          inherit (machine) local;
          hosts = machine.sshTargets;
          user = machine.sshUser;
        };
      })
      (
        lib.filter (machine: machine.switch) (
          map (service: machineOf service.dashboard.host) (
            lib.attrValues (
              lib.filterAttrs (
                _: service: service.dashboard != null && service.dashboard.host != null
              ) config.homelab.services
            )
          )
        )
      )
  );
  remoteHosts = lib.filterAttrs (_: target: !target.local) switchHosts;
  switchesHere = lib.any (target: target.local) (lib.attrValues switchHosts);

  # Anonymous HTTPS for reads; pushes over SSH with the hub's key.
  upstream = "https://github.com/eliseuv/dotfiles.git";
  pushUrl = "git@github.com:eliseuv/dotfiles.git";

  stateDir = "/var/lib/tag-publish";
  queueDir = "${stateDir}/queue";
  # Where tag-collect writes a file before moving it into the queue, so the
  # path unit never sees a partial one.
  incomingDir = "${stateDir}/incoming";
  # A file per published tag, holding its SHA; read by tag-collect to skip it.
  publishedDir = "${stateDir}/published";
  repoDir = "${stateDir}/repo.git";

  inherit (config.my.services.dotfilesSwitch) tagsDir;
  sshKey = config.sops.secrets."svcctl/poweroff-ssh-key".path;

  collect = pkgs.writeShellApplication {
    name = "tag-collect";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.openssh
    ];
    text = ''
      # Queues each tag in the JSON array on stdin ([{name, object}], as the
      # `tags` verb prints it) that is named for host $1 and not yet published.
      queue() {
        local host=$1 entry name
        jq --compact-output '.[]' | while read -r entry; do
          name=$(jq --raw-output .name <<<"$entry")
          if ! [[ $name =~ ^$host-[0-9]+$ ]]; then
            echo "tag-collect: refused $name from $host" >&2
            continue
          fi
          [ -e "${publishedDir}/$name" ] && continue
          jq --join-output .object <<<"$entry" > "${incomingDir}/$name"
          mv --force "${incomingDir}/$name" "${queueDir}/$name"
          echo "tag-collect: queued $name"
        done
      }

      # This host's exports, in the same shape as the verb's.
      local_tags() {
        shopt -s nullglob
        local file
        for file in ${tagsDir}/*; do
          [[ $file == *.new ]] && continue
          jq --null-input --arg name "$(basename "$file")" --rawfile object "$file" '{$name, $object}'
        done | jq --slurp .
      }

      # Like svcctl.py's remote_any(): each name in turn while ssh can't
      # connect (255); any other exit is the forced command's answer. A host
      # not redeployed since it gained `tags` refuses the verb.
      remote_tags() {
        local user=$1 status=255 host output
        shift
        for host in "$@"; do
          output=$(timeout 30 ssh -F /dev/null -i ${sshKey} -o BatchMode=yes -o ConnectTimeout=5 \
            -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/dev/null \
            "$user@$host" tags) && { printf '%s' "$output"; return 0; }
          status=$?
          [ "$status" = 255 ] || return "$status"
        done
        return "$status"
      }

      ${lib.optionalString switchesHere ''
        local_tags | queue ${config.my.host.name}
      ''}
      ${lib.concatStrings (
        lib.mapAttrsToList (host: target: ''
          if tags=$(remote_tags ${lib.escapeShellArgs ([ target.user ] ++ target.hosts)}); then
            queue ${host} <<<"$tags"
          else
            echo "tag-collect: ${host} unreachable or without the tags verb, skipped"
          fi
        '') remoteHosts
      )}
    '';
  };

  knownHosts = pkgs.writeText "tag-publish-known-hosts" ''
    github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
  '';

  publish = pkgs.writeShellApplication {
    name = "tag-publish";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.openssh
    ];
    text = ''
      export GIT_SSH_COMMAND="ssh -i ${
        config.sops.secrets."git-hub/github-key".path
      } -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${knownHosts}"
      work=$(mktemp --directory)
      trap 'rm -rf "$work"' EXIT
      # Emptied first, whatever happens next; see the header.
      shopt -s nullglob
      for file in ${queueDir}/*; do mv "$file" "$work/"; done
      files=("$work"/*)
      [ ''${#files[@]} -gt 0 ] || exit 0

      [ -d ${repoDir} ] || git init --quiet --bare ${repoDir}
      cd ${repoDir}
      git fetch --quiet ${upstream} '+refs/heads/*:refs/remotes/origin/*'
      published=$(git ls-remote --tags ${upstream})

      refs=()
      names=()
      for file in "''${files[@]}"; do
        name=$(basename "$file")
        if ! [[ $name =~ ^[A-Za-z0-9]+-[0-9]+$ ]]; then
          echo "tag-publish: refused $name: not a generation tag" >&2
          continue
        fi
        # hash-object checks the object is a well-formed tag.
        if ! sha=$(git hash-object -t tag -w "$file"); then
          echo "tag-publish: refused $name: not a tag object" >&2
          continue
        fi
        # The header ends at the first blank line.
        header=$(sed '/^$/q' "$file")
        commit=$(sed -n 's/^object //p' <<<"$header")
        if ! grep -qx "type commit" <<<"$header" || ! grep -qxF "tag $name" <<<"$header"; then
          echo "tag-publish: refused $name: not a tag named $name of a commit" >&2
          continue
        fi
        remote=$(awk -v ref="refs/tags/$name" '$2 == ref { print $1 }' <<<"$published")
        if [ -n "$remote" ]; then
          [ "$remote" = "$sha" ] \
            || echo "tag-publish: $name is on GitHub as $remote, not $sha; left as it is" >&2
          echo "$remote" > ${publishedDir}/"$name"
          continue
        fi
        if ! git cat-file -e "$commit^{commit}" 2>/dev/null; then
          echo "tag-publish: $name tags $commit, which isn't on GitHub; skipped"
          continue
        fi
        git update-ref "refs/tags/$name" "$sha"
        refs+=("refs/tags/$name:refs/tags/$name")
        names+=("$name")
      done

      [ ''${#refs[@]} -gt 0 ] || exit 0
      git push --quiet ${pushUrl} "''${refs[@]}"
      for name in "''${names[@]}"; do
        git rev-parse "refs/tags/$name" > ${publishedDir}/"$name"
        echo "tag-publish: published $name"
      done
    '';
  };
in
{

  config =
    lib.mkIf (config.my.homelab.enable && config.my.services.gitHub.enable && switchHosts != { })
      {

        # The queue is written by svcctl and emptied by git.
        systemd.tmpfiles.rules = [
          "d ${stateDir} 0755 git git -"
          "d ${queueDir} 0770 git svcctl -"
          "d ${incomingDir} 0700 svcctl svcctl -"
          "d ${publishedDir} 0755 git git -"
        ];

        systemd.services.tag-collect = {
          description = "Queue the switch hosts' generation tags for publishing";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "svcctl";
            Group = "svcctl";
            ExecStart = lib.getExe collect;
          };
        };

        systemd.timers.tag-collect = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitActiveSec = "15min";
          };
        };

        # finish (ExecStopPost) has exported the tag by the time either fires.
        systemd.services.dotfiles-switch = lib.mkIf switchesHere {
          onSuccess = [ "tag-collect.service" ];
          onFailure = [ "tag-collect.service" ];
        };

        # For svcctl.py, once a remote switch it watches ends.
        systemd.services.svcctl.environment.SVCCTL_TAG_COLLECT = "tag-collect.service";
        security.polkit.extraConfig = ''
          polkit.addRule(function (action, subject) {
            if (
              action.id == "org.freedesktop.systemd1.manage-units" &&
              subject.user == "svcctl" &&
              action.lookup("unit") == "tag-collect.service" &&
              action.lookup("verb") == "start"
            ) {
              return polkit.Result.YES;
            }
          });
        '';

        systemd.paths.tag-publish = {
          description = "Watch for generation tags to publish";
          wantedBy = [ "multi-user.target" ];
          pathConfig.DirectoryNotEmpty = queueDir;
        };

        systemd.services.tag-publish = {
          description = "Push queued generation tags to GitHub";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            User = "git";
            Group = "git";
            ExecStart = lib.getExe publish;
          };
        };

      };

}
