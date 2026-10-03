{ pkgs, lib }:
pkgs.writeShellScriptBin "ntfy-done" ''
  PID="$1"
  COMM=$(</proc/"$PID"/comm)

  while [ -d "/proc/$PID" ]
    do sleep 60
  done

  ${lib.getExe pkgs.curl} \
  -H "Title: $(whoami)@$(hostname)" \
  -H "Tags: checkered_flag" \
  -d "Finished: $COMM" \
  ntfy.sh/"$NTFY_TOPIC";
''
