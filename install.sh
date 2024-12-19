#!/bin/bash

# Function to execute commands with necessary privileges
execute_with_privileges() {
    local command=$1
    # Check if running as root (Docker container)
    if [ "$(id -u)" -eq 0 ]; then
        $command
    else
        # Check if sudo is available
        if command -v sudo >/dev/null; then
            sudo $command
        else
            echo "sudo not available, trying to run command without sudo:"
            $command
        fi
    fi
}

# Back up users .zshrc if they have an existing file
if [ -e $HOME/.zshrc ]; then
    TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    echo "Backing up existing ~/.zshrc to ~/.zshrc.bak.${TIMESTAMP}"
    mv ~/.zshrc ~/.zshrc.bak.$TIMESTAMP
fi

echo "Installing zsh..."
execute_with_privileges "apt update"
execute_with_privileges "apt install -y zsh locales git curl"
execute_with_privileges "locale-gen en_US.UTF-8"


if [ ! -d "$HOME/.oh-my-zsh" ]; then
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git $HOME/.oh-my-zsh
else
    echo "oh-my-zsh already installed"
fi

# check to see if zsh syntax highlitghting is installed
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
else
    echo "zsh-syntax-highlighting already installed"
fi

# check to see if zsh autosuggestions is installed
if [ ! -d "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions" ]; then
    git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
else
    echo "zsh-autosuggestions already installed"
fi
 
# install fuzzy-find https://github.com/junegunn/fzf
# this tool is useful to fuzzy find command history or git branches
if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth 1 https://github.com/junegunn/fzf.git ${HOME}/.fzf
    ${HOME}/.fzf/install --all --no-bash --no-fish
else
    echo "fzf is already installed"
fi
 
# Generate a basic zshrc script with plugins enabled
# Configuration block to be added
config_block=$(cat <<'EOF'
HISTSIZE=10000
SAVEHIST=10000

# need 256 color to see autosuggestions as gray text
export TERM=xterm-256color
# set locale to en_US.utf8
export LANG=en_US.utf8
export LANGUAGE=
export LC_CTYPE=en_US.utf8
export LC_NUMERIC="en_US.utf8"
export LC_TIME="en_US.utf8"
export LC_COLLATE="en_US.utf8"
export LC_MONETARY="en_US.utf8"
export LC_MESSAGES="en_US.utf8"
export LC_PAPER="en_US.utf8"
export LC_NAME="en_US.utf8"
export LC_ADDRESS="en_US.utf8"
export LC_TELEPHONE="en_US.utf8"
export LC_MEASUREMENT="en_US.utf8"
export LC_IDENTIFICATION="en_US.utf8"
export LC_ALL=

# install oh-my-zsh : https://ohmyz.sh/
export ZSH="$HOME/.oh-my-zsh"

# plugins for zsh-autosuggestion: https://github.com/zsh-users/zsh-autosuggestions/blob/master/INSTALL.md#oh-my-zsh
# zsh-syntax-highlighting: https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#oh-my-zsh
# git and z plugins are built-in so no need to install separately
# note: zsh-syntax-highlighting should always be last see here: https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md#in-your-zshrc
plugins=(git z zsh-autosuggestions zsh-syntax-highlighting)

# Go here to see other available themes: https://github.com/ohmyzsh/ohmyzsh/wiki/themes
ZSH_THEME="robbyrussell"
source $ZSH/oh-my-zsh.sh

# %~% shows full directory path in the prompt but can use %3d etc to only show max depth of 3
PROMPT="%(?:%{$fg_bold[green]%}%~%{➜%} :%{$fg_bold[red]%}%~%{➜%} ) %{$reset_color%}"
PROMPT+=' $(git_prompt_info)'
alias ls='ls --color=auto'

# alias function since zsh shell requires "history 1" to see full history
# tip: use ctrl + r to activate fzf since it's better than traditional history
hgrep() {
    history 1 | grep "$@"
}

# searh history using the fuzzy-find (fzf) tool: https://github.com/junegunn/fzf
# use ctrl + r to activate fzf or use the fh command
function fh() {
    eval $( ([ -n "$ZSH_NAME" ] && fc -l 1 || history) | fzf +s --tac | sed 's/ *[0-9]* *//')
}
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# alias functions from https://polothy.github.io/post/2019-08-19-fzf-git-checkout/
function fzf-git-branch() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    git branch --color=always --all --sort=-committerdate |
        grep -v HEAD |
        fzf --height 50% --ansi --no-multi --preview-window right:70% \
            --preview 'git log -n 50 --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' |
        sed "s/.* //"
}

function fzf-git-checkout() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    local branch
    branch=$(fzf-git-branch)
    if [[ -z "$branch" ]]; then
        echo "No branch selected."
        return
    fi

    # If branch name starts with 'remotes/' then it is a remote branch
    if [[ "$branch" = 'remotes/'* ]]; then
        # Remove 'remotes/remote_name/' prefix to get the local branch name
        local remote_branch_name="${branch#remotes/*/}"
        git switch -c "$remote_branch_name" --track "$branch"
    else
        git switch "$branch"
    fi
}

alias gb='fzf-git-branch'
alias gco='fzf-git-checkout'

EOF
)

echo "$config_block" > "${HOME}/.zshrc"


read -p "Do you want to change your shell to zsh? (y/n): " response

if [[ "$response" =~ ^[Yy]$ ]]; then

    # Get the path to zsh
    ZSH_PATH=$(command -v zsh)

    # Change the shell to zsh for the current user
    if command -v chsh >/dev/null; then
        chsh -s "$ZSH_PATH"
        if [ $? -eq 0 ]; then
            echo "Shell successfully changed to zsh. May require a logout before it takes effect"
            exec zsh
        else
            echo "Failed to change the shell to zsh."
            exit 1
        fi
    fi

else
    echo "Shell change to zsh was not performed."
fi

