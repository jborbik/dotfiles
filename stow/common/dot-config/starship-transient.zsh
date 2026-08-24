# Transient prompt for Zsh (collapses 2-line prompt to '❯ ' after pressing Enter)
zle-line-init() {
    emulate -L zsh
    [[ $CONTEXT == start ]] || return 0

    # Align vi-mode if zsh-vi-mode is present
    if (( $+functions[zvm_zle-line-init] )) && [[ $ZVM_INIT_DONE == true ]]; then
        zvm_zle-line-init
    fi

    # Enable bracketed paste mode for safe multi-line pasting
    (( $+zle_bracketed_paste )) && print -r -n - $zle_bracketed_paste[1]

    while true; do
        zle .recursive-edit
        local -i ret=$?
        [[ $ret == 0 && $KEYS == $'\4' ]] || break
        [[ -o ignore_eof ]] || exit 0
    done

    # Disable bracketed paste mode
    (( $+zle_bracketed_paste )) && print -r -n - $zle_bracketed_paste[2]

    local saved_prompt=$PROMPT
    local saved_rprompt=$RPROMPT

    # Preserve red cursor if the previous command failed
    if [[ -n "$STARSHIP_CMD_STATUS" && "$STARSHIP_CMD_STATUS" -ne 0 ]]; then
        PROMPT="%B%F{red}❯%f%b "
    else
        PROMPT="%B%F{green}❯%f%b "
    fi
    RPROMPT=""

    zle .reset-prompt

    PROMPT=$saved_prompt
    RPROMPT=$saved_rprompt

    if (( ret )); then
        zle .send-break
    else
        zle .accept-line
    fi
    return ret
}
zle -N zle-line-init
