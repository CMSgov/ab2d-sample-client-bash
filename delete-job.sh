#!/usr/bin/env bash

source fn_get_token.sh

BEARER_TOKEN=$(fn_get_token "$IDP_URL" "$AUTH_FILE")
if [ "$BEARER_TOKEN" == "null" ]
then
    printf "Failed to retrieve bearer token is base64 token accurate?\nIs %s available from this computer?\n", $IDP_URL
    exit 1
fi

JOB=$(cat "$DIRECTORY/jobId.txt")

echo "Id of job being monitored $JOB"

# Get the status
RESPONSE=$(curl -X DELETE "${API_URL}/Job/${JOB}/\$status" -sD - -H "accept: application/json" -H "Authorization: Bearer ${BEARER_TOKEN}" -vvv)
echo $RESPONSE