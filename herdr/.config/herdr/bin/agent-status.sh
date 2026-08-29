#!/bin/sh
# Agent counts for herdr's tab_bar_right.
#
# herdr resolves command entries on the server, so this never runs on a pane's
# critical path. It goes through the socket API rather than scraping panes,
# which keeps it at ~10ms.
#
# Only blocked/working/done are counted. idle and unknown are the resting
# states, and reporting them would leave the entry permanently lit -- the point
# is that an empty bar means nothing wants attention.
#
# Icons are plain Unicode rather than Nerd Font private-use glyphs. tmux.conf
# uses Codicons and Material Design here, so either would render; these survive
# a fallback font too.
BLOCKED_ICON='!'
WORKING_ICON='⋯'
DONE_ICON='✓'

# jq exits non-zero on malformed input; swallow it so a transient API hiccup
# blanks the entry instead of surfacing an error in the tab bar.
out=$(herdr agent list 2>/dev/null | jq -r \
  --arg b "$BLOCKED_ICON" --arg w "$WORKING_ICON" --arg d "$DONE_ICON" '
    ([.result.agents[]?.agent_status]
      | group_by(.)
      | map({key: .[0], value: length})
      | from_entries) as $c
    | [ (if $c.blocked then "\($b)\($c.blocked)" else empty end),
        (if $c.working then "\($w)\($c.working)" else empty end),
        (if $c.done    then "\($d)\($c.done)"    else empty end) ]
    | join(" ")
  ' 2>/dev/null) || exit 0

printf '%s\n' "$out"
