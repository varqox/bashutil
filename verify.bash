#!/usr/bin/env bash
set -uo pipefail

# Check that all internal functions become hidden after sourcing
if [[ -t 2 ]]; then
    bold=$'\x1b[;1m'
    bold_red=$'\x1b[;1;31m'
    bold_green=$'\x1b[;1;32m'
    reset_style=$'\x1b[m'
else
    bold=
    bold_red=
    bold_green=
    reset_style=
fi

function verify_error() {
    printf "${bold}${BASH_SOURCE[0]##*/}:${BASH_LINENO[0]}: ${bold_red}error: ${bold}%s${reset_style}\n" "$*" >&2
    exit 1
}
function verify_info() {
    printf "${bold}%s${reset_style}\n" "$*" >&2
}

verification_result="${bold_red}FAILED${reset_style}"
trap 'echo "${bold}verification: ${verification_result}"; exit' EXIT SIGTERM SIGINT SIGQUIT SIGPIPE SIGALRM

bashutil_path="${BASH_SOURCE[0]%/*}/bashutil.bash"

####################################################################################################
verify_info "checking that all internal functions stay hidden"
(
    . "${bashutil_path}" || exit
    declare -F |
        sed --silent "/^declare -f bashutil_/{
                s/^declare -f/${bold_red}error: ${bold}function was not unset:/
                s/\$/${reset_style}/
                w /dev/stderr
                # Mark we found something
                h
            }
            \${
                x
                # Exit with error if we found something
                /./q1
            }" || exit
)

####################################################################################################
verify_info "checking that all reported features can be used"
features_reported=($(. "${bashutil_path}" --features)) || verify_error "listing features failed"
for feature in "${features_reported[@]}"; do
    (. "${bashutil_path}" "${feature}") || verify_error "error when trying to load feature: ${feature}"
done

####################################################################################################
verify_info "checking that all features are visible for users"
features_found_by_audit=(
    $(sed --silent '/^\s*bashutil_declare_/{
            s/^\s*bashutil_declare_//
            s/\s*(.*//p
        }' "${bashutil_path}" | uniq)
) || verify_error 'sed error'

diff --unified --minimal --color=auto \
    <(printf "%s\n" "${features_reported[@]}" | sort) \
    <(printf "%s\n" "${features_found_by_audit[@]}" | sort) \
    >&2 ||
        verify_error "features reported by bashutil and declared inside ${bashutil_path} differ"

####################################################################################################
verify_info "checking that all unsets are up to date"
features_unset=(
    $(sed --silent 's/^\s*unset -f bashutil_declare_//p' "${bashutil_path}")
) || verify_error 'sed error'


diff --unified --minimal --color=auto \
    <(printf "%s\n" "${features_unset[@]}" | sort) \
    <(printf "%s\n" "${features_found_by_audit[@]}" | sort) \
    >&2 ||
        verify_error "features unset in bashutil and declared inside ${bashutil_path} differ"

####################################################################################################
verification_result="${bold_green}PASSED${reset_style}"
