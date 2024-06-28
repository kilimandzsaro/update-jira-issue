#!/bin/bash
issue_id=$1
field_id=$2
new_value=$3

# Function to update the "Release" field
update_field() {
    # JSON payload
    PAYLOAD=$(cat <<EOF
{
    "fields": {
        "$field_id": "$new_value"
    }
}
EOF
)

    # API call to update the issue
    RESPONSE=$(curl -s -w "%{http_code}" -o /dev/null \
        -X PUT \
        --url "$JIRA_BASE_URL/rest/api/2/issue/$issue_id" \
        -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")

    # Check response code
    if [ "$RESPONSE" -eq 204 ]; then
        echo "Issue $JIRA_ISSUE_KEY updated successfully."
        return 0
    else
        echo "Failed to update issue $JIRA_ISSUE_KEY. HTTP Status Code: $RESPONSE"
        return 1
    fi
}

# Run the function
if update_release_field then;
    exit 0
else
    exit 1
fi
