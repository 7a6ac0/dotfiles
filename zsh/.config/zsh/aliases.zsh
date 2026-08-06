# Better ls
alias ls='eza --icons'

# Detailed listing
alias ll='eza -lh --icons --git'

# Detailed listing including hidden files
alias la='eza -lah --icons --git'

# Tree view
alias tree='eza --tree --icons'

# Reuse ls completions for eza (avoids defining a separate completion function)
compdef eza=ls

# Better cat
alias cat='bat'

# =========================================================
# Core utilities
# =========================================================

alias grep='rg --color=auto'
alias diff='diff --color=auto'
alias df='df -h'
alias zr="source $XDG_CONFIG_HOME/zsh/.zshrc"

# =========================================================
# Editor
# =========================================================

alias vim='nvim'

# =========================================================
# git
# =========================================================

# Auto generate commit message
gac() {
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "不在 git repo 內"; return 1; }
  git diff --cached --quiet && { echo "沒有 staged 變更"; return 1; }

  local msg
  msg=$(git diff --cached | claude -p 'Read the staged git diff from stdin and write a commit message. Respond with the message only, no affirmation or explanation. Use conventional commit format: type(scope): description. Subject line under 50 characters. Types: feat, fix, docs, style, refactor, perf, test, chore, ci. Include scope when relevant (e.g. api, ui, auth).') || return 1

  [[ -n "$msg" ]] || { echo "claude 沒有回傳內容"; return 1; }

  printf '%s\n---\n' "$msg"
  read -q "?使用這個 message? [y/N] " || { echo; return 1 }
  echo
  git commit -m "$msg"
}

# =========================================================
# tmux
# =========================================================

alias ta="tmux a"

# yazi
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}
