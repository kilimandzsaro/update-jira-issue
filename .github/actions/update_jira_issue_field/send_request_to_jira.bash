#!/bin/bash
# It requires some environment variables to set to be able to connect to JIRA
# Environment variables:
#      - JIRA_BASE_URL
#      - JIRA_USER_EMAIL
#      - JIRA_API_TOKEN

# Example input and output (from the bash prompt):
# ./send-request-to-jira.bash -i "ENG-2222" -f "Release" -v "v2.0.0"
# -h, --help          Print the help page
# -i, --issue_id      JIRA ID of the issue you want to manipulate
# -f, --field_name    The ID of the field you want to modify
# -v, --new_value     The value you want to add to the given field

# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.

#=== Init ======================================================================
set -o nounset   # exit on unset variables.
set -o errexit   # exit on any error.
set -o errtrace  # any trap on ERR is inherited
#set -o xtrace    # show expanded command before execution.

unalias -a       # avoid rm being aliased to rm -rf and similar issues
LANG=C           # avoid locale issues

ScriptVersion="1.0"

trap "cleanup" EXIT SIGTERM

ISSUE_ID=""
FIELD_ID=""
NEW_VALUE=""

#=== Functions =================================================================

# Help page
usage () {
    echo "
    Usage: ${0##/*/} [options] [--]

    Options:
    -h|--help          Print the help page
    -i|--issue_id      JIRA ID of the issue you want to manipulate
    -f|--field_id      The ID of the field you want to modify
    -v|--new_value     The value you want to add to the given field
    -V|--version       Display script version
    "
    exit 0
}

check_jira_auth_variables() {
    if [[ ! -v JIRA_BASE_URL ] || [ ! -v JIRA_API_TOKEN ] || [ ! -v JIRA_USER_EMAIL ]]; then
        echo "Not all JIRA environment variables set, please do it: JIRA_BASE_URL, JIRA_API_TOKEN, JIRA_USER_EMAIL"
        exit 1
    elif [[ -z "$JIRA_BASE_URL" ] || [ -z "$JIRA_API_TOKEN" ] || [ -z "$JIRA_USER_EMAIL" ]]; then
        echo "One or more JIRA environment variables are empty, please set them: JIRA_BASE_URL, JIRA_API_TOKEN, JIRA_USER_EMAIL"
        exit 1
    fi
}

option_handling() {
    OPTS=$(getopt --name "$0" \
    --options hi:f:F:v::V \
    --longoptions help,issue_id:,field_id:,new_value::,version \
    -- "$@") \
    || (echo; echo "See above and try \"$0 --help\""; echo ; exit 1)

    eval set -- "$OPTS"
    unset OPTS

    while true ; do
        case "$1" in
            -h|--help) 
                usage
                ;;
            -i|--issue_id) 
                echo "I am looking for the \`$2' issue"
                ISSUE_ID = $2 ; shift 2 ;;
            -f|--field_id) 
                echo "The \`$2' filed will be modified" 
                FIELD_ID=$2; shift 2 ;;
            -v|--new_value)
                echo "Trying to add the \`$2' value to the given field" 
                NEW_VALUE=$2; shift 2 ;;
            -V|--version)
                echo "$0 -- Version $ScriptVersion"; exit 0
                ;;
            *) echo "Switch not found" ; exit 1 ;;
        esac
    done
}

update_issue() {
    # Call the update script and capture the response
    "./jira-handler/modify_issue_field.bash $ISSUE_ID $FIELD_ID $NEW_VALUE"
}

# ----------  end of functions

cleanup () { # Will be called by the trap above, no need to call it manually.
  :
} # ----------  end of function cleanup  ----------

#=== Main ======================================================================
main () {
    check_jira_auth_variables
    option_handling "$@"
} # ----------  end of function main  ----------

main "$@"

#=== End =======================================================================
