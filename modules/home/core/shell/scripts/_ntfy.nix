{ pkgs, lib }:
pkgs.writeShellScriptBin "ntfy" ''
  BODY="$1"

  ${lib.getExe pkgs.curl} \
  -H "Title: $(whoami)@$(hostname)" \
  -H "Tags: zap" \
  -d "$BODY" \
  ntfy.sh/"$NTFY_TOPIC";
''
