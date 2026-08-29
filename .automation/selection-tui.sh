#!/usr/bin/env bash
# A dependency-free checklist for choosing what a reconciliation run installs.
#
# The installer is the thing that puts stow, fzf and gum on the machine, so the
# picker it opens first cannot depend on any of them. Everything here is bash
# 3.2 and ANSI escapes — the bash macOS ships.
#
# Usage: fill the TUI_ITEM_* arrays (parallel by index), call tui_select, then
# read the kept keys back out of TUI_SELECTED.

TUI_ITEM_KEYS=()
TUI_ITEM_LABELS=()
TUI_ITEM_HINTS=()
TUI_ITEM_SECTIONS=()

TUI_SELECTED=()

# Both ends of the controlling terminal. The checklist reads and draws there
# rather than on stdin/stdout so it survives `curl … | bash`, where stdin is
# the script itself.
readonly TUI_FD_IN=3
readonly TUI_FD_OUT=4

tui_checked=()
tui_cursor=0
tui_width=80
tui_drawn_lines=0
tui_saved_stty=""
tui_cancelled=0

# A checklist needs a terminal to draw on and one to read keys from. Without
# both — a redirected run, a CI job, a pipe on both ends — the caller falls
# back to reconciling everything.
tui_available() {
  [[ -t 1 ]] || return 1
  [[ -r /dev/tty && -w /dev/tty ]] || return 1
  command -v stty >/dev/null 2>&1
}

tui_load_colours() {
  TUI_BOLD='' TUI_DIM='' TUI_ACCENT='' TUI_RESET=''

  [[ -z "${NO_COLOR:-}" ]] || return 0
  command -v tput >/dev/null 2>&1 || return 0
  [[ "$(tput colors 2>/dev/null || printf 0)" -ge 8 ]] || return 0

  TUI_BOLD="$(tput bold)"
  TUI_DIM="$(tput dim)"
  TUI_ACCENT="$(tput setaf 4)"
  TUI_RESET="$(tput sgr0)"
}

# Cached for the duration of one redraw: `tput` is a fork, and a redraw draws
# twenty-odd lines.
tui_measure_terminal() {
  tui_width="$(tput cols 2>/dev/null || printf 80)"
  [[ "$tui_width" -gt 40 ]] || tui_width=80
}

tui_open_terminal() {
  eval "exec $TUI_FD_IN</dev/tty $TUI_FD_OUT>/dev/tty"
  tui_saved_stty="$(stty -g <&$TUI_FD_IN)"
  # Raw enough to get a keypress at a time without echoing it back.
  stty -echo -icanon min 1 time 0 <&$TUI_FD_IN
  printf '\033[?25l' >&$TUI_FD_OUT
}

tui_close_terminal() {
  [[ -n "$tui_saved_stty" ]] || return 0
  printf '\033[?25h' >&$TUI_FD_OUT
  stty "$tui_saved_stty" <&$TUI_FD_IN
  tui_saved_stty=""
  eval "exec $TUI_FD_IN<&- $TUI_FD_OUT>&-"
}

# One redraw overwrites the previous one in place, so nothing may wrap: a
# wrapped line desynchronises the cursor-up count and leaves debris on screen.
# Callers clip their own text — measuring here would have to discount the
# colour escapes, which are bytes the terminal never shows.
tui_line() {
  printf '\033[2K%s\n' "$1" >&$TUI_FD_OUT
  tui_drawn_lines=$((tui_drawn_lines + 1))
}

tui_count_selected() {
  local index count=0
  for index in "${!TUI_ITEM_KEYS[@]}"; do
    [[ "${tui_checked[$index]}" == 1 ]] && count=$((count + 1))
  done
  printf '%s' "$count"
}

