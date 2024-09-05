#!/bin/bash
# Parameters:
#   1 - URL to run against
#   2 - Base64 encoded clientId:clientPassword

source fn_get_token.sh

# Refresh bearer token
BEARER_TOKEN=$(fn_get_token "$IDP_URL" "$AUTH_FILE")
if [ "$BEARER_TOKEN" == "null" ]
then
  printf "Failed to retrieve bearer token is base64 token accurate?\nIs %s available from this computer?\n", $IDP_URL
  exit 1
fi

URL="${API_URL}/Patient/\$export?_outputFormat=application%2Ffhir%2Bndjson&_type=ExplanationOfBenefit"

# If a date is provided
if [ "$SINCE" != '' ]; then
  URL="$URL&_since=$SINCE"
fi

if [ "$UNTIL" != '' ]; then
  URL="$URL&_until=$UNTIL"
fi

echo "Attempting to start job using $URL"

RESULT=$(curl "$URL" \
    -sD - \
    -H "accept: application/json" \
    -H "Accept: application/fhir+json" \
    -H "Prefer: respond-async" \
    -H "Authorization: Bearer ${BEARER_TOKEN}")

echo "$RESULT"

HTTP_CODE=$(echo "$RESULT" | grep "HTTP/" | awk  '{print $2}')
if [ "$HTTP_CODE" != 202 ]
then
    echo "Could not export job"
    exit 1
else
    JOB=$(echo "$RESULT" | grep "\(content-location\|Content-Location\)" | sed 's/.*Job.//' | sed 's/..status//' | tr -d '[:space:]')

    if [ "$JOB" == '' ]
    then
      echo "Could not parse response for job id. Make sure to save the job id located on the line with 'content-location'"
      exit 1
    fi

    echo "$JOB created"

    echo "$JOB" > "$DIRECTORY/jobId.txt"

    echo "Saved job id to $DIRECTORY/jobId.txt"
fi

