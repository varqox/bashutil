#!/usr/bin/env bash

if [[ -t 2 ]]; then
    bashutil_error() {
        printf "\x1b[1m%s: \x1b[;1;31merror: \x1b[;1m%s\x1b[m\n" "${BASH_SOURCE[0]}" "$*" >&2
    }
else
    bashutil_error() {
        printf "%s: merror: %s\n" "${BASH_SOURCE[0]}" "$*" >&2
    }
fi

(return 0) 2> /dev/null || {
    bashutil_error "should be sourced, not executed"
    exit 1
}
readonly bashutil='' 2> /dev/null || {
    bashutil_error "bashutil is already sourced"
    return 1
}

bashutil_declare_logs() {
    declare -i debugging=0

    debug() {
        if (( debugging != 0 )); then
            printf '\x1b[;36m%s\x1b[m\n' "$*" >&2
        fi
    }

    info() {
        printf '\x1b[;1m%s\x1b[m\n' "$*" >&2
    }

    warn() {
        printf '\x1b[;1;33m%s\x1b[m\n' "$*" >&2
    }

    error() {
        printf '\x1b[;1;31m%s\x1b[m\n' "$*" >&2
    }

    die_with_error() {
        error "$@"
        exit 1
    }

    bashutil_declare_logs() { for x in; do :; done }
}

while (( $# > 0 )); do
    case "$1" in
        --help)
            echo "Usage: . ${BASH_SOURCE[0]} [--help | --features | [<FEATURE>...]]"
            return
            ;;
        --features)
            printf '%s\n' logs
            return
            ;;
        logs)
            bashutil_declare_$1
            ;;
        *)
            bashutil_error "unrecognized argument: $1"
            return 1
            ;;
    esac
    shift
done

unset -f bashutil_error
unset -f bashutil_declare_logs
