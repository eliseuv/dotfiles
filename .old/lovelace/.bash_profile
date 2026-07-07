#!/bin/bash

##########
# COLORS #
##########

# ANSI color code variables
RED="\e[0;91m"
BLUE="\e[0;94m"
EXPAND_BG="\E[K"
BLUE_BG="\e[0;104m${EXPAND_BG}"
RED_BG="\e[0;101m${EXPAND_BG}"
GREEN_BG="\e[0;102m${EXPAND_BG}"
GREEN="\e[0;92m"
WHITE="\e[0;97m"
BOLD="\e[1m"
ULINE="\e[4m"
RESET="\e[0m"

########
# PATH #
########

# Append to PATH if not already there
function pathappend {
	for ARG in "$@"; do
		if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
			PATH="${PATH:+"$PATH:"}$ARG"
		fi
	done
}

# System binaries
pathappend /bin /usr/bin /usr/local/bin /usr/local/sbin

# Custom scripts
pathappend ~/.local/bin

# Custom binaries
pathappend ~/bin

# Julia
pathappend ~/.juliaup/bin

# Lovelace utils
pathappend ~/lovelace-tools/utils

############
# ENV VARS #
############

# Terminal emulator
#export TERM='rxvt-unicode-256color'
export TERM='linux'
#export TERMINAL='alacritty'

# Text editors
export EDITOR='vim'
#export VISUAL='emacsclient -c -a emacs'
# PDF Reader
#export READER='zathura'

export HISTSIZE=2000
export HISTFILESIZE=-1

# Bat
export BAT_THEME='Dracula'

# Set manpager
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# n^3 file manager options
export NNN_OPTS="dEox"

export DATADIR="/home_tmp/eliseuvf"

###########
# ALIASES #
###########

# Clear screen
alias c='clear'

# Changing 'ls' to 'exa'
alias l='exa --group-directories-first --icons --color=always'
alias la='exa --all --group-directories-first --icons --color=always'
alias ll='exa --all --long --header --git --group-directories-first --icons --color=always'
alias lt='exa --all --tree --group-directories-first --icons --ignore-glob=.git --color=always'
alias l.='exa --all | rg "^\."'

# Easier cd
alias ..='cd ..'
alias ~='cd ~'

# Create parent dirs as needed
alias mkdir='mkdir -p'

# Confirm before overwriting something
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Use rsync for copying files
alias rs='rsync -Pazvhm'
alias rsmv='rsync -Pazvhm --remove-source-files'

# Reset fail lock after failed authentication attempts
alias failreset='faillock --user $USER --reset'

# Grep
alias grep='grep --color'

# Use 'bat' instead of 'cat'
alias b='bat'

# Default editor
alias v='vim'

# tmux
alias t='tmux attach || tmux new-session'
alias ta='tmux attach -t'
alias tn='tmux new-session'
alias tl='tmux list-sessions'

# Watch with 1s refresh
alias w='watch --color -n 1.0 '

# Resource monitors
alias bt='btop'

# stow: use stowsh
alias stow='stowsh -t ~'

# Default git push
alias git-push="git add . && git commit -m 'Lovelace update' && git push"

# n^3 file manager
alias nn="(export VISUAL='vim'; nnn-static)"

# SSH agent restart (temporary)
alias ssh-restart='killall ssh-agent; eval `ssh-agent`; ssh-add'

#############
# Functions #
#############

# Fuzzy search dir navigation
function fcd {
	cd "$(find ~ -not -path '*/.*' -type d | fzf --height 50% --reverse --preview 'exa -lah {}')" || return
}

# Fuzzy search file in dir and open
function fop {
	local filename=$(find . -type f | fzf --reverse --preview 'bat {} --color always')
	if [ -f "$filename" ]; then
		local filetype=$(xdg-mime query filetype "$filename")
		echo "Opening file " "$filename" " of type " "$filetype" " with " "$(xdg-mime query default $filetype)"
		xdg-open "$filename" &
	fi
}

# using ripgrep combined with preview
# find-in-file - usage: fif <searchTerm>
function fif {
	if [ ! "$#" -gt 0 ]; then
		echo "Need a string to search for!"
		return 1
	fi
	rg --files-with-matches --no-messages "$1" | fzf --preview "highlight -O ansi -l {} 2> /dev/null | rg --colors 'match:bg:yellow' --ignore-case --pretty --context 10 '$1' || rg --ignore-case --pretty --context 10 '$1' {}"
}

###############
# SLURM utils #
###############

source "$HOME/lovelace-tools/slurm-utils.sh"

##########
# Zoxide #
##########

eval "$(zoxide init bash)"

#########
# Julia #
#########

# Julia threads
export JULIA_NUM_THREADS=auto

# Julia default editor for the @edit macro
export JULIA_EDITOR=nvim

# Update Julia packages
alias julia-update='julia -e "using Pkg; Pkg.update()"'

# Complete Julia update
function juliaupdate {
	printf "\n${BLUE}Updating juliaup...${RESET}\n\n"
	juliaup self update
	printf "\n${BLUE}Updating Julia...${RESET}\n\n"
	juliaup update
	printf "\n${BLUE}Updating Julia environments...${RESET}\n\n"
	julia-update
}

# Julia package manager garbage collection
alias julia-cleanup='juliaup gc; julia -e "using Pkg; Pkg.gc()"'

# Complete Julia cleanup
function juliacleanup {
	printf "\n${BLUE}Cleaning juliaup...${RESET}\n\n"
	juliaup gc
	printf "\n${BLUE}Cleaning Julia environments...${RESET}\n\n"
	julia-cleanup
}

##########
# Update #
##########

function update {
	printf "\n${GREEN}Updating binaries...${RESET}\n\n"
	bin update
	juliaupdate
}

alias up='update'
