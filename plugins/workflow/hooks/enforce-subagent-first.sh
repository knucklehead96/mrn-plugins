#!/bin/bash
# nv-workflow: subagent-first enforcement. The main thread is chat-only.
# Denies file, search, shell and MCP tools on the MAIN thread; allows
# everything inside a subagent.
# Discriminator: the hook payload carries .agent_id only inside a subagent.

command -v jq >/dev/null 2>&1 || exit 0   # jq missing: fail open, never deadlock

INPUT=$(cat)
AGENT_ID=$(echo "$INPUT" | jq -r '.agent_id // empty')
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Task-control tools stay allowed on the main thread (also covers legacy
# aliases in case a matcher still catches them).
case "$TOOL" in
  TaskStop|KillShell|KillBash|ListAgents) exit 0 ;;
esac

# Nested-spawn block: a subagent calling Agent again would spawn a
# subagent-of-a-subagent. The main thread calling Agent is normal delegation.
if [ "$TOOL" = "Agent" ]; then
  if [ -n "$AGENT_ID" ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"nv-workflow: no nested subagents. Do this work yourself with your own tools instead of spawning a helper."}}\n'
  fi
  exit 0
fi

[ -n "$AGENT_ID" ] && exit 0   # inside a subagent — allow

TARGET=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')

# Allowlist: config the main thread may read directly.
case "$TARGET" in
  "$HOME"/.claude/*|*/SKILL.md|*/lessons.md|*/CLAUDE.md)
    exit 0 ;;
esac

jq -n --arg t "$TOOL" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:("nv-workflow: main thread is chat-only. Delegate this " + $t + ": file reads/searches → explore; root cause analysis → analyst; code review → reviewer; code edits and builds → developer; test runs → tester; anything else → general-purpose.")}}'
exit 0
