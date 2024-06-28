#!/bin/bash

# Variables
PATTERN=$1
BRANCH=$2
REMOTE="origin"

# Function to search in branch name
search_in_branch_name() {
    if [[ "$BRANCH" == *"$PATTERN"* ]]; then
        echo "$PATTERN"
        return 0
    fi
    return 1
}

# Function to search in commit messages
search_in_commit_messages() {
    COMMIT_MATCHES=$(git log "$REMOTE/$BRANCH" --pretty=format:"%H %s" | grep -i "$PATTERN")
    if [ -n "$COMMIT_MATCHES" ]; then
        echo "$PATTERN"
        return 0
    fi
    return 1
}

# Function to search in pull request title
search_in_pr_title() {
    PR_TITLE=$(gh pr list --head "$BRANCH" --json title --jq '.[0].title' 2>/dev/null)
    if [ -n "$PR_TITLE" ]; then
        if [[ "$PR_TITLE" == *"$PATTERN"* ]]; then
            echo "$PATTERN"
            return 0
        fi
    fi
    return 1
}

# Function to get the PR SHA
get_pr_sha() {
    PR_SHA=$(gh pr view --json commits --jq '.commits[0].oid' 2>/dev/null)
    if [ -n "$PR_SHA" ]; then
        echo "$PR_SHA"
    else
        echo "PR SHA not found."
    fi
}

# Fetch the latest changes from the remote
git fetch "$REMOTE"

# Run the functions and return the found issue ID or the PR SHA
if search_in_branch_name; then
    exit 0
elif search_in_commit_messages; then
    exit 0
elif search_in_pr_title; then
    exit 0
else
    get_pr_sha
    exit 0
fi
