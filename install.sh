#!/usr/bin/env bash
#
# Reconcile this macOS machine with the dotfiles in this repository.
#
# Idempotent: safe to re-run on an already-configured machine.
#
#   ./install.sh                       open the checklist, everything pre-selected
#   ./install.sh --all                 reconcile everything, no checklist
#   ./install.sh --select zsh,tmux     reconcile just those items
#   DOTFILES_SKIP_BREW=1 ./install.sh  re-stow only, skip Homebrew
#
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=.automation/reconciliation-catalog.sh
source "$DOTFILES_DIR/.automation/reconciliation-catalog.sh"
# shellcheck source=.automation/selection-tui.sh
source "$DOTFILES_DIR/.automation/selection-tui.sh"

readonly BACKUP_ROOT="$HOME/.dotfiles-backup"

# Set on the first backup of a run; all of that run's rescues share the directory.
backup_dir=""

# What this run reconciles. Filled by resolve_selection before any work starts.
SELECTED_PACKAGES=()
SELECTED_EXTRAS=()

requested_selection="${DOTFILES_SELECT:-}"
requested_all="${DOTFILES_ALL:+1}"

log() { printf '==> %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Reconciles this machine with the dotfiles in this repository. With no options a
checklist opens with every item selected; deselect what you do not want, press
Enter, and only the items left ticked are installed and linked.

Options:
  -a, --all             Skip the checklist and reconcile every item.
  -s, --select LIST     Skip the checklist and reconcile LIST, a comma- or
                        space-separated list of item names.
  -l, --list            Print the selectable item names and exit.
  -h, --help            Show this help and exit.

Environment:
  DOTFILES_SELECT=LIST  Same as --select.
  DOTFILES_ALL=1        Same as --all.
  DOTFILES_SKIP_BREW=1  Reconcile without touching Homebrew.

Without a terminal to draw on — a redirected or piped run — the checklist is
skipped and every item is reconciled.
EOF
}

