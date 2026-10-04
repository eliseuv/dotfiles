{
  pkgs,
  lib,
  wakeOnLan,
}:
let
  inherit (wakeOnLan) hosts relay;
  macCases = lib.concatMapAttrsStringSep "\n" (host: mac: "${lib.toLower host}) mac=${mac} ;;") hosts;
in
pkgs.writeShellApplication {
  name = "wake";
  runtimeInputs = with pkgs; [
    wakeonlan
    avahi
    coreutils
  ];
  text = ''
    usage() {
      echo "Usage: wake <host>   (one of: ${lib.concatStringsSep ", " (lib.attrNames hosts)})" >&2
      exit 1
    }

    [ "$#" -eq 1 ] || usage
    target="$1"
    case "''${target,,}" in
    ${macCases}
      *) usage ;;
    esac

    # Being able to resolve the relay over mDNS is the "am I home" test: it
    # only answers on the LAN, unlike a subnet check, which a foreign network
    # numbered like ours would pass. The relay itself can only be woken from
    # the LAN, and while it sleeps it doesn't answer, so it skips the test.
    # Ask avahi directly rather than through NSS: a miss there falls through
    # to unicast DNS, and the router takes ~4s to NXDOMAIN .local names.
    if [ "''${target,,}" = "${lib.toLower relay}" ] ||
      [ "$(hostname)" = ${relay} ] ||
      timeout 3 avahi-resolve -4 -n ${relay}.local >/dev/null 2>&1; then
      wakeonlan "$mac"
    else
      echo "wake: not on the LAN; asking ${relay} over the tailnet" >&2
      exec ssh ${relay} wake "$target"
    fi
  '';
}
