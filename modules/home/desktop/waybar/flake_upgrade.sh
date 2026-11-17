#!/usr/bin/env bash
# Click action of the waybar flake module, run inside $TERMINAL: the full
# upgrade, then a verdict that can't be missed, with the window held open
# so the output can be read whichever way it went.

cd "$HOME/dotfiles" || exit 1
just upgrade
status=$?

echo
if [ "$status" -eq 0 ]; then
    printf '\e[1;32m%s\e[0m\n' "upgrade: done"
else
    printf '\e[1;31m%s\e[0m\n' "upgrade: FAILED (exit $status), scroll up for the error"
fi
read -rp "Press Enter to close"
