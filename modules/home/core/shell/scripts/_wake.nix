{
  pkgs,
  lib,
  wakeOnLan,
}:
let
  inherit (wakeOnLan) hosts relay;
  macCases = lib.concatMapAttrsStringSep "\n" (host: mac: "${lib.toLower host}) mac=${mac} ;;") hosts;
  peerNames = lib.concatMapStringsSep " " (host: "${host}.local") (
    lib.attrNames (removeAttrs hosts [ relay ])
  );
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
    if [ "$(hostname)" = ${relay} ]; then
      wakeonlan "$mac"
    elif [ "''${target,,}" = "${lib.toLower relay}" ]; then
      # With the relay asleep, any other wakeable host answering is the "am I
      # home" test instead. The packet goes out regardless, since a false
      # miss (everything at home asleep) mustn't block a real wake, but
      # without an answer the wake can't be vouched for, so it fails.
      wakeonlan "$mac"
      peers=$(timeout 3 avahi-resolve -4 -n ${peerNames} 2>/dev/null || true)
      if [ -z "$peers" ]; then
        echo "wake: no LAN host answered; if you're away from home that packet went nowhere." >&2
        echo "wake: ${relay} is the relay, so it can only be woken from its own LAN." >&2
        exit 1
      fi
    elif timeout 3 avahi-resolve -4 -n ${relay}.local >/dev/null 2>&1; then
      wakeonlan "$mac"
    else
      echo "wake: not on the LAN; asking ${relay} over the tailnet" >&2
      exec ssh ${relay} wake "$target"
    fi
  '';
}
