#!/usr/bin/env bash
# Regenerate README blocks that present reconciliation-catalog facts.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$ROOT_DIR/README.md"

# shellcheck source=reconciliation-catalog.sh
source "$ROOT_DIR/.automation/reconciliation-catalog.sh"

usage() {
  printf 'usage: %s [--check]\n' "${0##*/}" >&2
  exit 2
}

render_packages() {
  local pkg
  printf '| Package | Stow target | Contents |\n| --- | --- | --- |\n'
  for pkg in "${CATALOG_PACKAGES[@]}"; do
    printf '| `%s/` | `~/.config/%s/` | %s |\n' \
      "$pkg" "$pkg" "$(catalog_package_description "$pkg")"
  done
}

render_extras() {
  local extra
  printf '| Item | Contents |\n| --- | --- |\n'
  for extra in "${CATALOG_EXTRAS[@]}"; do
    printf '| `%s` | %s |\n' "$extra" "$(catalog_extra_description "$extra")"
  done
}

# The selectable items that pull a formula in, as a comma-separated cell.
formula_sources() {
  local formula="$1" pkg sources=""

  if printf '%s\n' "${CATALOG_CORE_FORMULAE[@]}" | grep -Fqx "$formula"; then
    printf 'always'
    return
  fi
  for pkg in "${CATALOG_PACKAGES[@]}"; do
    catalog_package_formulae "$pkg" | grep -Fqx "$formula" || continue
    sources="${sources:+$sources, }\`$pkg\`"
  done
  printf '%s' "$sources"
}

render_required_formulae() {
  local formula
  printf '```sh\nbrew install'
  while IFS= read -r formula; do
    printf ' %s' "$formula"
  done < <(catalog_all_required_formulae)
  printf '\n```\n\n| Package | Why it is needed | Selected with |\n| --- | --- | --- |\n'
  while IFS= read -r formula; do
    printf '| `%s` | %s | %s |\n' \
      "$formula" "$(catalog_formula_description "$formula")" "$(formula_sources "$formula")"
  done < <(catalog_all_required_formulae)
}

render_yazi_preview_formulae() {
  local formula
  printf '```sh\nbrew install'
  for formula in "${CATALOG_YAZI_PREVIEW_FORMULAE[@]}"; do
    printf ' %s' "$formula"
  done
  printf '\nbrew link'
  for formula in "${CATALOG_KEG_ONLY_FORMULAE[@]}"; do
    printf ' %s' "$formula"
  done
  printf ' --force --overwrite\n```\n'
}

render_font_casks() {
  local cask
  printf '```sh\nbrew install --cask'
  for cask in "${CATALOG_FONT_CASKS[@]}"; do
    printf ' %s' "$cask"
  done
  printf '\n```\n'
}

render_followups() {
  local followup number=1
  while IFS= read -r followup; do
    printf '%d. %s\n' "$number" "$followup"
    number=$((number + 1))
  done < <(catalog_user_followups)
}

render_manual_equivalent() {
  local pkg
  printf '%s\n' '```sh' 'cd ~/dotfiles' '' \
    '# 0. Move any pre-existing config out of the way — stow will not overwrite it.' \
    'mkdir -p ~/.dotfiles-backup/manual'
  printf 'for pkg in'
  for pkg in "${CATALOG_PACKAGES[@]}"; do
    printf ' %s' "$pkg"
  done
  printf '; do\n'
  printf '  # -e is false for a broken symlink, hence the second test.\n'
  printf '  if [ -e ~/.config/"$pkg" ] || [ -L ~/.config/"$pkg" ]; then\n'
  printf '    mv ~/.config/"$pkg" ~/.dotfiles-backup/manual/"$pkg"\n'
  printf '  fi\n'
  printf 'done\n\n'
  printf '# 1. Symlink the packages into $HOME.\n'
  printf 'stow --restow --target="$HOME"'
  for pkg in "${CATALOG_PACKAGES[@]}"; do
    printf ' %s' "$pkg"
  done
  printf '\n\n'
  printf '%s\n' \
    '# 2. Bootstrap ~/.zshenv. Stow will NOT do this — see below.' \
    'ln -sfn "$HOME/.config/zsh/.zshenv" "$HOME/.zshenv"' '' \
    '# 3. Create the cache/state directories the configs write into.' \
    'mkdir -p ~/.cache/zsh ~/.local/state/zsh ~/.local/bin' '' \
    '# 4. Install the tmux plugin manager.'
  printf 'git clone --depth=1 %s ~/.config/tmux/plugins/tpm\n\n' "$CATALOG_TPM_REPO"
  printf '%s\n' \
    '# 5. Fetch the yazi flavors pinned in yazi/.config/yazi/package.toml.' \
    'ya pkg install' \
    '```'
}

render_machine_local_state() {
  local path description
  while IFS=$'\t' read -r path description; do
    printf '%s\n' "- **\`$path\`** — $description"
  done < <(catalog_machine_local_state)
}

render_block() {
  case "$1" in
    packages) render_packages ;;
    extras) render_extras ;;
    required-formulae) render_required_formulae ;;
    yazi-preview-formulae) render_yazi_preview_formulae ;;
    font-casks) render_font_casks ;;
    followups) render_followups ;;
    manual-equivalent) render_manual_equivalent ;;
    machine-local-state) render_machine_local_state ;;
    *) printf 'unknown README block: %s\n' "$1" >&2; exit 2 ;;
  esac
}

replace_block() {
  local source="$1" destination="$2" block="$3" replacement
  replacement="$(mktemp "${TMPDIR:-/tmp}/dotfiles-readme.XXXXXX")"
  render_block "$block" > "$replacement"
  awk -v start="<!-- catalog:${block}:start -->" \
      -v end="<!-- catalog:${block}:end -->" \
      -v replacement="$replacement" '
    $0 == start {
      if (seen_start++) exit 2
      print
      while ((getline line < replacement) > 0) print line
      close(replacement)
      in_block = 1
      next
    }
    $0 == end {
      if (!in_block || seen_end++) exit 2
      in_block = 0
    }
    !in_block { print }
    END { if (seen_start != 1 || seen_end != 1 || in_block) exit 2 }
  ' "$source" > "$destination"
  rm -f "$replacement"
}

generate() {
  local source="$README" destination="$1" block intermediate
  for block in packages extras required-formulae yazi-preview-formulae font-casks followups manual-equivalent machine-local-state; do
    intermediate="$(mktemp "${TMPDIR:-/tmp}/dotfiles-readme.XXXXXX")"
    replace_block "$source" "$intermediate" "$block"
    if [[ "$source" != "$README" ]]; then
      rm -f "$source"
    fi
    source="$intermediate"
  done
  mv "$source" "$destination"
}

case "${1:-}" in
  '')
    generated="$(mktemp "${TMPDIR:-/tmp}/dotfiles-readme.XXXXXX")"
    generate "$generated"
    mv "$generated" "$README"
    ;;
  --check)
    generated="$(mktemp "${TMPDIR:-/tmp}/dotfiles-readme.XXXXXX")"
    trap 'rm -f "$generated"' EXIT
    generate "$generated"
    if ! cmp -s "$README" "$generated"; then
      printf 'README.md is out of date; run .automation/render-readme.sh\n' >&2
      diff -u "$README" "$generated" || true
      exit 1
    fi
    ;;
  *) usage ;;
esac
