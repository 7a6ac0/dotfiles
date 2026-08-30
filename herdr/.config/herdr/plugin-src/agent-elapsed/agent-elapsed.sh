#!/bin/sh
# Publishes the `$elapsed` sidebar token: how long each agent has been sitting
# in its current state.
#
# herdr reports agent_status but no timestamp for when it was entered, and the
# sidebar renders tokens verbatim rather than evaluating them, so the duration
# has to be measured here and re-pushed as it grows.
#
# Runs as a plugin startup command, which is herdr's only supervised long-lived
# process: the server starts it, restarts it, and collects its output into
# `herdr plugin log`. It used to be scheduled by a tab_bar_right command entry,
# which meant the sidebar silently depended on the tab bar being non-empty.
INTERVAL=5
SOURCE='agent-elapsed'

# Long enough to survive a skipped tick, short enough that a stale duration
# expires instead of lying when this stops running.
TTL_MS=20000

# Survives a server restart: an agent still in the state it was in keeps its
# original entry time, which is the honest answer. Runtime state, so it stays
# out of the dotfiles tree even though ~/.config/herdr is a symlink into it.
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/herdr"
STATE_FILE="$STATE_DIR/agent-elapsed.tsv"

# Coarse on purpose: the sidebar answers "a moment or a while?", not stopwatch
# questions, and a value that changes every second would repaint constantly.
format_elapsed() {
  seconds=$1
  if [ "$seconds" -lt 60 ]; then
    printf '%ds' "$seconds"
  elif [ "$seconds" -lt 3600 ]; then
    printf '%dm' $((seconds / 60))
  else
    printf '%dh%02dm' $((seconds / 3600)) $(((seconds % 3600) / 60))
  fi
}

mkdir -p "$STATE_DIR" 2>/dev/null

while :; do
  # jq exits non-zero on malformed input, and the API socket is not up yet on
  # the first tick after a cold start. Either way this tick is skipped rather
  # than taking the process down -- a supervised loop that exits on a transient
  # error is just an unsupervised one.
  snapshot=$(herdr agent list 2>/dev/null | jq -r \
    '.result.agents[]? | "\(.pane_id)\t\(.agent_status)"' 2>/dev/null)

  if [ -n "$snapshot" ]; then
    now=$(date +%s)
    next="$STATE_FILE.$$"
    : > "$next" 2>/dev/null || next=''

    printf '%s\n' "$snapshot" | while IFS='	' read -r pane status; do
      [ -n "$pane" ] || continue

      # Same pane still in the same state keeps its original entry time;
      # anything else -- new pane, changed state -- starts the clock now.
      since=$(awk -F'\t' -v p="$pane" -v s="$status" \
        '$1 == p && $2 == s { print $3; exit }' "$STATE_FILE" 2>/dev/null)
      case "$since" in
        ''|*[!0-9]*) since=$now ;;
      esac
      [ -n "$next" ] && printf '%s\t%s\t%s\n' "$pane" "$status" "$since" >> "$next"

      # idle and unknown get no token: how long nothing has been happening is
      # not a question the sidebar should answer. The TTL clears whatever they
      # had on the way in.
      case "$status" in
        blocked|working|done)
          herdr pane report-metadata "$pane" --source "$SOURCE" \
            --token "elapsed=$(format_elapsed $((now - since)))" \
            --ttl-ms "$TTL_MS" >/dev/null 2>&1
          ;;
      esac
    done

    [ -n "$next" ] && mv "$next" "$STATE_FILE" 2>/dev/null
  fi

  sleep "$INTERVAL"
done