# `"${array[@]}"` on an empty array is an unbound-variable error under `set -u`
# in the bash macOS ships, so a possibly-empty selection is only ever read here.
selected_packages() {
  [[ ${#SELECTED_PACKAGES[@]} -eq 0 ]] || printf '%s\n' "${SELECTED_PACKAGES[@]}"
}

selected_extras() {
  [[ ${#SELECTED_EXTRAS[@]} -eq 0 ]] || printf '%s\n' "${SELECTED_EXTRAS[@]}"
}

list_contains() {
  local needle="$1" candidate
  shift

  for candidate in "$@"; do
    [[ "$candidate" == "$needle" ]] && return 0
  done
  return 1
}

package_selected() {
  [[ ${#SELECTED_PACKAGES[@]} -gt 0 ]] && list_contains "$1" "${SELECTED_PACKAGES[@]}"
}

extra_selected() {
  [[ ${#SELECTED_EXTRAS[@]} -gt 0 ]] && list_contains "$1" "${SELECTED_EXTRAS[@]}"
}

check_platform() {
  [[ "$(uname -s)" == "Darwin" ]] ||
    die "these dotfiles target macOS (.zprofile hardcodes /opt/homebrew)"
  command -v brew >/dev/null 2>&1 ||
    die "Homebrew not found — install it first: https://brew.sh"
}

# ---------------------------------------------------------------------------
# Selection
# ---------------------------------------------------------------------------

list_items() {
  local item
  for item in "${CATALOG_PACKAGES[@]}"; do
    printf '%s\tpackage\t%s\n' "$item" "$(catalog_package_description "$item")"
  done
  for item in "${CATALOG_EXTRAS[@]}"; do
    printf '%s\textra\t%s\n' "$item" "$(catalog_extra_description "$item")"
  done
}

select_everything() {
  log "Reconciling every item ($1)"
  SELECTED_PACKAGES=("${CATALOG_PACKAGES[@]}")
  SELECTED_EXTRAS=("${CATALOG_EXTRAS[@]}")
}

# Sorts item names into the two selection arrays, rejecting anything the
# catalog does not declare — a typo must not silently reconcile less.
record_selection() {
  local item

  SELECTED_PACKAGES=()
  SELECTED_EXTRAS=()
  for item in "$@"; do
    if list_contains "$item" "${CATALOG_PACKAGES[@]}"; then
      SELECTED_PACKAGES[${#SELECTED_PACKAGES[@]}]="$item"
    elif list_contains "$item" "${CATALOG_EXTRAS[@]}"; then
      SELECTED_EXTRAS[${#SELECTED_EXTRAS[@]}]="$item"
    else
      die "unknown item '$item' — run ./install.sh --list for the valid names"
    fi
  done
}

select_from_list() {
  local requested
  # Commas and whitespace both separate, so --select zsh,tmux and
  # --select "zsh tmux" mean the same thing.
  read -r -a requested <<< "${1//,/ }"
  [[ ${#requested[@]} -gt 0 ]] || die "--select was given an empty list"
  record_selection "${requested[@]}"
}

run_checklist() {
  local item

  TUI_ITEM_KEYS=()
  TUI_ITEM_HINTS=()
  TUI_ITEM_SECTIONS=()

  for item in "${CATALOG_PACKAGES[@]}"; do
    TUI_ITEM_KEYS[${#TUI_ITEM_KEYS[@]}]="$item"
    TUI_ITEM_HINTS[${#TUI_ITEM_HINTS[@]}]="$(catalog_package_description "$item" | tr -d '`')"
    TUI_ITEM_SECTIONS[${#TUI_ITEM_SECTIONS[@]}]="Managed packages"
  done
  for item in "${CATALOG_EXTRAS[@]}"; do
    TUI_ITEM_KEYS[${#TUI_ITEM_KEYS[@]}]="$item"
    TUI_ITEM_HINTS[${#TUI_ITEM_HINTS[@]}]="$(catalog_extra_description "$item" | tr -d '`')"
    TUI_ITEM_SECTIONS[${#TUI_ITEM_SECTIONS[@]}]="Extras"
  done

  tui_select "Reconcile this machine — pick what to install" ||
    die "cancelled — nothing on this machine was changed"

  [[ ${#TUI_SELECTED[@]} -gt 0 ]] ||
    die "nothing selected — nothing on this machine was changed"

  record_selection "${TUI_SELECTED[@]}"
}

resolve_selection() {
  if [[ -n "$requested_selection" ]]; then
    select_from_list "$requested_selection"
  elif [[ -n "$requested_all" ]]; then
    select_everything "requested"
  elif ! tui_available; then
    select_everything "no terminal to draw a checklist on"
  else
    run_checklist
  fi

  local summary
  summary="$({ selected_packages; selected_extras; } | tr '\n' ' ')"
  log "Selected: ${summary% }"
}

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -a | --all) requested_all=1 ;;
      -s | --select)
        shift
        [[ $# -gt 0 ]] || die "--select needs a list of item names"
        requested_selection="$1"
        ;;
      --select=*) requested_selection="${1#--select=}" ;;
      -l | --list)
        list_items
        exit 0
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        usage >&2
        die "unknown option '$1'"
        ;;
    esac
    shift
  done
}

# ---------------------------------------------------------------------------
# Homebrew
# ---------------------------------------------------------------------------

# Names out of "$@" that brew has not installed yet, one per line. "$1" is the
# list to check against: formula or cask.
#
# Handing brew something it already has only earns a "already installed and
# up-to-date" warning plus reinstall advice, which on a re-run buries the lines
# that matter. Filtering first keeps the output to actual work.
missing_packages() {
  local kind="$1" installed pkg
  shift

  # Newline-delimited on both ends so the match below cannot hit a substring.
  installed=$'\n'"$(brew list "--$kind" -1)"$'\n'

  for pkg in "$@"; do
    [[ "$installed" == *$'\n'"$pkg"$'\n'* ]] || printf '%s\n' "$pkg"
  done
}

install_missing() {
  local kind="$1" label="$2"
  shift 2

  local missing=() pkg
  while IFS= read -r pkg; do
    missing[${#missing[@]}]="$pkg"
  done < <(missing_packages "$kind" "$@")

  if [[ ${#missing[@]} -eq 0 ]]; then
    log "$label already installed"
    return
  fi

  log "Installing $label: ${missing[*]}"
  if [[ "$kind" == cask ]]; then
    brew install --cask "${missing[@]}"
  else
    brew install "${missing[@]}"
  fi
}

# Both keg-only formulae are :versioned_formula, so brew installs them unlinked
# — yazi's video and image previews need them on PATH.
link_keg_only() {
  local prefix pkg
  prefix="$(brew --prefix)"

  for pkg in "${CATALOG_KEG_ONLY_FORMULAE[@]}"; do
    # brew records a link as a symlink here; calling `brew link` on a keg that
    # already has one just prints "Already linked".
    [[ -L "$prefix/var/homebrew/linked/$pkg" ]] && continue

    log "Linking keg-only $pkg"
    brew link "$pkg" --force --overwrite
  done
}

# Core formulae plus whatever the selected packages depend on, each named once.
selected_formulae() {
  local pkg
  {
    printf '%s\n' "${CATALOG_CORE_FORMULAE[@]}"
    while IFS= read -r pkg; do
      catalog_package_formulae "$pkg"
    done < <(selected_packages)
  } | catalog_unique
}

install_packages() {
  if [[ -n "${DOTFILES_SKIP_BREW:-}" ]]; then
    log "DOTFILES_SKIP_BREW set — skipping Homebrew"
    return
  fi

  local formulae=() formula
  while IFS= read -r formula; do
    formulae[${#formulae[@]}]="$formula"
  done < <(selected_formulae)
  install_missing formula "formulae for the selected packages" "${formulae[@]}"

  if extra_selected yazi-previews; then
    install_missing formula "Yazi preview backends" "${CATALOG_YAZI_PREVIEW_FORMULAE[@]}"
    link_keg_only
  fi

  if extra_selected fonts; then
    install_missing cask "Nerd Fonts" "${CATALOG_FONT_CASKS[@]}"
  fi
}

# ---------------------------------------------------------------------------
# Linking
# ---------------------------------------------------------------------------

# .zshrc points compinit and HISTFILE at these; neither creates its parent.
create_xdg_dirs() {
  log "Creating XDG cache/state directories"
  mkdir -p "$HOME/.cache/zsh" "$HOME/.local/state/zsh" "$HOME/.local/bin"
}

# Every package in this repo installs to ~/.config/<package>.
config_target() { printf '%s/.config/%s' "$HOME" "$1"; }

# Where that target must point once the package is stowed.
package_source() { printf '%s/%s/.config/%s' "$DOTFILES_DIR" "$1" "$1"; }

# stow refuses to write over a real file or directory, so anything already
# sitting on a selected package's target is moved aside first. A machine with a
# hand-rolled ~/.config keeps its old config instead of blocking the install.
#
# Links this repo already owns are left alone — otherwise every re-run would
# manufacture a backup of itself and `stow --restow` would have nothing to do.
# A deselected package is never touched, backup included.
backup_conflicts() {
  local pkg target

  while IFS= read -r pkg; do
    target="$(config_target "$pkg")"

    # -e is false for a broken symlink, so -L has to be tested separately.
    [[ -e "$target" || -L "$target" ]] || continue

    # -ef compares inodes through symlinks: true only when this exact package
    # is what the target already resolves to.
    [[ "$target" -ef "$(package_source "$pkg")" ]] && continue

    if [[ -z "$backup_dir" ]]; then
      backup_dir="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
      mkdir -p "$backup_dir" || die "cannot create backup directory $backup_dir"
    fi

    log "Backing up $target -> $backup_dir/$pkg"
    mv "$target" "$backup_dir/$pkg" || die "could not move $target aside"
  done < <(selected_packages)

  if [[ -n "$backup_dir" ]]; then
    warn "existing config was moved to $backup_dir"
  fi
}

stow_packages() {
  command -v stow >/dev/null 2>&1 || die "stow not found — run without DOTFILES_SKIP_BREW"

  local pkg
  while IFS= read -r pkg; do
    log "Stowing $pkg -> \$HOME"
    if ! stow --restow --target="$HOME" --dir="$DOTFILES_DIR" "$pkg"; then
      die "stow failed for '$pkg' — move the conflicting path listed above aside, then re-run"
    fi
  done < <(selected_packages)
}

# ---------------------------------------------------------------------------
# Package-specific automated reconciliation
# ---------------------------------------------------------------------------

# zsh only auto-reads ~/.zshenv, and that file is what sets ZDOTDIR.
# Stow cannot create this hop, so it is done by hand.
link_zshenv() {
  local target="$HOME/.config/zsh/.zshenv"
  local link="$HOME/.zshenv"

  if [[ -e "$link" && ! -L "$link" ]]; then
    warn "$link is a real file, not a symlink — leaving it alone"
    warn "back it up and re-run, or add 'export ZDOTDIR=\"\$HOME/.config/zsh\"' to it manually"
    return
  fi

  if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then
    log "$link already linked"
    return
  fi

  log "Linking $link -> $target"
  ln -sfn "$target" "$link"
}

install_tpm() {
  local tpm_dir="$HOME/.config/tmux/plugins/tpm"

  if [[ -d "$tpm_dir" ]]; then
    log "TPM already present"
    return
  fi
  log "Cloning TPM into $tpm_dir"
  git clone --depth=1 "$CATALOG_TPM_REPO" "$tpm_dir"
}

# yazi's flavor is a `ya pkg` clone pinned in package.toml, not tracked source.
install_yazi_deps() {
  if ! command -v ya >/dev/null 2>&1; then
    warn "ya not found — skipping yazi flavors (install yazi, then run 'ya pkg install')"
    return
  fi
  log "Installing yazi flavors from package.toml"
  ya pkg install
}

run_package_automated_reconciliation() {
  local pkg step

  for pkg in "${CATALOG_AUTOMATED_RECONCILIATION_PACKAGES[@]}"; do
    package_selected "$pkg" || continue

    while IFS= read -r step; do
      case "$step" in
        install-tpm) install_tpm ;;
        install-yazi-flavors) install_yazi_deps ;;
        link-zshenv) link_zshenv ;;
        *) die "unknown automated reconciliation step '$step' for '$pkg'" ;;
      esac
    done < <(catalog_package_automated_steps "$pkg")
  done
}

# Only the follow-ups the selection actually earned: a run without tmux should
# not tell the user to press prefix + I.
selected_user_followups() {
  local pkg extra

  for pkg in "${CATALOG_FOLLOWUP_PACKAGES[@]}"; do
    package_selected "$pkg" && catalog_package_followups "$pkg"
  done
  for extra in "${CATALOG_EXTRAS[@]}"; do
    extra_selected "$extra" && catalog_extra_followups "$extra"
  done
  return 0
}

print_user_followups() {
  local followup followups=() number=1

  while IFS= read -r followup; do
    followups[${#followups[@]}]="$followup"
  done < <(selected_user_followups)

  if [[ ${#followups[@]} -eq 0 ]]; then
    printf '\nDone. No manual steps remain.\n\n'
    return
  fi

  printf '\nDone. Remaining manual steps:\n\n'
  for followup in "${followups[@]}"; do
    printf '  %d. %s\n' "$number" "$followup"
    number=$((number + 1))
  done
  printf '\n'
}

main() {
  parse_arguments "$@"
  check_platform
  resolve_selection
  install_packages
  create_xdg_dirs
  backup_conflicts
  stow_packages
  run_package_automated_reconciliation
  print_user_followups
}

main "$@"
