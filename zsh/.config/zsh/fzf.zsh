# =========================================================
# fzf
# =========================================================
source <(fzf --zsh)

export FZF_DEFAULT_COMMAND='fd --hidden --strip-cwd-prefix --exclude .git'  # strip-cwd-prefix removes the leading ./ from results

# Ctrl-T uses fd
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND --type f"

# Alt-C
export FZF_ALT_C_COMMAND="$FZF_DEFAULT_COMMAND --type=d"

# UI
export FZF_DEFAULT_OPTS='
  --height=50%
  --layout=default
  --border
  --color=hl:#2dd4bf
'

export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=plain,numbers --line-range=:500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --icons=always --tree --color=always {} | head -200'"

# fzf preview for tmux
export FZF_TMUX_OPTS=" -p90%,70% "