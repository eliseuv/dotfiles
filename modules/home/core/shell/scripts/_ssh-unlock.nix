# Asks gpg-agent for the passphrase of every SSH key it holds but hasn't
# cached, while someone is at a terminal to type it: once the cache lapses, an
# unattended job (e.g. a scheduled Claude run pushing) gets "agent refused
# operation", as pinentry has nowhere to ask. Signing a throwaway message
# triggers the prompt locally, without contacting any host.
{
  pkgs,
  lib,
  # gpg-agent's maxCacheTtlSsh: how long an unlock lasts at most, or null
  cacheTtl,
}:
pkgs.writeShellApplication {
  name = "ssh-unlock";
  runtimeInputs = with pkgs; [
    openssh
    gnupg
    gawk
    coreutils
  ];
  text = ''
    if ! GPG_TTY=$(tty); then
      echo "ssh-unlock: run it from a terminal, where the passphrase can be typed" >&2
      exit 1
    fi
    export GPG_TTY
    # Point pinentry at this terminal (and display, if any)
    gpg-connect-agent updatestartuptty /bye >/dev/null

    if ! keys=$(ssh-add -L); then
      echo "ssh-unlock: the agent holds no SSH keys" >&2
      exit 1
    fi

    # Fingerprints of the keys whose passphrase is cached; KEYINFO fields are
    # keygrip, type, serialno, idstr, cached, protection, fpr, ...
    cached=$(gpg-connect-agent 'keyinfo --ssh-list --ssh-fpr' /bye | awk '$1 == "S" && $7 == "1" { print $9 }')

    pubkey=$(mktemp)
    trap 'rm -f "$pubkey"' EXIT
    unlocked=0
    while read -r key; do
      printf '%s\n' "$key" >"$pubkey"
      description=$(ssh-keygen -lf "$pubkey")
      fingerprint=$(awk '{ print $2 }' <<<"$description")
      if grep -qxF "$fingerprint" <<<"$cached"; then
        echo "already unlocked: $description"
        continue
      fi
      echo "unlocking: $description"
      # With a public key, ssh-keygen signs through the agent
      echo | ssh-keygen -Y sign -f "$pubkey" -n ssh-unlock >/dev/null
      unlocked=$((unlocked + 1))
    done <<<"$keys"

    ${lib.optionalString (cacheTtl != null) ''
      if [ "$unlocked" -gt 0 ]; then
        echo "unlocked until $(date -d '+${toString cacheTtl} seconds' '+%a %H:%M') at the latest"
      fi
    ''}
  '';
}
