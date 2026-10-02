---
name: install-statusline
description: Install the workflow Claude Code status line (dir, model, effort, session tokens, cache hit rate, context use, API time, cost) into the user's Claude config dir and settings.json. Use only when the user runs /install-statusline.
disable-model-invocation: true
---

# install-statusline

Installs a status line script into `${CLAUDE_CONFIG_DIR:-~/.claude}` and
points `statusLine` in `settings.json` at it. Needs `jq`.

## Steps

The workflow hook blocks `Bash` on the main thread. Run each installer
call in a `general-purpose` subagent. The subagent returns the full output
and the exit code. The main thread talks to the user.

1. Run the installer:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/install-statusline/scripts/install.sh"
   ```

2. Exit code 3 means `settings.json` already has a different `statusLine`.
   The installer prints the current block and changes nothing. Show that
   block to the user and ask if they want to replace it. Only with their
   explicit OK, re-run with `--force`:

   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/skills/install-statusline/scripts/install.sh" --force
   ```

   Never pass `--force` without the user's OK.

   An older install with an unquoted script path also shows as "differs"
   (exit 3); ask the user, then re-run with `--force` to update it.

3. Exit code 1 is an error (for example `jq` missing, or `settings.json` is
   not valid JSON). Show the error and the fix hint it printed. Do not edit
   `settings.json` by hand.

4. On exit code 0, report to the user:
   - the installed script path and the `settings.json` path,
   - any backup paths the installer printed (`*.bak-<YYYYmmdd-HHMMSS>`),
   - the sample rendered line,
   - that the status line shows on the next status line refresh; no restart
     is needed.

## What the status line shows

```
 | 📁 dir | model | ⚡ effort | ↑in ↓out | ♻️ cache% ·ttl | 🌗 used/size % | ⏳ api-time | 💲cost (rate/M)
```

| Segment | Meaning |
|---|---|
| `📁 dir` | Working dir (`~` for home) |
| `model` | Short model name from the model ID (for example `Opus 5.5`); falls back to the display name |
| `⚡ effort` | Reasoning effort level, when set |
| `↑in ↓out` | Session tokens. `in` = input + cache creation + cache read; `out` = output |
| `♻️ cache%` | Prompt cache hit rate. Adds `·<time>` left when the cache expiry is known. Shows red `cold` when the cache is cold or expired |
| `🌑`..`🌕 used/size %` | Context window tokens used / window size, and percent used. The moon fills in 20% steps. The percent is green below 50%, yellow below 80%, red from 80% |
| `⏳ api-time` | Total API time for the session |
| `💲cost (rate/M)` | Session cost in USD, then cost per 1M session tokens (`cost / (in + out) * 1M`). Rate hidden when tokens are 0 |

Cache hit rate: `prompt_cache.hit_ratio` when Claude Code sends it, else
from the current context usage:

```
cache_read / (input + cache_creation + cache_read)
```

The session token totals come from the main session transcript plus its
`<session>/subagents/*.jsonl` transcripts (so they match the cost),
deduplicated by message ID. They are cached in
`${TMPDIR:-/tmp}/claude-statusline-<uid>/` until any of these files grows.
