#!/usr/bin/env bash

if [[ -t 2 ]] || [[ ${BASHUTIL_FORCE_COLORS:+x} ]]; then
    bashutil_error() {
        builtin printf "\x1b[1m%s:%s: \x1b[;1;31merror: \x1b[;1m%s\x1b[m\n" "${BASH_SOURCE[0]}" "${BASH_LINENO[0]}" "$*" >&2
    }
else
    bashutil_error() {
        builtin printf "%s:%s: error: %s\n" "${BASH_SOURCE[0]}" "${BASH_LINENO[0]}" "$*" >&2
    }
fi

(return 0) 2> /dev/null || {
    bashutil_error "should be sourced, not executed"
    unset -f bashutil_error
    exit 1
}

bashutil_declare_logs() {
    log_debug() {
        if [[ ${DEBUG:+x} ]]; then
            if [[ -t 2 ]] || [[ ${BASHUTIL_FORCE_COLORS:+x} ]]; then
                builtin printf '\x1b[;36m%s\x1b[m\n' "$*" >&2
            else
                builtin printf '%s\n' "$*" >&2
            fi
        fi
    }

    log_info() {
        if [[ -t 2 ]] || [[ ${BASHUTIL_FORCE_COLORS:+x} ]]; then
            builtin printf '\x1b[;1m%s\x1b[m\n' "$*" >&2
        else
            builtin printf '%s\n' "$*" >&2
        fi
    }

    log_warn() {
        if [[ -t 2 ]] || [[ ${BASHUTIL_FORCE_COLORS:+x} ]]; then
            builtin printf '\x1b[;1;33m%s\x1b[m\n' "$*" >&2
        else
            builtin printf '%s\n' "$*" >&2
        fi
    }

    log_error() {
        if [[ -t 2 ]] || [[ ${BASHUTIL_FORCE_COLORS:+x} ]]; then
            builtin printf '\x1b[;1;31m%s\x1b[m\n' "$*" >&2
        else
            builtin printf '%s\n' "$*" >&2
        fi
    }

    die_with_error() {
        log_error "$@"
        exit 1
    }

    # Declaring again is no-op. This form prints noting in bash -x
    bashutil_declare_logs() {
        for x in; do :; done
    }
}

bashutil_declare_progress_bar() {
    local reinit='
        if [[ -t 2 ]]; then
            # Scrolling region smaller than 2 lines does not work...
            if IFS=" " read -r bashutil_lines bashutil_columns < <(stty size <&2 2> /dev/null) && (( bashutil_lines > 2 )); then
                printf "\x1b7\x1b[r\x1b8\v\x1b[A\x1b7\x1b[%d;H\x1b[0m\x1b[2K\x1b[?7l%s\x1b[?7h\x1b[;%dr\x1b8" ${bashutil_lines} "${bashutil_progress_bar_msg-}" $((bashutil_lines - 1)) >&2
                #       ^^^^^ Save state (cursor position, colors, origin mode)
                #            ^^^^^^ Reset scrolling region to full screen
                #                  ^^^^^ Restore state (cursor position, colors, origin mode)
                #                       ^^^^^^^^ Go down one line (with scrolling if at the bottom), then go up.
                #                               ^^^^^ Save state (cursor position, colors, origin mode)
                #                                    ^^^^^^^^^ Go to the beginning of the bottom line
                #                                             ^^^^^^^ Reset formatting (affects erasing line).
                #                                                    ^^^^^^^ Erase the bottom line
                #                                                           ^^^^^^^^ Disable line auto-wrapping.
                #  Enable back line auto-wrapping.                                    ^^^^^^^^
                #  Exclude the bottom line from scrolling region                              ^^^^^^^^^
                #  Restore state (cursor position, colors, origin mode)                                ^^^^^
            fi
        fi
    '

    # Restore progress bar on the terminal's size change
    local previous_winch_trap="$(trap -p WINCH)"
    previous_winch_trap="${previous_winch_trap#trap -- }"
    previous_winch_trap="${previous_winch_trap% SIGWINCH}"
    trap "${reinit}${previous_winch_trap:+eval }${previous_winch_trap}" WINCH
    # Reset on exit
    local previous_exit_trap="$(trap -p EXIT)"
    previous_exit_trap="${previous_exit_trap#trap -- }"
    previous_exit_trap="${previous_exit_trap% EXIT}"
    trap '
        declare -i bashutil_rc=$?
        trap - WINCH
        if [[ -t 2 ]] && (( bashutil_lines > 2 )); then
            printf "\x1b7\x1b[r\x1b[%d;H\x1b[2K\x1b8" ${bashutil_lines} >&2
            #       ^^^^^ Save state (cursor position, colors, origin mode)
            #            ^^^^^^ Reset scrolling region to full screen
            #                  ^^^^^^^^^ Go to the beginning of the bottom line
            #                           ^^^^^^^ Erase the bottom line
            #                                  ^^^^^ Restore state (cursor position, colors, origin mode)
        fi
    '"${previous_exit_trap:+"(exit \${bashutil_rc}); eval "}${previous_exit_trap}" EXIT

    function progress() {
        bashutil_progress_bar_msg="$*"
        if [[ -t 2 ]] && (( bashutil_lines > 2 )); then
            printf "\x1b7\x1b[r\x1b[%d;H\x1b[0m\x1b[2K\x1b[?7l%s\x1b[?7h\x1b[;%dr\x1b8" ${bashutil_lines} "${bashutil_progress_bar_msg-}" $((bashutil_lines - 1)) >&2
            #       ^^^^^ Save state (cursor position, colors, origin mode)
            #            ^^^^^^ Reset scrolling region to full screen
            #                  ^^^^^^^^^ Go to the beginning of the bottom line
            #                           ^^^^^^^ Reset formatting (affects erasing line).
            #                                  ^^^^^^^ Erase the bottom line
            #                                         ^^^^^^^^ Disable line auto-wrapping.
            #  Enable back line auto-wrapping.                  ^^^^^^^^
            #  Exclude the bottom line from scrolling region            ^^^^^^^^^
            #  Restore state (cursor position, colors, origin mode)              ^^^^^
        fi
    }

    # Set up the progress bar
    eval "${reinit}"

    # Declaring again is no-op. This form prints noting in bash -x
    bashutil_declare_progress_bar() {
        for x in; do :; done
    }
}

bashutil_cleanup() {
    while IFS= read -r declare_line; do
        case "${declare_line}" in
            'declare -f bashutil_'*)
                unset -f "${declare_line##* }"
                ;;
        esac
    done < <(declare -F)
}

while (( $# > 0 )); do
    case "$1" in
        --help|help)
            builtin echo "Usage: . ${BASH_SOURCE[0]} [--help | help | --features | features | [<FEATURE>...]]"
            bashutil_cleanup
            return
            ;;
        --features|features)
            while IFS= read -r declare_line; do
                case "${declare_line}" in
                    'declare -f bashutil_declare_'*)
                        builtin echo "${declare_line##* bashutil_declare_}"
                        ;;
                esac
            done < <(declare -F)
            bashutil_cleanup
            return
            ;;
        *)
            if declare -F "bashutil_declare_$1" > /dev/null; then
                "bashutil_declare_$1"
            else
                bashutil_error "unrecognized argument: $1"
                bashutil_cleanup
                return 1
            fi
            ;;
    esac
    shift
done

bashutil_cleanup
