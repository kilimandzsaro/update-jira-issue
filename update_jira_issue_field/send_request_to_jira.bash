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

OPTIONS=hi:f:v:V 
OPTIONSLONG=help,issue_id:,field_id:,new_value:,version

#=== Functions =================================================================

# Help page
usage () {
    exit_code=${1:=0}
    echo "
    This sciprt tries to update the given field of the given Jira issue. It uses Jira's API to do so.
    Pre-requisits:
      - JIRA_BASE_URL environment variable to set to your Jira instance
      - JIRA_API_TOKEN environment variable to set to your Jira's PAT (personal access token: https://confluence.atlassian.com/enterprise/using-personal-access-tokens-1026032365.html)
      - JIRA_USER_EMAIL environment variable to set which matches to the email used to login to Jira (and used to generate the PAT)

    The script requires 3 parameters:
      1. Issue ID which you can set with the '-i' or '--issue_id' switch. 
         This is the ID of the issue you plan to modify. Usually it looks like <PROJECTKEY>-<NUMBERS>. Eg.: XXX-111
      2. Field ID you want to modify and set with the '-f' or '--field_id' switch.
         Here you can find a way how to get your field ID: https://confluence.atlassian.com/jirakb/how-to-find-any-custom-field-s-ids-744522503.html
      3. New value to set to the field using the '-v' or '--new_value' switch.
         If the new value is not 1 string, then you have to quote it, otherwise only the first string will be used during the update

    Usage: ${0##/*/} [options] [--]

    Options:
    -h|--help          Print the help page
    -i|--issue_id      JIRA ID of the issue you want to manipulate
    -f|--field_id      The ID of the field you want to modify
    -v|--new_value     The value you want to add to the given field
    -V|--version       Display script version
    "
    exit $exit_code
}

# Checks if the given variable is defined and not empty.
# It expects the variable name's in question as an argument (NOT THE VARIABLE ITSELF!)
check_variable() {
    name="$1"
    if [ -z "${!name}" ]; then
        echo "Missing a required parameter to perform the action"
        echo "The needed parameter is:" 
        echo "    $(echo $name)"
        exit 1
    fi
}

# Make sure that the needed Jira environment variables are set
check_jira_auth_variables() {
    if [ -z "${JIRA_BASE_URL+x}" -o -z "${JIRA_API_TOKEN+x}" -o -z "${JIRA_USER_EMAIL+x}" ]; then
        echo "Not all JIRA environment variables set, please do it: JIRA_BASE_URL, JIRA_API_TOKEN, JIRA_USER_EMAIL"
        exit 1
    fi
}

# Process the script arguments
option_handling() {
    if [ $# -lt 6 ]; then
        echo "Missing some parameters"
        usage 1
    fi
    OPTS=$(getopt --name "$0" --options $OPTIONS --longoptions $OPTIONSLONG -- "$@") || (echo; echo "See above and try \"$0 --help\""; echo ; exit 1)

    eval set -- "$OPTS"
    unset OPTS

    while true ; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -i|--issue_id) 
                echo "I am looking for the '$2' issue"
                ISSUE_ID=$2 ; shift 2 ;;
            -f|--field_id) 
                echo "The '$2' field will be modified" 
                FIELD_ID=$2; shift 2 ;;
            -v|--new_value)
                echo "The new value will be: '$2'" 
                NEW_VALUE=$2; shift 2 ;;
            -V|--version)
                echo "$0 -- Version $ScriptVersion"; exit 0
                ;;
            --)
                shift
                break
                ;;
            *) echo "Switch not found" ; exit 1 ;;
        esac
    done
}

# Send a PUT request to update the given issue's field.
# The function requires 3 arguments, first is the issue ID, the second is the field ID and the third is the value.
# If you are wondering why the function is not using the global variables, it's because I tried to write it as modular as possible.
update_issue() {
    if [ $# -ne 3 ]; then
        echo "Missing some arguments, please provide the ISSUE_ID, FIELD_ID and NEW_VALUE in this order"
        exit 1
    fi
    issue=$1
    field=$2
    value=$3
    check_variable issue
    check_variable field
    check_variable value
    # JSON payload
    template='{"fields": {"%s": "%s"}}\n'
    payload=$(printf "$template" "$field" "$value")

    # API call to update the issue
    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
        -X PUT \
        --url "$JIRA_BASE_URL/rest/api/2/issue/$issue" \
        -u "$JIRA_USER_EMAIL:$JIRA_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload")

    # Check response code
    if [[ "$RESPONSE" == "204" ]]; then
        echo "Issue $issue updated successfully."
        return 0
    else
        echo "Failed to update issue $issue. HTTP Status Code: $RESPONSE"
        return 1
    fi
}

# ----------  end of functions

cleanup () { # Will be called by the trap above, no need to call it manually.
  :
} # ----------  end of function cleanup  ----------

#=== Main ======================================================================
main () {
    check_jira_auth_variables
    option_handling "$@"
    update_issue "$ISSUE_ID" "$FIELD_ID" "$NEW_VALUE"
} # ----------  end of function main  ----------

main "$@"

#=== End =======================================================================
