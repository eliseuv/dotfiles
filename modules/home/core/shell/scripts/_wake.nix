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
    getent
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
    if [ "''${target,,}" = "${lib.toLower relay}" ] ||
      [ "$(hostname)" = ${relay} ] ||
      timeout 3 getent hosts ${relay}.local >/dev/null; then
      wakeonlan "$mac"
    else
      echo "wake: not on the LAN; asking ${relay} over the tailnet" >&2
      exec ssh ${relay} wake "$target"
    fi
  '';
}
