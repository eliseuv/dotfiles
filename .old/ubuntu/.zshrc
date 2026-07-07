# Download Znap, if it's not there yet.
[[ -r ~/.znap/znap/znap.zsh ]] ||
    git clone --depth 1 -- \
        https://github.com/marlonrichert/zsh-snap.git ~/.znap/znap
source ~/.znap/znap/znap.zsh  # Start Znap

# Startup command
#neofetch

# # Theme
# znap prompt romkatv/powerlevel10k
# [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# The following lines were added by compinstall
zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _ignored _correct _approximate
zstyle ':completion:*' expand prefix suffix
zstyle ':completion:*' file-sort name
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' ignore-parents parent pwd directory
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' matcher-list '' 'm:{[:lower:]}={[:upper:]}' 'r:|[._-]=** r:|=**' 'l:|=* r:|=*'
zstyle ':completion:*' menu select=1
zstyle ':completion:*' preserve-prefix '//[^/]##/'
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*' verbose true
zstyle :compinstall filename '/home/evf/.zshrc'
# End of lines added by compinstall

# Use vi (-v) or emacs (-e) mode
bindkey -e

# ZSH Syntax Highlighting
znap source zsh-users/zsh-syntax-highlighting
ZSH_HIGHLIGHT_HIGHLIGHTERS=( main brackets )

# ZSH completions
# znap source zsh-users/zsh-completions
znap source marlonrichert/zsh-autocomplete

# ZSH Autosuggestions
znap source zsh-users/zsh-autosuggestions
export ZSH_AUTOSUGGEST_STRATEGY=(history completion)
export ZSH_AUTOSUGGEST_HISTORY_IGNORE=("cd *" "cp *" "z *")
bindkey '^ ' autosuggest-accept

# Lines configured by zsh-newuser-install
HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000000
SAVEHIST=1000000
setopt BANG_HIST
unsetopt EXTENDED_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_VERIFY
setopt autocd nomatch
unsetopt beep extendedglob notify
# End of lines configured by zsh-newuser-install

# Use Home, End and Delete keys
bindkey  "^[[H"   beginning-of-line
bindkey  "^[[F"   end-of-line
bindkey  "^[[3~"  delete-char

# fzf
source /usr/share/doc/fzf/examples/key-bindings.zsh
source /usr/share/doc/fzf/examples/completion.zsh

# Open in editor
autoload -z edit-command-line
vim-command-line () {
  local VISUAL='nvim-lazy'
  edit-command-line
}
zle -N vim-command-line
bindkey "^x^e" vim-command-line
# bindkey -s ^v "nvims\n"

# Zoxide
eval "$(zoxide init zsh)"

# Starship prompt
eval "$(starship init zsh)"

# Autocompletions
autoload -Uz compinit
fpath+=~/.zfunc
fpath+=~/.zsh/completion
compinit

# Load profile
source ~/.profile

export PATH=$PATH:/home/evf/.spicetify
