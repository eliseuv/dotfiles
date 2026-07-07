#!/bin/bash

# Profile with environment variables and aliases

##########
# COLORS #
##########

# ANSI color code variables
local RESET="\e[0m"
local RED="\e[0;91m"
local BLUE="\e[0;94m"
local GREEN="\e[0;92m"
local WHITE="\e[0;97m"
local BOLD="\e[1m"
local ULINE="\e[4m"
local EXPAND_BG="\E[K"
local RED_BG="\e[0;101m${EXPAND_BG}"
local GREEN_BG="\e[0;102m${EXPAND_BG}"
local BLUE_BG="\e[0;104m${EXPAND_BG}"

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

# Append to PATH if not already there
function pathprepend {
    for ARG in "$@"; do
        if [ -d "$ARG" ] && [[ ":$PATH:" != *":$ARG:"* ]]; then
            PATH="$ARG${PATH:+":$PATH"}"
        fi
    done
}

# System binaries
pathappend /bin /usr/bin /usr/local/bin /usr/local/sbin

# Custom scripts
pathappend ~/.local/bin

# CUDA
#pathappend /opt/cuda/bin /opt/cuda/nsight_compute /opt/cuda/nsight_systems/bin

# Perl
pathappend /usr/bin/core_perl /usr/bin/site_perl /usr/bin/vendor_perl

# Ruby
pathappend ~/.local/share/gem/ruby/3.0.0/bin

# Julia
pathappend ~/.juliaup/bin/

# bob nvim
pathappend ~/.local/share/bob/nvim-bin/

# DOOM Emacs
pathappend ~/.config/emacs/bin

############
# ENV VARS #
############

# Terminal emulator
#export TERM='rxvt-unicode-256color'
#export TERM='alacritty'
#export TERMINAL='alacritty'

# Text editors
export EDITOR='nvim'
export VISUAL='emacsclient -c -a emacs'

# DOOM Emacs
export EMACSDIR='~/.config/emacs'
export DOOMDIR='~/.config/doom'

# PDF Reader
export READER='zathura'

# Bat
export BAT_THEME='Dracula'

# Web browser
export BROWSER='qutebrowser'
export BROWSERCLI='w3m'

# Set manpager
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# n^3 file manager options
export NNN_OPTS="dEox"

# Task Spooler
# Mximum number of parallel jobs
export TS_SLOTS=8

# Ada Lovelace cluster
export LOVELACE='ada-lovelace.if.ufrgs.br'
export LOVELACE_DATA="eliseuvf@$LOVELACE:/home_tmp/eliseuvf/"

#############
# GPG + SSH #
#############

# Let GPG manage SSH
unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
    export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi

# Configure pinentry to use the correct tty
export GPG_TTY=$TTY
gpg-connect-agent updatestartuptty /bye >/dev/null

# Launch GPG Agnet
gpgconf --launch gpg-agent

###########
# ALIASES #
###########

# Clear screen
alias c='clear'

# Show history
alias h='history -i'

# Changing 'ls' to 'eza'
alias l='eza --group-directories-first --icons --color=always'
alias la='eza --all --group-directories-first --icons --color=always --git'
alias ll='eza --all --long --header --group-directories-first --icons --color=always --git'
alias lt='eza --all --tree --group-directories-first --icons --ignore-glob=.git --color=always'
alias l.='eza --all | rg "^\." --git'

# Easier cd
alias ..='cd ..'
alias ~='cd ~'

# Create parent dirs as needed
alias mkdir='mkdir -p'

# Confirm before overwriting something
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Grep
alias grep='grep --color'

# stow: never fold
alias stow='stow --no-folding'

# Watch with 1s refresh
# The whitespace at the end is important as it triggers alias substitution
alias watch='watch -tc -n 1 '

# Use 'bat' instead of 'cat'
alias b='bat'

# NeoVim
alias v='nvim'

# Helix
alias hx='helix'

# Newsboat
alias nb='newsboat'

# Pulse Mixer
alias pm='pulsemixer'

# Resource monitors
alias ht='htop -d5 -sPERCENT_CPU'
#alias gt='gotop -p -r 500ms'
alias bt='btm'

# n^3 file manager
alias nn="(export VISUAL='nvim'; nnn)"

# scrot
alias scrot='scrot ~/Pictures/screenshots/%Y-%m-%d_%H:%M:%S.png'

