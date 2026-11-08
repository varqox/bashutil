#!/usr/bin/env bash
# This should work since Bash 3.2

(return 0) 2> /dev/null || {
    if [[ ${BASHUTIL_FORCE_COLORS:+x} ]] || { [[ -t 2 ]] && [[ -z ${NO_COLOR:+x} ]] && [[ "${TERM:-dumb}" != dumb ]]; }; then
        builtin printf "\x1b[0;1;31merror: \x1b[0;1m%s should be sourced, not executed\x1b[0m\n" "${BASH_SOURCE[0]}" >&2
    else
        builtin printf "error: %s should be sourced, not executed\n" "${BASH_SOURCE[0]}" >&2
    fi
    exit 1
}

_bashutil_add_trap_for() {
    local previous_trap new_trap
    previous_trap="$(builtin trap -p "${1:?missing signal name}")" || return
    previous_trap="${previous_trap#trap -- }"
    previous_trap="${previous_trap% *}" # Trim the signal name
    case "${previous_trap}" in
        ''|"''"|'""') # Empty or ignored signal is fully replaced.
            builtin trap -- "${2:?missing trap handler} || :" "${1}"
            ;;
        *)
            # We execute handler as if condition so that it works under `set -e` and does not terminate the program.
            # Previous handler is executed in both branches, inheriting the original $? result while running with `set -e`
            # effectiveness preserved.
            builtin printf -v new_trap "builtin trap -- 'if { '%q'; }; then { '%s'; } else { '%s'; } fi' %s" "${2:?missing trap handler}" "${previous_trap}" "${previous_trap}" "${1}"
            builtin eval "${new_trap}"
            ;;
    esac
}

_bashutil_main() {
    local arg declare_line rc
    # Validate first
    for arg in "$@"; do
        case "${arg}" in
            --help|help)
                builtin printf '%s\n' "Usage: . ${BASH_SOURCE[0]} [--help | help | --features | features | [<FEATURE>...]]"
                unset -f _bashutil_add_trap_for _bashutil_main
                return 0
                ;;
            --features|features)
                while IFS= read -r declare_line; do
                    case "${declare_line}" in
                        'declare -f _bashutil_declare_'*)
                            builtin printf '%s\n' "${declare_line##* _bashutil_declare_}"
                            ;;
                    esac
                done < <(declare -F)
                unset -f _bashutil_add_trap_for _bashutil_main
                return 0
                ;;
            *)
                if ! declare -F "_bashutil_declare_${arg}" > /dev/null; then
                    if [[ ${BASHUTIL_FORCE_COLORS:+x} ]] || { [[ -t 2 ]] && [[ -z ${NO_COLOR:+x} ]] && [[ "${TERM:-dumb}" != dumb ]]; }; then
                        builtin printf "\x1b[0;2;31m%s\x1b[0;1;31merror: \x1b[0;1munrecognized argument: %s\x1b[0m\n" "${BASH_SOURCE[2]:+[${BASH_SOURCE[2]}:${BASH_LINENO[1]}] }" "${arg}" >&2 || :
                    else
                        builtin printf "%serror: unrecognized argument: %s\n" "${BASH_SOURCE[2]:+[${BASH_SOURCE[2]}:${BASH_LINENO[1]}] }" "${arg}" >&2 || :
                    fi
                    unset -f _bashutil_add_trap_for _bashutil_main
                    return 1
                fi
                ;;
        esac
    done
    # Process declarations
    for arg in "$@"; do
        "_bashutil_declare_${arg}" || {
            rc=$?;
            unset -f _bashutil_add_trap_for _bashutil_main
            return $rc
        }
    done
    unset -f _bashutil_add_trap_for _bashutil_main
}

