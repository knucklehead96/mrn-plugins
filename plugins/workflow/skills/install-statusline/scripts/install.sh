#!/bin/bash

set -euo pipefail

usage() {
  sed -n '5,13s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"
}

FORCE=0
for arg in "$@"; do
  case "$arg" in
    --force)   FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *)         echo "error: unknown argument: $arg" >&2; usage >&2; exit 1 ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not installed." >&2
  echo "  Debian/Ubuntu: sudo apt-get install jq" >&2
  echo "  macOS:         brew install jq" >&2
  exit 1
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/statusline-command.sh"
DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TS=$(date +%Y%m%d-%H%M%S)

if [ ! -f "$SRC" ]; then
  echo "error: bundled script not found: $SRC" >&2
  exit 1
fi

mkdir -p "$DIR"
DIR="$(cd "$DIR" && pwd)"
DEST="$DIR/statusline-command.sh"
SETTINGS="$DIR/settings.json"
WANT=$(jq -cn --arg cmd "bash \"$DEST\"" '{type: "command", command: $cmd}')

# --- Pre-flight: check settings.json before changing anything ---
# A symlinked settings.json is resolved so the backup and the atomic
# write go to the link target and the link survives.
if [ -L "$SETTINGS" ]; then
  if [ ! -e "$SETTINGS" ]; then
    echo "error: $SETTINGS is a dangling symlink; not touching it." >&2
    exit 1
  fi
  while [ -L "$SETTINGS" ]; do
    t=$(readlink "$SETTINGS")
    case "$t" in
      /*) SETTINGS="$t" ;;
      *)  SETTINGS="$(dirname "$SETTINGS")/$t" ;;
    esac
  done
fi
CREATED=0
if [ ! -e "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
  CREATED=1
fi
if ! jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
  echo "error: $SETTINGS is not a valid JSON object; not touching it." >&2
  exit 1
fi

STATE=new
if jq -e --argjson want "$WANT" '.statusLine == $want' "$SETTINGS" >/dev/null; then
  STATE=same
elif jq -e 'has("statusLine")' "$SETTINGS" >/dev/null; then
  STATE=differs
  if [ "$FORCE" -ne 1 ]; then
    echo "Existing statusLine in $SETTINGS differs:"
    jq '.statusLine' "$SETTINGS"
    echo "Re-run with --force to replace it (a backup is kept)."
    exit 3
  fi
fi

# --- Script copy ---
SCRIPT_BAK=""
if [ -e "$DEST" ] && cmp -s "$SRC" "$DEST"; then
  SCRIPT_MSG="unchanged (identical)"
else
  if [ -e "$DEST" ]; then
    SCRIPT_BAK="$DEST.bak-$TS"
    cp -p "$DEST" "$SCRIPT_BAK"
  fi
  cp "$SRC" "$DEST"
  chmod 755 "$DEST"
  SCRIPT_MSG="installed"
fi

# --- settings.json update ---
SETTINGS_BAK=""
if [ "$STATE" = same ]; then
  SETTINGS_MSG="already installed"
else
  if [ "$CREATED" -ne 1 ]; then
    SETTINGS_BAK="$SETTINGS.bak-$TS"
    cp -p "$SETTINGS" "$SETTINGS_BAK"
  fi
  TMP=$(mktemp "$SETTINGS.tmp.XXXXXX")
  trap 'rm -f "$TMP"' EXIT
  cp -p "$SETTINGS" "$TMP"
  jq --argjson want "$WANT" '.statusLine = $want' "$SETTINGS" > "$TMP"
  mv -f "$TMP" "$SETTINGS"
  trap - EXIT
  if [ "$STATE" = differs ]; then
    SETTINGS_MSG="statusLine replaced (--force)"
  else
    SETTINGS_MSG="statusLine added"
  fi
fi

# --- Summary ---
echo "Script:   $DEST ($SCRIPT_MSG)"
[ -n "$SCRIPT_BAK" ] && echo "          backup: $SCRIPT_BAK"
echo "Settings: $SETTINGS ($SETTINGS_MSG)"
[ -n "$SETTINGS_BAK" ] && echo "          backup: $SETTINGS_BAK"
echo "Command:  bash \"$DEST\""
echo
echo "Sample render:"
jq -n --arg cwd "$PWD" '{
  workspace: {current_dir: $cwd},
  model: {display_name: "Opus"},
  effort: {level: "high"},
  cost: {total_cost_usd: 0.42},
  context_window: {total_input_tokens: 42000, context_window_size: 200000,
                   used_percentage: 21}
}' | bash "$DEST"
echo
echo
echo "The status line shows on the next refresh. No restart needed."
exit 0
