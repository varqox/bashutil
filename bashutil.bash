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
# TODO: this may be not needed if we want to load more features conditionally
readonly bashutil='' 2> /dev/null || {
    bashutil_error "bashutil is already sourced"
    unset -f bashutil_error
    return 1
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
