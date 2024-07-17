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
        uses: actions/checkout@v4

      - name: Get Issue ID or sha
        id: get-id
        uses: kilimandzsaro/update-jira-issue/get_jira_issue_id_from_pr_commit_branch@v2
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
        uses: actions/checkout@v4

      - name: Update Jira Issue
        uses: kilimandzsaro/update-jira-issue/send_request_to_jira@v2
        with: 
          issue_id: XXX-111
          field_id: customfield_10052
          new_value: "whatever you want"
        env:
          JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
          JIRA_USER_EMAIL: ${{ secrets.JIRA_USER_EMAIL }}
          JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}

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
        uses: actions/checkout@v4

      - name: Get Issue ID or sha
        id: get-id
        uses: kilimandzsaro/update-jira-issue/get_jira_issue_id_from_pr_commit_branch@v2
        with: 
          pattern: "XXX-[0-9]+"
          branch: ${{ github.head_ref }}
          remote: origin

      - name: Update Jira Issue
        uses: kilimandzsaro/update-jira-issue/update_jira_issue_field@v2
        with: 
          issue_id: ${{ env.issue_id }}
          field_id: customfield_10052
          new_value: "whatever you want"
        env:
          JIRA_API_TOKEN: ${{ secrets.JIRA_API_TOKEN }}
          JIRA_USER_EMAIL: ${{ secrets.JIRA_USER_EMAIL }}
          JIRA_BASE_URL: ${{ secrets.JIRA_BASE_URL }}

```

# get jira issue ID from last release tag

This action goes over the git log and tries to find the pattern specified as input. It returns with the found results as an array.
It tries to find the given pattern since the last release tag. It uses tags, so if your repository doesn't use them, then this is not for you.
The output is stored in the `issues` variable

## Example

```yaml
name: Get issues from last release

on:
  pull_request:
    branches:
      - master

jobs:
  get-issues:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Get Issue IDs
        id: get-ids
        uses: kilimandzsaro/update-jira-issue/get_jira_issue_id_from_last_release_tag@v2
        with: 
          pattern: "XXX-[0-9]+"

```

# send_to_jira_webhook

This action is a generalization of the `update_jira_issue_field` action. You have full control over the body which is sent to jira so you can customize the automation in jira.
The base idea is coming from this action: https://github.com/GeoWerkstatt/create-jira-release
Only the webhook URL is the mandatory input parameter.

## Example

```yaml
name: Send to Jira

on:
  pull_request:
    branches:
      - master

jobs:
  get-issues:
    runs-on: ubuntu-latest

    steps:
      - name: Get Issue IDs
        id: get-ids
        uses: kilimandzsaro/update-jira-issue/send_to_jira_webhook@v2
        with: 
          jira-automation-webhook: "https://xxx.atlassian.com/xxxxxx"
          jira-issue-ids: ["XXX-111", "XXX-222"]
          request-data: { "field1": "value1", "field2": "value2" }
```

### Combining some actions

This is an example how you can combine some of the actions

```yaml
name: Sending info to Jira

on:
  pull_request:
    branches:
      - master

jobs:
  check-pattern:
    runs-on: ubuntu-latest
    env:
      jira_project_id: XXX

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Get Issue IDs
        id: get-ids
        uses: kilimandzsaro/update-jira-issue/get_jira_issue_id_from_last_release_tag@v2
        with: 
          pattern: "XXX-[0-9]+"
      
      - name: build request body
        id: request-body
        run: |
          body=$(jq -n \
            --arg version: "v0.0.0" \
            --arg projectName "${{ env.jira_project_id }}" \
            --arg repository "${{ github.event.repository.name }}" \
            '{
              version: $version,
              projectName: $projectName,
              repository: $repository
            }') >> GITHUB_OUTPUT

      - name: Get Issue IDs
        id: get-ids
        uses: kilimandzsaro/update-jira-issue/send_to_jira_webhook@v2
        with: 
          jira-automation-webhook: "https://xxx.atlassian.com/xxxxxx"
          jira-issue-ids: ${{ steps.get-ids.outputs.issues }}
          request-data: ${{ steps.request-body.outputs.body }}
```