# Weather
alias wttr='curl wttr.in/?0Fq'

# Convenience aliases

# Use rsync for copying files
alias rs='rsync -Pazvh'
alias rsmv='rsync -Pazvh --remove-source-files'

# Reset fail lock after failed authentication attempts
alias failreset='faillock --user $USER --reset'

# udiskie
alias ud-umount='udiskie-umount --detach'

# SSH agent restart (temporary)
alias ssh-restart='killall ssh-agent; eval `ssh-agent`; ssh-add'

# Disk destroyer
# I always forget the correct flags for writing the image to USB drive
# Usage: disk-destroyer if=/path/to/image.iso of=/dev/sd<?>
alias disk-destroyer='sudo dd bs=4M conv=fsync oflag=direct status=progress'

# Stage, commit and push changes with default commit message
alias git-push="git add . && git commit -m 'update' && git push"

# Connect to UFRGS VPN
alias vpn-ufrgs="sudo openvpn --config ~/.config/openvpn/vpn-ufrgs.ovpn"

#############
# FUNCTIONS #
#############

# yazi wrapper
function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

# Print csv file
function pcsv {
    sed 's/,,/, ,/g;s/,,/, ,/g' "$1" | column -s, -t | less -#2 -N -S
}

# ex - archive extractor
# usage: ex <file>
function ex {
    if [ -f $1 ]; then
        case $1 in
        *.tar.bz2) tar xjf $1 ;;
        *.tar.gz) tar xzf $1 ;;
        *.bz2) bunzip2 $1 ;;
        *.rar) unrar x $1 ;;
        *.gz) gunzip $1 ;;
        *.tar) tar xf $1 ;;
        *.tbz2) tar xjf $1 ;;
        *.tgz) tar xzf $1 ;;
        *.zip) unzip $1 ;;
        *.Z) uncompress $1 ;;
        *.7z) 7z x $1 ;;
        *) echo "'$1' cannot be extracted via ex()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# YouTube MP3
function ytmp3 {
    yt-dlp -f 'ba' -x --audio-format mp3 $1 -o '$HOME/Storage/Music/_unsorted/%(title)s.%(ext)s'
}

# Add spacing left of text
# Pipe to it to to add spacing to the beginning of outpu
# COMMAND | tab
function tab {
    while read LINE; do
        sed -e 's/^/  /' <<<"$LINE"
    done
}

# Cheat sheet
function cheat {
    curl cheat.sh/"$@" | bat
}

# Enqueue bins as jobs
binjlargs() {
    printf "\nSubmitting script %s\n\n" "$1"
    while IFS= read -r line; do
        echo "$1 $line"
        COMMAND="tsp $1 $line"
        eval "$COMMAND"
    done <<<$(julia --startup-file=no "$2")
}

#######
# fzf #
#######

# fzf ripgrep options
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'

# fzf theme
export FZF_DEFAULT_OPTS='--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9 --color=fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9 --color=info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6 --color=marker:#ff79c6,spinner:#ffb86c,header:#6272a4'

