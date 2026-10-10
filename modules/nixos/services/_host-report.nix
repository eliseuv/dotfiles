# host-report: this host's system generations as JSON, for the homelab
# dashboard's host pages (homelab/dashboard/hosts.nix). Run there directly on
# the dashboard host, and on others through the remote-control forced command
# (services/remote-control.nix), so it takes only fixed verbs and checks its
# one argument itself.
#
#   host-report generations   current and booted systems, every generation
#   host-report diff <N>      closure diff of generation N against the
#                             previous generation that still exists
#
# A generation's commit comes from `revisionsDir`, where dotfiles-switch and
# the Justfile record which commit each system was built from; the system
# itself doesn't carry it (see services/dotfiles-switch.nix).
{
  pkgs,
  revisionsDir,
}:
pkgs.writeShellApplication {
  name = "host-report";
  runtimeInputs = with pkgs; [
    coreutils
    gawk
    jq
    nix
  ];
  text = ''
    profiles=/nix/var/nix/profiles

    # Generation numbers, ascending.
    numbers() {
      for link in "$profiles"/system-*-link; do
        [ -e "$link" ] || continue
        number=''${link#"$profiles"/system-}
        echo "''${number%-link}"
      done | sort -n
    }

    generation() {
      local number=$1 link path hash revision=null kernel=null
      link=$profiles/system-$number-link
      path=$(readlink -f "$link")
      hash=$(basename "$path")
      hash=''${hash%%-*}
      if [ -r ${revisionsDir}/"$hash" ]; then
        revision=$(jq -Rn --arg rev "$(cat ${revisionsDir}/"$hash")" '$rev')
      fi
      for modules in "$link"/kernel-modules/lib/modules/*; do
        [ -d "$modules" ] && kernel=$(jq -Rn --arg kernel "$(basename "$modules")" '$kernel')
      done
      # The link's own mtime (stat doesn't follow it) is when the generation
      # was made, as nixos-rebuild list-generations reports it.
      jq -n \
        --argjson number "$number" \
        --arg path "$path" \
        --argjson date "$(stat -c %Y "$link")" \
        --arg nixos "$(cat "$link"/nixos-version 2>/dev/null || true)" \
        --argjson kernel "$kernel" \
        --argjson revision "$revision" \
        '{$number, $path, $date, $nixos, $kernel, $revision}'
    }

    case "''${1:-}" in
    generations)
      numbers | while read -r number; do generation "$number"; done |
        jq -s \
          --arg host "$(cat /proc/sys/kernel/hostname)" \
          --arg current "$(readlink -f /run/current-system)" \
          --arg booted "$(readlink -f /run/booted-system)" \
          '{$host, $current, $booted, generations: .}'
      ;;
    diff)
      number=''${2:-}
      [[ $number =~ ^[0-9]+$ ]] && [ -e "$profiles/system-$number-link" ] || {
        echo "host-report: no generation ''${number:-<none>}" >&2
        exit 1
      }
      base=$(numbers | awk -v n="$number" '$1 < n { base = $1 } END { print base }')
      path=$(readlink -f "$profiles/system-$number-link")
      if [ -z "$base" ]; then
        jq -n --argjson number "$number" --arg path "$path" \
          '{$number, $path, base: null, base_path: null, changes: ""}'
        exit 0
      fi
      base_path=$(readlink -f "$profiles/system-$base-link")
      jq -n \
        --argjson number "$number" \
        --arg path "$path" \
        --argjson base "$base" \
        --arg base_path "$base_path" \
        --arg changes "$(nix store diff-closures "$base_path" "$path")" \
        '{$number, $path, $base, $base_path, $changes}'
      ;;
    *)
      echo "Usage: host-report generations | diff <N>" >&2
      exit 1
      ;;
    esac
  '';
}
