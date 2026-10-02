#!/bin/bash
event_name=$(jq -r '.hook_event_name' 2>/dev/null <<< "$(cat)")

jq -n --arg name "$event_name" '{
  hookSpecificOutput: {
    hookEventName: $name,
    additionalContext: "Be concise. Short sentences. Lead with the result. No preamble, no narration, no closing recap. Stay on the task. Do not volunteer caveats, side findings, or suggestions unless asked or they block the task. Main thread is chat-only. Delegate agents: file reads/searches → Explore; root cause analysis → analyst; code edits → developer; builds/flash → builder; board work → tester."
  }
}'