if [[ -z ${_bashutil_loaded+x} ]]; then
    readonly _bashutil_loaded=''

    _bashutil_declare_log() {
        log() {
            local IFS=' ' # for spacing "$*" with spaces
            case "${1-}" in
                debug)
                    if [[ ${BASHUTIL_DEBUG:+x} ]]; then
                        if [[ ${BASHUTIL_FORCE_COLORS:+x} ]] || { [[ -t 2 ]] && [[ -z ${NO_COLOR:+x} ]] && [[ "${TERM:-dumb}" != dumb ]]; }; then
                            builtin printf '\x1b[0;2;36m%s\x1b[0;36m%s\x1b[0m\n' "${BASH_SOURCE[1]:+[${BASH_SOURCE[1]}:${BASH_LINENO[0]}] }" "${*:2}" >&2
                        else
                            builtin printf '%s%s\n' "${BASH_SOURCE[1]:+[${BASH_SOURCE[1]}:${BASH_LINENO[0]}] }" "${*:2}" >&2
                        fi
                    fi
                    ;;
                info)
                    if [[ ${BASHUTIL_FORCE_COLORS:+x} ]] || { [[ -t 2 ]] && [[ -z ${NO_COLOR:+x} ]] && [[ "${TERM:-dumb}" != dumb ]]; }; then
                        builtin printf '\x1b[0;1m%s\x1b[0m\n' "${*:2}" >&2
                    else
                        builtin printf '%s\n' "${*:2}" >&2
                    fi
                    ;;
                warn)
                    if [[ ${BASHUTIL_FORCE_COLORS:+x} ]] || { [[ -t 2 ]] && [[ -z ${NO_COLOR:+x} ]] && [[ "${TERM:-dumb}" != dumb ]]; }; then
                        builtin printf '\x1b[0;1;33mwarning: %s\x1b[0m\n' "${*:2}" >&2
                    else
                        builtin printf 'warning: %s\n' "${*:2}" >&2
                    fi
                    ;;
                error)
                    if [[ ${BASHUTIL_FORCE_COLORS:+x} ]] || { [[ -t 2 ]] && [[ -z ${NO_COLOR:+x} ]] && [[ "${TERM:-dumb}" != dumb ]]; }; then
                        builtin printf '\x1b[0;1;31merror: %s\x1b[0m\n' "${*:2}" >&2
                    else
                        builtin printf 'error: %s\n' "${*:2}" >&2
                    fi
                    ;;
                *)
                    if [[ ${BASHUTIL_FORCE_COLORS:+x} ]] || { [[ -t 2 ]] && [[ -z ${NO_COLOR:+x} ]] && [[ "${TERM:-dumb}" != dumb ]]; }; then
                        builtin printf '\x1b[0;1;2;31m%s\x1b[0;1;31merror: %s\x1b[0m\n' "${BASH_SOURCE[1]:+[${BASH_SOURCE[1]}:${BASH_LINENO[0]}] }" "${1+unrecognized log level: }${1-missing log level argument}" >&2
                    else
                        builtin printf '%serror: %s\n' "${BASH_SOURCE[1]:+[${BASH_SOURCE[1]}:${BASH_LINENO[0]}] }" "${1+unrecognized log level: }${1-missing log level argument}" >&2
                    fi
                    return 2
                    ;;

            esac
        }

        # Declaring again is no-op. This form prints nothing in bash -x
        _bashutil_declare_log() {
            for x in; do :; done
        }
    }

    _bashutil_declare_die() {
        die() {
            local -i rc=$?
            if (( rc == 0 )); then
                rc=1
            fi
            local IFS=' ' # for spacing "$*" with spaces
            if [[ ${BASHUTIL_FORCE_COLORS:+x} ]] || { [[ -t 2 ]] && [[ -z ${NO_COLOR:+x} ]] && [[ "${TERM:-dumb}" != dumb ]]; }; then
                builtin printf '\x1b[0;1;31m%s\x1b[0m\n' "$*" >&2 || :
            else
                builtin printf '%s\n' "$*" >&2 || :
            fi
            exit $rc
        }

        # Declaring again is no-op. This form prints nothing in bash -x
        _bashutil_declare_die() {
            for x in; do :; done
        }
    }

    _bashutil_declare_progress_bar() {
        _bashutil_progress_bar_deinit() {
            if [[ ${_bashutil_progress_bar_initialized+x} ]] && [[ -t 2 ]]; then
                if (( ${_bashutil_lines:-0} > 0 )); then
                    builtin printf "\x1b7\x1b[r\x1b[%d;H\x1b[2K\x1b8" "${_bashutil_lines}" >&2 || :
                    #               ^^^^^ Save state (cursor position, colors, origin mode)
                    #                    ^^^^^^ Reset scrolling region to full screen
                    #                          ^^^^^^^^^ Go to the beginning of the bottom line
                    #                                   ^^^^^^^ Erase the bottom line
                    #                                          ^^^^^ Restore state (cursor position, colors, origin mode)
                else
                    builtin printf "\x1b7\x1b[r\x1b8" >&2 || :
                    #               ^^^^^ Save state (cursor position, colors, origin mode)
                    #                    ^^^^^^ Reset scrolling region to full screen
                    #                          ^^^^^ Restore state (cursor position, colors, origin mode)
                fi
            fi
            _bashutil_lines=0
            unset _bashutil_progress_bar_initialized
        }
        _bashutil_progress_bar_reinitialize() {
            if [[ ${_bashutil_progress_bar_msg+x} ]] && [[ -t 2 ]] && [[ "${TERM:-dumb}" != dumb ]]; then
                # Scrolling region smaller than 2 lines does not work...
                # We use disabling auto-wrapping to keep progress message in one line - counting number of
                # occupied terminal cells is too hard and would require handling Unicode etc.
                # Sacrificing overwritten last cell in the progress line for simplicity is a good trade-off.
                local dims
                if dims="$(stty size <&2 2> /dev/null)" && [[ "${dims%% *}" =~ ^[0-9]+$ ]] && _bashutil_lines="${dims%% *}" && (( _bashutil_lines > 2 )); then
                    _bashutil_progress_bar_initialized=1
                    builtin printf "\x1b7\x1b[r\x1b8\v\x1b[A\x1b7\x1b[%d;H\x1b[0m\x1b[2K\x1b[?7l%s\x1b[?7h\x1b[1;%dr\x1b8" ${_bashutil_lines} "${_bashutil_progress_bar_msg-}" $((_bashutil_lines - 1)) >&2 || :
                    #               ^^^^^ Save state (cursor position, colors, origin mode)
                    #                    ^^^^^^ Reset scrolling region to full screen
                    #                          ^^^^^ Restore state (cursor position, colors, origin mode)
                    #                               ^^^^^^^^ Go down one line (with scrolling if at the bottom), then go up.
                    #                                       ^^^^^ Save state (cursor position, colors, origin mode)
                    #                                            ^^^^^^^^^ Go to the beginning of the bottom line
                    #                                                     ^^^^^^^ Reset formatting (affects erasing line).
                    #                                                            ^^^^^^^ Erase the bottom line
                    #                                                                   ^^^^^^^^ Disable line auto-wrapping.
                    #  Enable back line auto-wrapping.                                            ^^^^^^^^
                    #  Exclude the bottom line from scrolling region                                      ^^^^^^^^^
                    #  Restore state (cursor position, colors, origin mode)                                        ^^^^^
                    return
                else
                    _bashutil_lines=0
                fi
            fi
            _bashutil_progress_bar_deinit
        }

        # Restore progress bar on the terminal's size change
        _bashutil_progress_bar_on_sigwinch() {
            local -i rc=$?
            _bashutil_progress_bar_reinitialize
            return $rc
        }
        _bashutil_add_trap_for WINCH _bashutil_progress_bar_on_sigwinch || return

        # Reset on exit
        _bashutil_progress_bar_on_exit() {
            local -i rc=$?
            # Make progress function no-op to prevent it reinitializing the progress bar.
            progress() {
                for x in; do :; done # This form prints nothing in bash -x
            }
            _bashutil_progress_bar_on_sigwinch() {
                return $?
            }
            _bashutil_progress_bar_on_exit() {
                return $?
            }
            _bashutil_progress_bar_deinit
            return $rc
        }
        _bashutil_add_trap_for EXIT _bashutil_progress_bar_on_exit || return

        progress() {
            local IFS=' ' # for spacing "$*" with spaces
            _bashutil_progress_bar_msg="$*"
            if [[ ${_bashutil_progress_bar_initialized+x} ]] && [[ -t 2 ]] && [[ "${TERM:-dumb}" != dumb ]]; then
                builtin printf "\x1b7\x1b[r\x1b[%d;H\x1b[0m\x1b[2K\x1b[?7l%s\x1b[?7h\x1b[1;%dr\x1b8" "${_bashutil_lines}" "${_bashutil_progress_bar_msg-}" $((_bashutil_lines - 1)) >&2 || :
                #               ^^^^^ Save state (cursor position, colors, origin mode)
                #                    ^^^^^^ Reset scrolling region to full screen
                #                          ^^^^^^^^^ Go to the beginning of the bottom line
                #                                   ^^^^^^^ Reset formatting (affects erasing line).
                #                                          ^^^^^^^ Erase the bottom line
                #                                                 ^^^^^^^^ Disable line auto-wrapping.
                #  Enable back line auto-wrapping.                          ^^^^^^^^
                #  Exclude the bottom line from scrolling region                    ^^^^^^^^^
                #  Restore state (cursor position, colors, origin mode)                      ^^^^^
            else
                # Init or restore progress bar if the stderr became usable again.
                _bashutil_progress_bar_reinitialize
            fi
        }

        # Declaring again is no-op. This form prints nothing in bash -x
        _bashutil_declare_progress_bar() {
            for x in; do :; done
        }
    }
fi

_bashutil_main "$@"
