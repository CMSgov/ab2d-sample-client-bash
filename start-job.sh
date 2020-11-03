#!/bin/bash
# Parameters:
#   1 - URL to run against
#   2 - Base64 encoded clientId:clientPassword
#   3 - The contract number (Optional)

source fn_get_token.sh

# Refresh bearer token
BEARER_TOKEN=$(fn_get_token "$IDP_URL" "$AUTH_FILE")
if [ "$BEARER_TOKEN" == "null" ]
then
  printf "Failed to retrieve bearer token is base64 token accurate?\nIs %s available from this computer?\n", $IDP_URL
  exit 1
fi

# If a contract number is provided only pull for the specified contract
if [ "$CONTRACT" != '' ]
then
    URL="${API_URL}/Group/$CONTRACT/\$export?_outputFormat=application%2Ffhir%2Bndjson&_type=ExplanationOfBenefit"
    echo "Getting contract $CONTRACT"
# If no contract number then pull all contracts that the provided bearer token has access too
else
    URL="${API_URL}/Patient/\$export?_outputFormat=application%2Ffhir%2Bndjson&_type=ExplanationOfBenefit"
fi

# If a date is provided
if [ "$SINCE" != '' ]; then
  URL="$URL&_since=$SINCE"
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

