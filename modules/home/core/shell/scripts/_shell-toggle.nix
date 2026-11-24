# Overrides my.home.shell on this machine, for shells started from then on.
# The hook in zsh.nix reads the file.
{
  pkgs,
  lib,
  defaultShell,
}:
pkgs.writeShellApplication {
  name = "shell-toggle";
  runtimeInputs = [ pkgs.coreutils ];
  text = ''
    state=''${XDG_STATE_HOME:-$HOME/.local/state}/interactive-shell
    default=${lib.escapeShellArg defaultShell}

    # As the hook does, anything else in the file means the default
    override=
    if [ -r "$state" ]; then
      read -r override <"$state" || true
    fi
    case "$override" in
      zsh | nushell) current=$override ;;
      *)
        override=
        current=$default
        ;;
    esac

    case "''${1:-toggle}" in
      toggle) if [ "$current" = zsh ]; then chosen=nushell; else chosen=zsh; fi ;;
      zsh) chosen=zsh ;;
      nu | nushell) chosen=nushell ;;
      reset)
        rm -f "$state"
        echo "$default (default), for new shells"
        exit
        ;;
      status)
        if [ -n "$override" ]; then
          echo "$current (default: $default)"
        else
          echo "$current (default)"
        fi
        exit
        ;;
      *)
        echo "usage: shell-toggle [zsh|nu|reset|status]" >&2
        exit 2
        ;;
    esac

    mkdir -p "$(dirname "$state")"
    echo "$chosen" >"$state"
    echo "$chosen, for new shells"
  '';
}
