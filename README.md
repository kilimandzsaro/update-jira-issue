# update-jira-issue
A github action to be able to update a jira issue with the given information from github action.
The scripts can be used as a bash script or in github action. It was optimized to use linux in docker.

## pre-requisits
    - Setup the JIRA_BASE_URL environment variable
    - Setup the JIRA_USER_EMAIL environment variable
    - Setup the JIRA_API_TOKEN environment variable
These variables are needed to be able to authenticate to JIRA.

## Examples

### A github action where it searches for the Jira issue ID in the PRs title, commits or in branch name

The following github action is trying to get the Jira issue ID - following the given pattern - from either the branch name, the commit message or the PR title. If neither is found, then it will use the PR's sha to modify the issue's given text field

10052

```yaml
name: Update Jira issue field

on:
  pull_request:
    branches:
      - master

jobs:
  check-pattern:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up GitHub CLI
        uses: cli/gh-action@v2

      - name: Get PR details
        id: pr
        run: |
          echo "PR_TITLE=$(gh pr view ${{ github.event.pull_request.number }} --json title --jq .title)" >> $GITHUB_ENV
          echo "BRANCH_NAME=${{ github.head_ref }}" >> $GITHUB_ENV

      - name: Search in branch name
        run: |
          if [[ "${BRANCH_NAME}" == *"ENG-111"* ]]; then
            echo "Pattern found in branch name: ${BRANCH_NAME}"
          else
            echo "Pattern not found in branch name."
          fi

      - name: Search in commit messages
        run: |
          git fetch origin ${{ github.head_ref }}
          COMMIT_MATCHES=$(git log origin/${{ github.head_ref }} --pretty=format:"%H %s" | grep -i "ENG-111" || true)
          if [ -n "$COMMIT_MATCHES" ]; then
            echo "Pattern found in commit messages:"
            echo "$COMMIT_MATCHES"
          else
            echo "Pattern not found in commit messages."
          fi

      - name: Search in pull request title
        run: |
          if [[ "${PR_TITLE}" == *"ENG-111"* ]]; then
            echo "Pattern found in pull request title: ${PR_TITLE}"
          else
            echo "Pattern not found in pull request title."
          fi
```



Action to get the JIRA issue ID from either the PR title, or from branch name, or from the commits on the branch:




```
on:
  push

name: Test Transition Issue

jobs:
  fill-release-in-issue:
    name: Release issue
    runs-on: ubuntu-latest
    steps:
    - name: Checkout
      uses: actions/checkout@master

    - name: Login
      uses: atlassian/gajira-login@v3
      env:
        JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}
        JIRA_USER_EMAIL: ${{ secrets.JIRA_USER_EMAIL }}
        JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}

    - name: Find Issue Key
      uses: ./
      with:
        from: commits

    - name: Transition issue
      uses: atlassian/gajira-transition@master
      with:
        issue: ${{ steps.create.outputs.issue }}
        transition: "In Progress"
```
