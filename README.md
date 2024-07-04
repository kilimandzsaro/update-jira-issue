# update-jira-issue
A github action to be able to update a jira issue with the given information from github action.
The scripts can be used as a bash script or in github action. It was optimized to use linux in docker.

## pre-requisits
    - Setup the JIRA_BASE_URL environment variable
    - Setup the JIRA_USER_EMAIL environment variable
    - Setup the JIRA_API_TOKEN environment variable
These variables are needed to be able to authenticate to JIRA.

## Examples

### A github action where it searches for the Jira issue ID in the PRs title, body, commits or in branch name

The following github action is trying to get the Jira issue ID - following the given pattern - from either the branch name, the commit message or the PR title or PR's body. When the ID is found, it stored in the GITHUB_ENV variables, so other actions can use them
The order of the search is:
  - PR title
  - PR body
  - Commit
  - Branch name

```yaml
name: Get issue ID from git

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

      - name: Get Issue ID or sha
        id: get-id
        uses: kilimandzsaro/update-jira-issue/get_jira_issue_id_from_pr_commit_branch@v1
        with: 
          pattern: "XXX-[0-9]+"
          branch_name: ${{ github.head_ref }}
          remote: origin

```

### Update the given Jira issue field with the specified value

This action is trying to connect to Jira using it's API and update some field of the given Issue. There are some pre-requisits for this action.

Pre-requisits:
  - JIRA_BASE_URL environment variable to set to your Jira instance (eg: https://my-company.atlassian.net)
  - JIRA_API_TOKEN environment variable to set to your Jira's PAT (personal access token: https://confluence.atlassian.com/enterprise/using-personal-access-tokens-1026032365.html)
  - JIRA_USER_EMAIL environment variable to set which matches to the email used to login to Jira (and used to generate the PAT)

The action requires 3 input parameters:
      1. `issue_id` the ID of the Jira issue. 
         This is the ID of the issue you plan to modify. Usually it looks like <PROJECTKEY>-<NUMBERS>. Eg.: XXX-111
      2. `field_id` which needs to be modified
         Here you can find a way how to get your field ID: https://confluence.atlassian.com/jirakb/how-to-find-any-custom-field-s-ids-744522503.html
      3. `new_value` is the new value to set to the field.
         If the new value is not 1 string, then you have to quote it, otherwise only the first string will be used during the update

Example action:

```yaml
name: Update Jira issue

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

      - name: Update Jira Issue
        uses: kilimandzsaro/update-jira-issue/send_request_to_jira@v1
        with: 
          jira_api_token: ${{ secrets.JIRA_API_TOKEN }}
          jira_email: ${{ secrets.JIRA_EMAIL }}
          jira_base_url: ${{ secrets.JIRA_BASE_URL }}
          issue_id: XXX-111
          field_id: customfield_10052
          new_value: "whatever you want"

```

### Combining the two actions

You can combine the two actions and use the first action's output as an input to the second one.

Example combined action:

```yaml
name: Get issue ID from git

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

      - name: Get Issue ID or sha
        id: get-id
        uses: kilimandzsaro/update-jira-issue/get_jira_issue_id_from_pr_commit_branch@v1
        with: 
          pattern: "XXX-[0-9]+"
          branch_name: ${{ github.head_ref }}
          remote: origin

      - name: Update Jira Issue
        uses: kilimandzsaro/update-jira-issue/send_request_to_jira@v1
        with: 
          jira_api_token: ${{ secrets.JIRA_API_TOKEN }}
          jira_email: ${{ secrets.JIRA_EMAIL }}
          jira_base_url: ${{ secrets.JIRA_BASE_URL }}
          issue_id: ${{ steps.get-id.outputs.issue_id }}
          field_id: customfield_10052
          new_value: "whatever you want"

```