tui_render() {
  local index section="" pointer box hint label_width=0 hint_width

  tui_measure_terminal
  for index in "${!TUI_ITEM_KEYS[@]}"; do
    [[ ${#TUI_ITEM_KEYS[$index]} -gt $label_width ]] && label_width=${#TUI_ITEM_KEYS[$index]}
  done
  # Two indent, pointer, box, the label column, and the gaps between them.
  hint_width=$((tui_width - label_width - 10))

  [[ "$tui_drawn_lines" -gt 0 ]] && printf '\033[%dA' "$tui_drawn_lines" >&$TUI_FD_OUT
  tui_drawn_lines=0

  tui_line ""
  tui_line "  ${TUI_BOLD}${TUI_ITEM_TITLE}${TUI_RESET}"
  tui_line "  ${TUI_DIM}↑/↓ move · space toggle · a all · n none · enter confirm · q cancel${TUI_RESET}"

  for index in "${!TUI_ITEM_KEYS[@]}"; do
    if [[ "${TUI_ITEM_SECTIONS[$index]}" != "$section" ]]; then
      section="${TUI_ITEM_SECTIONS[$index]}"
      tui_line ""
      tui_line "  ${TUI_BOLD}${section}${TUI_RESET}"
    fi

    if [[ "$index" -eq "$tui_cursor" ]]; then
      pointer="${TUI_ACCENT}❯${TUI_RESET}"
    else
      pointer=" "
    fi
    if [[ "${tui_checked[$index]}" == 1 ]]; then
      box="${TUI_ACCENT}[x]${TUI_RESET}"
    else
      box="[ ]"
    fi

    hint="${TUI_ITEM_HINTS[$index]}"
    [[ ${#hint} -le $hint_width ]] || hint="${hint:0:$((hint_width - 1))}…"

    tui_line "$(printf '  %s %s %-*s  %s%s%s' \
      "$pointer" "$box" "$label_width" "${TUI_ITEM_KEYS[$index]}" \
      "$TUI_DIM" "$hint" "$TUI_RESET")"
  done

  tui_line ""
  tui_line "  ${TUI_DIM}$(tui_count_selected) of ${#TUI_ITEM_KEYS[@]} selected${TUI_RESET}"
}

tui_move() {
  local last=$((${#TUI_ITEM_KEYS[@]} - 1))
  tui_cursor=$((tui_cursor + $1))
  [[ "$tui_cursor" -lt 0 ]] && tui_cursor="$last"
  [[ "$tui_cursor" -gt "$last" ]] && tui_cursor=0
  return 0
}

tui_set_all() {
  local index
  for index in "${!TUI_ITEM_KEYS[@]}"; do
    tui_checked[$index]="$1"
  done
}

tui_read_key() {
  local key rest=""

  IFS= read -rsn1 key <&$TUI_FD_IN || return 1

  # Arrows arrive as ESC [ A. bash 3.2 cannot wait a fraction of a second, so
  # telling a lone Esc from an arrow costs a full second of patience — `q` is
  # advertised as the cancel key for that reason.
  if [[ "$key" == $'\033' ]]; then
    read -rsn2 -t 1 rest <&$TUI_FD_IN || true
    case "$rest" in
      '[A') printf 'up' ;;
      '[B') printf 'down' ;;
      '') printf 'cancel' ;;
      *) printf 'ignore' ;;
    esac
    return 0
  fi

  case "$key" in
    '') printf 'confirm' ;;
    ' ') printf 'toggle' ;;
    k | K) printf 'up' ;;
    j | J) printf 'down' ;;
    a | A) printf 'all' ;;
    n | N) printf 'none' ;;
    q | Q) printf 'cancel' ;;
    *) printf 'ignore' ;;
  esac
}

# Runs the checklist with every item pre-selected. Fills TUI_SELECTED and
# returns 1 if the user backed out.
tui_select() {
  TUI_ITEM_TITLE="$1"
  TUI_SELECTED=()
  tui_cursor=0
  tui_drawn_lines=0
  tui_cancelled=0

  tui_load_colours
  tui_set_all 1

  tui_open_terminal
  # A Ctrl-C mid-checklist must put the terminal back before it goes: echo off
  # and a hidden cursor outlive the script otherwise.
  trap 'tui_close_terminal' EXIT
  trap 'tui_close_terminal; exit 130' INT TERM

  local action
  while :; do
    tui_render
    action="$(tui_read_key)"
    case "$action" in
      up) tui_move -1 ;;
      down) tui_move 1 ;;
      toggle)
        if [[ "${tui_checked[$tui_cursor]}" == 1 ]]; then
          tui_checked[$tui_cursor]=0
        else
          tui_checked[$tui_cursor]=1
        fi
        ;;
      all) tui_set_all 1 ;;
      none) tui_set_all 0 ;;
      confirm) break ;;
      cancel)
        tui_cancelled=1
        break
        ;;
    esac
  done

  tui_render
  tui_close_terminal
  trap - EXIT INT TERM

  [[ "$tui_cancelled" -eq 0 ]] || return 1

  local index
  for index in "${!TUI_ITEM_KEYS[@]}"; do
    [[ "${tui_checked[$index]}" == 1 ]] && TUI_SELECTED[${#TUI_SELECTED[@]}]="${TUI_ITEM_KEYS[$index]}"
  done
  return 0
}
