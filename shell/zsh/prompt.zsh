#!/usr/bin/env zsh
# Based off Pure <https://github.com/sindresorhus/pure>

_strlen() { echo ${#${(S%%)1//$~%([BSUbfksu]|([FB]|){*})/}}; }

# fastest possible way to check if repo is dirty
prompt_git_dirty() {
    is-callable git || return

    # disable auth prompting on git 2.3+
    GIT_TERMINAL_PROMPT=0

    # check if we're in a git repo
    [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" == "true" ]] || return
    # check if it's dirty
    command test -n "$(git status --porcelain --ignore-submodules -unormal)" || return

    echo -n "%F{red}[+]"
    local r=$(command git rev-list --right-only --count HEAD...@'{u}' 2>/dev/null)
    local l=$(command git rev-list --left-only --count HEAD...@'{u}' 2>/dev/null)

    (( ${r:-0} > 0 )) && echo -n " %F{green}${r}⇣"
    (( ${l:-0} > 0 )) && echo -n " %F{yellow}${l}⇡"
    echo -n '%f'
}

# displays the exec time of the last command if set threshold was exceeded
prompt_cmd_exec_time() {
    local stop=$EPOCHSECONDS
    local start=${cmd_timestamp:-$stop}
    integer elapsed=$stop-$start
    (($elapsed > 2)) && echo ' '$($DOTFILES/bin/since -- $elapsed)
}

## Hooks ###############################
prompt_hook_preexec() {
    cmd_timestamp=$EPOCHSECONDS
}

prompt_hook_precmd() {
    LAST=$EPOCHSECONDS
    print -Pn '\e]0;%~\a' # full path in the title
    vcs_info # get git info
    # Newline before prompt, excpet on init
    [[ -n "$_DONE" ]] && print ""; _DONE=1
}

## Initialization ######################
prompt_init() {
    zmodload zsh/datetime

    # prevent percentage showing up
    # if output doesn't end with a newline
    export PROMPT_EOL_MARK=''

    prompt_opts=(cr subst percent)

    setopt PROMPTSUBST
    autoload -Uz add-zsh-hook
    autoload -Uz vcs_info

    add-zsh-hook precmd prompt_hook_precmd
    add-zsh-hook preexec prompt_hook_preexec
    # Updates cursor shape and prompt symbol based on vim mode
    zle-keymap-select() {
        case $KEYMAP in
            vicmd)      print -n -- "\E]50;CursorShape=0\C-G";
                        PROMPT_SYMBOL=$N_MODE;
                        ;;  # block cursor
            main|viins) print -n -- "\E]50;CursorShape=1\C-G";
                        PROMPT_SYMBOL=$I_MODE;
                        ;;  # line cursor
        esac
        zle reset-prompt
        zle -R
    }
    zle-line-finish() { print -n -- "\E]50;CursorShape=0\C-G" }
    zle -N zle-keymap-select
    zle -N zle-line-finish
    zle -A zle-keymap-select zle-line-init

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' use-simple true
    zstyle ':vcs_info:*' max-exports 2
    zstyle ':vcs_info:git*' formats ':%b'
    zstyle ':vcs_info:git*' actionformats ':%b (%a)'

    # show username@host if logged in through SSH OR logged in as root
    is-ssh || is-root && prompt_username='%F{magenta}%n%F{244}@%m '

    ## Vim cursors
    if [[ -z "$SSH_CONNECTION" ]]
    then
        N_MODE="%F{green}## "
        I_MODE="%(?.%F{yellow}.%F{red})λ "
    else
        N_MODE="%F{red}### "
        I_MODE="%(?.%F{green}.%F{red})λ "
    fi

    RPROMPT='%F{cyan}${vcs_info_msg_0_}$(prompt_git_dirty)'  # Branch + dirty indicator
    RPROMPT+='%F{yellow}$(prompt_cmd_exec_time)'             # Exec time
    RPROMPT+='%f' # end

    PROMPT='$prompt_username'  # username
    PROMPT+='%F{blue}%~ %f'      # path
    PROMPT+='${PROMPT_SYMBOL:-$ }' # Prompt (red if $? == 0)
    PROMPT+='%f' #end
}

prompt_init "$@"
