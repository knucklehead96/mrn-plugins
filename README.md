# mrn-plugins

A Claude Code plugin marketplace.

## Install

```
/plugin marketplace add knucklehead96/mrn-plugins
/plugin install workflow@mrn-plugins
```

## Plugins

### workflow

Subagent-first developer workflow: the main thread chats and delegates, and
subagents do the work.

**Skills** (on-demand, run by typing the command)

| Command | What it does |
|---|---|
| `/workflow:commit` | Commits changes as `<module>: <topic>` (50 chars max), a blank line, then a 2-line body (70 chars per line). No co-author or attribution lines. |
| `/workflow:install-statusline` | Installs a status line: dir, model, effort, session tokens, cache hit rate, context use, API time, cost and cost per 1M tokens. |
| `/workflow:install-my-config` | Merges preferred settings into `settings.json`: spinner tips off, 1h prompt cache, Concise output style, attribution off, permission mode `auto`. |

The install skills back up `settings.json` before changing it. They need `jq`.

**Agents**

| Agent | Model | Effort | Access |
|---|---|---|---|
| `developer` | claude-opus-5-5 | high | read/write |
| `reviewer` | claude-opus-5-5 | xhigh | read-only |
| `analyst` | claude-opus-5-5 | xhigh | read-only |
| `tester` | claude-sonnet-5-5 | medium | read/write |
| `explore` | claude-haiku-4-5-20251001 | low | read-only |
| `general-purpose` | claude-sonnet-5-5 | low | all tools |

**Hooks** (need `jq`)

- `enforce-subagent-first.sh` (`PreToolUse`): denies file, search, shell and MCP
  tools on the main thread. Subagents are unrestricted and cannot spawn further
  subagents.
- `brevity.sh` (`SessionStart`, `SubagentStart`): injects a concise-output and
  delegation reminder.

## Layout

```
.claude-plugin/marketplace.json   marketplace manifest
plugins/workflow/
  .claude-plugin/plugin.json
  agents/  hooks/  skills/
```

## Adding a plugin

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json`.
2. Add an entry to `.claude-plugin/marketplace.json`:
   `{ "name": "<name>", "source": "./plugins/<name>", "description": "..." }`
3. Run `claude plugin validate .`
4. Any later change under `plugins/<name>/` must bump `version` in its
   `plugin.json` in the same commit; installs are cached by version.
