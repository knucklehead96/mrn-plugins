---
name: install-my-config
description: Update the user's Claude Code settings.json - disable spinner tips and attribution, enable the 1h prompt cache, set the output style to Concise and permission mode to auto. Use only when the user runs /install-my-config.
disable-model-invocation: true
---

# install-my-config

Merges these keys into `${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json`.
Other keys (including `permissions.allow`) are left untouched. Needs `jq`.

| Key | Value |
|---|---|
| `spinnerTipsEnabled` | `false` |
| `promptCacheTtl` | `"1h"` |
| `outputStyle` | `"Concise"` |
| `attribution.commit`, `attribution.pr` | `""` (no attribution lines) |
| `permissions.defaultMode` | `"auto"` |

## Steps

The nv-workflow hook blocks `Bash` on the main thread. Run the installer in
a `general-purpose` subagent and have it return the full output and exit code.

1. Run:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/install-my-config/scripts/install.sh"
   ```

2. Exit code 0: report the settings path, the backup path (if any), and which
   keys changed. Tell the user the new settings apply to new sessions.
3. Exit code 1: show the error. Do not edit `settings.json` by hand.
