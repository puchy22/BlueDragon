
# Set zinit installation and plugins home
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"

# Download zinit if is not installed yet
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"

# Activate zinit
source "${ZINIT_HOME}/zinit.zsh"

# Initialize oh-my-posh theme
eval "$(oh-my-posh init zsh)"

# Set the theme
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/kushal.omp.json)"

# Add in zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# Add OhMyZshell plugins
zinit snippet OMZP::git
zinit snippet OMZP::sudo
zinit snippet OMZP::archlinux
zinit snippet OMZP::aws
zinit snippet OMZP::command-not-found

# Load completions
autoload -Uz compinit && compinit

# Keybindings
bindkey -e
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# Completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'	# Make auto completions not case sensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# Custom aliases

## Commons
alias ls='lsd -l'
alias la='ls -a'
alias nv='nvim'
alias cat='bat'
alias top='htop'
alias tree='broot'

## Git Aliases
alias gs='git status'
alias gcm='git commit -m'
alias gca='git commit -am'
alias gps='git push'
alias gpl='git pull'

# Fast-Fetch in open terminal
fastfetch -l "small" --logo-color-1 blue --logo-color-2 blue --logo-color-3 blue --color blue

# Add fzf shell integration
eval "$(fzf --zsh)"

source /home/puchy/.config/broot/launcher/bash/br

eval "$(zoxide init --cmd cd zsh)"


# Created by `pipx` on 2024-10-05 17:35:11
export PATH="$PATH:/home/puchy/.local/bin"
