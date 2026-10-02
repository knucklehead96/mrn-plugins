#!/bin/bash
# Claude Code status line: dir | model | effort | session tokens | cache hit | context | API time | cost (per 1M tokens)

input=$(cat)

# Session totals aren't in the payload: sum usage from the transcript and its subagent
# transcripts (cost.total_cost_usd covers both), one entry per message id (each reply is
# logged several times). Cached until any of these files grows or a new one appears.
session_in=null session_out=null
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')
if [ -f "$transcript" ]; then
  cache_dir="${TMPDIR:-/tmp}/claude-statusline-$(id -u)"
  cache="$cache_dir/$(basename "$transcript").tokens"
  shopt -s nullglob
  files=("$transcript" "${transcript%.jsonl}"/subagents/*.jsonl)
  size="${#files[@]}:$(wc -c -- "${files[@]}" | awk 'END { print $1 }')"
  read -r cached_size session_in session_out 2>/dev/null < "$cache"
  if [ "$cached_size" != "$size" ]; then
    # -R + fromjson? skips a half-written last line instead of failing the whole parse.
    read -r session_in session_out < <(jq -n -R -r '
      [inputs | fromjson? | select(.type == "assistant" and .message.id and .message.usage)
        | {key: .message.id, value: .message.usage}]
      | from_entries | [.[]]
      | "\(map((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)) | add // 0) \(map(.output_tokens // 0) | add // 0)"
    ' "${files[@]}")
    # Write-then-rename: Claude Code kills in-flight runs, and a half-written cache would stick.
    [ -n "$session_out" ] && mkdir -p "$cache_dir" \
      && echo "$size $session_in $session_out" > "$cache.$$" && mv -f "$cache.$$" "$cache"
  fi
fi

printf '%s' "$input" | jq -r --argjson sin "${session_in:-null}" --argjson sout "${session_out:-null}" '
  def human:
    if . >= 1000000 then "\(. / 100000 | floor / 10)M"
    elif . >= 1000 then "\(. / 1000 | round)k"
    else tostring end;

  def dur:
    (. / 1000 | floor) as $s
    | if $s >= 3600 then "\($s / 3600 | floor)h\($s % 3600 / 60 | floor)m"
      elif $s >= 60 then "\($s / 60 | floor)m\($s % 60)s"
      else "\($s)s" end;

  def left:
    (. / 60 | floor) as $m
    | if $m >= 60 then "\($m / 60 | floor)h \($m % 60)m" elif $m >= 1 then "\($m)m" else "<1m" end;

  # claude-opus-5-5 -> Opus 5.5, claude-sonnet-5[1m] -> Sonnet 5, claude-haiku-4-5-20251001 -> Haiku 4.5
  def short_model:
    (.model.id // "") | sub("^claude-"; "") | sub("\\[.*\\]$"; "") | sub("-[0-9]{8}$"; "")
    | split("-") | select(length > 1)
    | (.[0][0:1] | ascii_upcase) + .[0][1:] + " " + (.[1:] | join("."));

  # 0.4242 -> "0.42" (two decimals, no float noise)
  def usd:
    (. * 100 | round) as $c
    | "\($c / 100 | floor).\($c % 100 | tostring | if length < 2 then "0" + . else . end)";

  def color($pct):
    if $pct >= 80 then "\u001b[31m" elif $pct >= 50 then "\u001b[33m" else "\u001b[32m" end;

  .context_window as $cw
  | ($cw.current_usage // {}) as $u
  | (($u.input_tokens // 0) + ($u.cache_creation_input_tokens // 0) + ($u.cache_read_input_tokens // 0)) as $ctx_used
  | [
      "",
      (.workspace.current_dir // .cwd // empty
        | if . == env.HOME or startswith(env.HOME + "/") then "~" + .[(env.HOME | length):] else . end
        | "📁 \(.)"),
      (short_model // .model.display_name // "?"),
      (.effort.level // empty | "⚡ \(.)"),
      (select($sin != null) | "↑\($sin | human) ↓\($sout | human)"),
      (.prompt_cache as $pc
        | (($pc.hit_ratio
            // (if $ctx_used > 0 then ($u.cache_read_input_tokens // 0) / $ctx_used else null end))
           // empty) as $hit
        | ($pc.expires_at // null) as $exp
        | if $pc.warm == false or ($exp != null and $exp <= now) then "♻️ \u001b[31mcold\u001b[0m"
          else "♻️ \($hit * 100 | round)%" + (if $exp then " ·\($exp - now | left)" else "" end) end),
      ($cw | select(.context_window_size != null)
        | (.used_percentage // ($ctx_used * 100 / .context_window_size) | round) as $pct
        | (["🌑", "🌘", "🌗", "🌖", "🌕"][[$pct / 20 | floor, 4] | min]) as $moon
        | "\($moon) \($ctx_used | human)/\(.context_window_size | human) \(color($pct))\($pct)%\u001b[0m"),
      (.cost.total_api_duration_ms // empty | "⏳ \(dur)"),
      (.cost.total_cost_usd // empty
        | "💲\(usd)"
          + ((($sin // 0) + ($sout // 0)) as $tok
             | if $tok > 0 then " (\(. * 1000000 / $tok | usd)/M)" else "" end))
    ]
  | join(" | ")
'
