{ pkgs, lib }:
pkgs.writeShellScriptBin "schedule-claude" ''
  if [ "$#" -lt 2 ]; then
    echo "Usage: schedule-claude <time> <prompt>"
    echo "Example: schedule-claude \"14:30\" \"Write a poem about NixOS\""
    echo "Example: schedule-claude \"tomorrow\" \"Tell me a joke\""
    echo "Example: schedule-claude \"10:00 2026-08-24\" \"Summarize the news\""
    exit 1
  fi

  TIME="$1"
  shift
  PROMPT="$*"

  OUTPUT_FILE="$HOME/claude_output_$(date +%Y%m%d_%H%M%S).txt"
  
  JOB_SCRIPT=$(mktemp)
  PROMPT_FILE=$(mktemp)
  
  echo "$PROMPT" > "$PROMPT_FILE"
  
  echo "#!/bin/sh" > "$JOB_SCRIPT"
  echo "export PATH=\"$PATH\"" >> "$JOB_SCRIPT"
  echo "export HOME=\"$HOME\"" >> "$JOB_SCRIPT"
  echo "claude -p \"\$(cat \"$PROMPT_FILE\")\" > \"$OUTPUT_FILE\" 2>&1" >> "$JOB_SCRIPT"
  echo "rm -f \"$PROMPT_FILE\" \"$JOB_SCRIPT\"" >> "$JOB_SCRIPT"
  
  at "$TIME" -f "$JOB_SCRIPT"
  
  echo "Scheduled Claude prompt for $TIME."
  echo "Output will be saved to $OUTPUT_FILE"
''
