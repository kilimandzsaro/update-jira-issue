#!/bin/bash
# It requires some environment variables to set to be able to connect to JIRA
# Environment variables:
#      - JIRA_BASE_URL
#      - JIRA_USER_EMAIL
#      - JIRA_API_TOKEN

# Example input and output (from the bash prompt):
# ./send-request-to-jira.bash -i "ENG-2222" -f "Release" -v "v2.0.0"
# -h, --help          Print the help page
# -p, --pattern       The patter of the Jira issue ID you are looking for
# -b, --branch   The branch name to observe
# -r, --remote        The remote name if it's other then "origin"

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

pattern=""
branch=""
remote="origin"

options=hp:b:r:V 
optionslong=help,pattern:,branch:,remote:,version

#=== Functions =================================================================

# Help page
usage () {
    echo "
    This sciprt tries find the given pattern first in the PR name, then in commits, then in the branch name. If not found, then it returns with the PRs hash.

    The script requires 2 mandator parameters and 1 optional one:
      1. Pattern should be a pattern to look for. You can set it with the '-p' or '--pattern' switch. 
         This is a pattern of a JIRA ID the script should find. Usually it looks like "XXX-[0-9]+"
      2. The branch which should be checked. It can be set with the '-b' or '--branch' switch.
      3. If your remote is not the default "origin", then with '-o' or '--origin' you can set to the correct one

    Usage: ${0##/*/} [options] [--]

    Options:
    -h|--help          Print the help page
    -p|--pattern       Pattern (with regexp if you wish) to look for
    -b|--branch        The branch name to check
    -r|--remote        The remote branch if it's not "origin"
    -V|--version       Display script version
    "
    exit 0
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

# Process the script arguments
option_handling() {
    if [ $# -lt 4 ]; then
        echo "Missing some parameters"
        usage
    fi
    OPTS=$(getopt --name "$0" --options $options --longoptions $optionslong -- "$@") || (echo; echo "See above and try \"$0 --help\""; echo ; exit 1)

    eval set -- "$OPTS"
    unset OPTS

    while true ; do
        case "$1" in
            -h|--help)
                usage
                ;;
            -p|--pattern) 
                # echo "I am looking for the '$2' issue"
                pattern="$2" ; shift 2 ;;
            -b|--branch) 
                # echo "On the '$2' branch" 
                branch=$2; shift 2 ;;
            -r|--remote)
                # echo "The remote name is: '$2'" 
                remote=$2; shift 2 ;;
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

# Function to search in branch name
search_in_branch_name() {
    if [[ "$branch" =~ $pattern ]]; then
        echo "found in branch name"
        echo "${BASH_REMATCH[0]}"
        echo "issue_id=${BASH_REMATCH[0]}" >> $GITHUB_ENV
        return 0
    fi
    echo "didn't find in branch"
    return 1
}

# Function to search in commit messages
search_in_commit_messages() {
    commit_matches=$(git log "$remote/$branch" --pretty=format:"%H %s %b" | grep -E -o "$pattern")
    if [ -n "$commit_matches" ]; then
        echo "found in commit"
        echo "${commit_matches}" | head -n 1
        echo "issue_id=${commit_matches}" >> $GITHUB_ENV
        return 0
    fi
    echo "didn't find in commit"
    return 1
}

# Function to search in pull request title
search_in_pr_title() {
    pr_title=$(gh pr list --head "$branch" --json title --jq '.[0].title' 2>/dev/null)
    if [ -n "$pr_title" ]; then
        if [[ "$pr_title" =~ $pattern ]]; then
            echo "${BASH_REMATCH[0]}"
            echo "found in PR"
            echo "issue_id=${BASH_REMATCH[0]}" >> $GITHUB_ENV
            return 0
        fi
    fi
    echo "didn't find in PR title"
    return 1
}

# Function to search in pull request description (body)
search_in_pr_body() {
    pr_title=$(gh pr list --head "$branch" --json body --jq '.[0].body' 2>/dev/null)
    if [ -n "$pr_title" ]; then
        if [[ "$pr_title" =~ $pattern ]]; then
            echo "${BASH_REMATCH[0]}"
            echo "found in PR description"
            echo "issue_id=${BASH_REMATCH[0]}" >> $GITHUB_ENV
            return 0
        fi
    fi
    echo "didn't find in PR description"
    return 1
}

# Function to get the PR SHA
get_pr_sha() {
    pr_sha=$(gh pr view --json commits --jq '.commits[0].oid' 2>/dev/null)
    if [ -n "$pr_sha" ]; then
        echo "Using the PR's SHA"
        echo "$pr_sha"
        echo "issue_id=${pr_sha}" >> $GITHUB_ENV
    else
        echo "PR SHA not found."
    fi
}

# ----------  end of functions

cleanup () { # Will be called by the trap above, no need to call it manually.
  :
} # ----------  end of function cleanup  ----------

#=== Main ======================================================================
main () {
    # Fetch the latest changes from the remote
    git fetch "$remote"

    option_handling "$@"
    # Run the functions and return the found issue ID or the PR SHA
    if search_in_pr_title; then
        exit 0
    elif search_in_pr_body; then
        exit 0
    elif search_in_commit_messages; then
        exit 0
    elif search_in_branch_name; then
        exit 0
    else
        get_pr_sha
        exit 0
    fi

    exit 1
} # ----------  end of function main  ----------

main "$@"

#=== End =======================================================================
