# Auto-activate Python virtual environments on cd
function control_venv_activation() {
    # Check if we are inside a directory with a venv or .venv folder
    if [[ -d "./venv" || -d "./.venv" ]]; then
        VENV_DIR=$([[ -d "./venv" ]] && echo "./venv" || echo "./.venv")

        # Only source if it is not already active
        if [[ "$VIRTUAL_ENV" != "$(pwd)/${VENV_DIR#./}" ]]; then
            source "${VENV_DIR}/bin/activate"
        fi
    else
        # Deactivate the environment if we leave the project directory
        if [[ -n "$VIRTUAL_ENV" ]]; then
            # Check if the current path is outside the active venv root
            local parent_dir=$(dirname "$VIRTUAL_ENV")
            if [[ "$PWD" != "$parent_dir"* ]]; then
                deactivate
            fi
        fi
    fi
}

# Register the function to run every time the directory changes
autoload -Uz add-zsh-hook
add-zsh-hook chpwd control_venv_activation

# Avoid starship FUNCSET WARNING
autoload -Uz add-zle-hook-widget
add-zle-hook-widget zle-keymap-select starship_zle-keymap-select
eval "$(starship init zsh)"
