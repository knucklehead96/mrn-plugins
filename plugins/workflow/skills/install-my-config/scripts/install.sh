#!/bin/bash
# Merges the user's preferred Claude Code settings into settings.json.
# Exit codes: 0 ok (or already set), 1 error.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required but not installed." >&2
  echo "  Debian/Ubuntu: sudo apt-get install jq" >&2
  echo "  macOS:         brew install jq" >&2
  exit 1
fi

DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$DIR"
SETTINGS="$DIR/settings.json"
TS=$(date +%Y%m%d-%H%M%S)
WANT='{"spinnerTipsEnabled": false, "promptCacheTtl": "1h", "outputStyle": "Concise", "attribution": {"commit": "", "pr": ""}, "permissions": {"defaultMode": "auto"}}'

# Resolve symlinks so the link survives the write.
while [ -L "$SETTINGS" ]; do
  t=$(readlink "$SETTINGS")
  case "$t" in
    /*) SETTINGS="$t" ;;
    *)  SETTINGS="$(dirname "$SETTINGS")/$t" ;;
  esac
done

CREATED=0
if [ ! -e "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
  CREATED=1
fi
if ! jq -e 'type == "object"' "$SETTINGS" >/dev/null 2>&1; then
  echo "error: $SETTINGS is not a valid JSON object; not touching it." >&2
  exit 1
fi

# Deep merge (*) so sibling keys such as permissions.allow survive.
CHANGED=$(jq -r --argjson want "$WANT" \
  '. as $cur | ($cur * $want) as $new | [$want | keys[] | select($new[.] != $cur[.])] | join(", ")' "$SETTINGS")

if [ -z "$CHANGED" ]; then
  echo "Settings: $SETTINGS (already up to date)"
  exit 0
fi

BAK=""
if [ "$CREATED" -ne 1 ]; then
  BAK="$SETTINGS.bak-$TS"
  cp -p "$SETTINGS" "$BAK"
fi
TMP=$(mktemp "$SETTINGS.tmp.XXXXXX")
trap 'rm -f "$TMP"' EXIT
cp -p "$SETTINGS" "$TMP"
jq --argjson want "$WANT" '. * $want' "$SETTINGS" > "$TMP"
mv -f "$TMP" "$SETTINGS"
trap - EXIT

echo "Settings: $SETTINGS (updated: $CHANGED)"
[ -n "$BAK" ] && echo "          backup: $BAK"
echo "Applies to new sessions."
exit 0