# Fuzzy search dir navigation
function fcd {
    cd "$(find ~ -not -path '*/.*' -type d | fzf --height 50% --reverse --preview 'eza -lah {}')" || return
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

# Fuzzy search music library
function fmp {
    local FORMAT="[%file%]"
    mpc listall -f $FORMAT | fzf --multi --preview 'mediainfo ~/Storage/Music/{}' | mpc add
}

########
# tmux #
########

alias t='tmux attach || tmux new-session'
alias ta='tmux attach -t'
alias tn='tmux new-session'
alias tl='tmux list-sessions'

########
# Rust #
########

# Rust Cargo
pathprepend ~/.cargo/bin

# Rust backtrace
export RUST_BACKTRACE=1

# Update Rust through Rustup
alias rust-update='rustup update --no-self-update'

# Update cargo binaries
# https://crates.io/crates/cargo-update
alias cargo-update='cargo install-update --all'

# Cargo cleanup
# https://github.com/matthiaskrgr/cargo-cache
# Removes crate source checkouts and git repo checkouts
alias cargo-cleanup='cargo cache --autoclean'
# Recompress git repos
alias cargo-gc='cargo cache --gc'

function cargocleanup {
    printf "${BLUE}Removing crate source checkouts and git repos checkouts...${RESET}\n"
    cargo-cleanup
    printf "\n${BLUE}Recompressing git repos...${RESET}\n"
    cargo-gc
}

######
# Go #
######

# Go path
export GOPATH=$HOME/go

# Go binaries
export GOBIN=$GOPATH/bin

# Go Programs
pathappend "$GOBIN"

# Update binaries obtained by 'go install'
# https://github.com/nao1215/gup
alias go-update='gup update'

function gocleanup {
    printf "${BLUE}Removing build cache...${RESET}\n"
    go clean -cache
    printf "\n${BLUE}Removing module download cache...${RESET}\n"
    go clean -modcache
}

#########
# Julia #
#########

# Julia threads
export JULIA_NUM_THREADS=auto

# Julia default editor for the @edit macro
export JULIA_EDITOR=nvim

# Julia binaries
pathappend "$HOME/.julia/juliaup/bin"

# Julia with precompiled Revise.jl and OhMyREPL
alias jl='julia --sysimage=/home/evf/.julia/config/sysimages/revise-omr_sysimage.so'

# Update Julia packages
alias julia-update='julia -e "using Pkg; Pkg.update()"'

# Julia package manager garbage collection
alias julia-cleanup='julia -e "using Pkg; Pkg.gc()"'

# Enqueue Julia scripts as jobs
jlargs() {
    printf "\nSubmitting script $1\n\n"
    while IFS= read -r line; do
        echo "Args = $line"
        COMMAND="tsp julia $1 $line"
        eval "$COMMAND"
    done <<<$(julia --startup-file=no "$2")
}

# Enqueue Julia scripts as jobs
binjlargs() {
    printf "\nSubmitting bin $1\n\n"
    while IFS= read -r line; do
        echo "$1 $line"
        COMMAND="tsp $1 $line"
        eval "$COMMAND"
    done <<<$(julia --startup-file=no "$2")
}

# Run Julia Pluto
alias pluto-start="julia --eval 'using Pluto ; Pluto.run(launch_browser=false)'"

###########
# Haskell #
###########

# Put GHCup path at the start
pathprepend "$HOME/.ghcup/bin"

# Add the -dynamic flag to every invocation of GHC
alias cabal-install='cabal install --ghc-options=-dynamic'

# GHCup env
[ -f "/home/evf/.ghcup/env" ] && source "/home/evf/.ghcup/env"

############
# Anaconda #
############

# Conda profile
[ -f "$HOME/anaconda3/etc/profile.d/conda.sh" ] && source "$HOME/anaconda3/etc/profile.d/conda.sh"

# Conda directories
export CONDA_BASE_DIR="$HOME/anaconda3/"
export CONDA_ENVS_DIR="$HOME/anaconda3/envs/"

# Activate an env (with fzf)
function condaenv {
    local ENVS_LIST=("base")
    ENVS_LIST+=$(fd -d 1 -t d . $CONDA_ENVS_DIR -x echo {/.})
    conda activate $(printf "%s\n" ${ENVS_LIST[@]} | fzf)
}

# List explicitly installed packages
alias conda-list='conda env export --from-history'

function condaupdate {
    printf "${BLUE}Updating base env...${RESET}\n\n"
    conda activate base
    conda update --all --yes
    conda deactivate
    local ENVS=$(fd -d 1 -t d . $CONDA_ENVS_DIR -x echo {/.})
    for ENV in ${ENVS[@]}; do
        printf "\n${BLUE}Updating $ENV env...${RESET}\n\n"
        conda activate $ENV
        conda upgrade --all --yes
        conda deactivate
    done
}

function condacleanup {
    printf "${BLUE}Cleaning up base env...${RESET}\n\n"
    conda activate base
    conda clean --all --yes
    conda deactivate
    local ENVS=$(fd -d 1 -t d . $CONDA_ENVS_DIR -x echo {/.})
    for ENV in ${ENVS[@]}; do
        printf "\n${BLUE}Cleaning up $ENV env...${RESET}\n\n"
        conda activate $ENV
        conda clean --all --yes
        conda deactivate
    done
}

########
# Ruby #
########

# Install Ruby Gems to ~/gems
export GEM_HOME="$HOME/gems"

# Add Ruby Gems bin to path
pathprepend "$GEM_HOME/bin"

##########
# NeoVim #
##########

# NeoVim version multiplexer
pathprepend ~/.local/share/bob/nvim-bin

# NeoVim config switcher
function nvims() {
    items=("LazyVim" "EruditeNvim" "AstroNvim" "NvChad" "default")
    config=$(printf "%s\n" "${items[@]}" | fzf --prompt=" Neovim Config  " --height=~50% --layout=reverse --border --exit-0)
    if [[ -z $config ]]; then
        echo "Nothing selected"
        return 0
    elif [[ $config == "default" ]]; then
        config=""
    fi
    NVIM_APPNAME=$config nvim "$@"
}

alias nvim-lazy="NVIM_APPNAME=LazyVim nvim"
alias nvim-erudite="NVIM_APPNAME=EruditeNvim nvim"
alias nvim-chad="NVIM_APPNAME=NvChad nvim"
alias nvim-astro="NVIM_APPNAME=AstroNvim nvim"
alias v='nvim-lazy'
alias vr='nvim-lazy -R'

# LazyVim update
alias nvim-lazy-update="nvim-lazy --headless \"+Lazy! sync\" +qa"

# Use LazyVim as default
export NVIM_APPNAME="LazyVim"

#######
# APT #
#######

# Pacman
# Fuzzy search on available packages and install
alias apts="apt search . | rg \^\\\\w\+\.\*/ | awk -F/ '{print \$1}' | fzf --multi --preview 'apt show {1}' --reverse | xargs -ro sudo apt install"
# Fuzzy search on installed packacges and remove
alias aptremove="apt list --installed | rg \^\\\\w\+\.\*/ | awk -F/ '{print \$1}' | fzf --multi --preview 'apt show {1}' --reverse | xargs -ro sudo apt remove"

# Pacman cleanup
function poposcleanup {
    printf "\n${BLUE}Removing orphaned packages...${RESET}\n\n"
    # sudo apt autoremove --purge --yes
    sudo nala autopurge
    printf "\n${BLUE}Cleaning packages and install scripts...${RESET}\n\n"
    # sudo apt clean --yes
    sudo nala clean
}

#######################
# Systemwide Commands #
#######################

# Update system
function update {
    [[ -f /tmp/update.lock ]] && exit 1
    touch /tmp/update.lock
    printf "\n${GREEN}Updating PopOS!...${RESET}\n\n"
    # sudo apt update --yes && sudo apt upgrade --yes
    sudo nala upgrade
    printf "\n${GREEN}Updating NeoVim...${RESET}\n\n"
    bob update --all
    nvim-lazy-update
    printf "\n${GREEN}Updating Rust...${RESET}\n\n"
    rust-update
    printf "\n${GREEN}Updating Cargo bins...${RESET}\n\n"
    cargo-update
    printf "\n${GREEN}Updating Go bins...${RESET}\n\n"
    go-update
    printf "\n${GREEN}Updating Julia...${RESET}\n\n"
    juliaup update
    julia-update
    printf "\n${GREEN}Updating Anaconda...${RESET}\n\n"
    condaupdate
    # printf "\n${GREEN}Updating DOOM Emacs...${RESET}\n\n"
    # doom upgrade --force
    printf "\n${GREEN}Custom check...${RESET}\n"
    customcheck
    printf "\n"
    rm -f /tmp/update.lock
}

# Cleanup
function cleanup {
    printf "\n${GREEN}PopOS! cleanup...${RESET}\n"
    poposcleanup
    printf "\n${GREEN}Cargo cleanup...${RESET}\n\n"
    cargocleanup
    printf "\n${GREEN}Go cleanup...${RESET}\n\n"
    gocleanup
    printf "\n${GREEN}Julia cleanup...${RESET}\n\n"
    julia-cleanup
    printf "\n${GREEN}Anaconda cleanup...${RESET}\n\n"
    condacleanup
    # printf "\n${GREEN}DOOM cleanup...${RESET}\n\n"
    # doom gc --force --verbose
}

function customcheck {
    printf "\n  ${GREEN}✓ ${BLUE}No custom checks${RESET}\n"

    # printf "\n${BLUE}Checking if Emacs with native compilation is available...${RESET}\n"
    # pacman -Si emacs-nativecomp
}

# Update and cleanup
alias up='update'

export PATH="$HOME/.elan/bin:$PATH"
