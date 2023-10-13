#!/usr/bin/env bash

source bootstrap.sh "$@"

if [ "$BEARER_TOKEN" == "null" ]
then
    printf "Failed to retrieve bearer token is base64 token accurate?\nIs %s available from this computer?\n", $IDP_URL
    exit 1
fi

echo "Using okta url: $IDP_URL"
echo "Connecting to AB2D API at: $API_URL"
echo "Saving data to: $DIRECTORY"
echo "FHIR Version: $FHIR_VERSION"

# ------ Starting job

echo "Starting job"
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

echo "Attempting to start job using $URL"

RESULT=$(curl "$URL" \
    -v \
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
fi


# ------ Monitoring job
echo "Monitoring job with job id $JOB"

# Get the status
RESPONSE=$(curl "${API_URL}/Job/${JOB}/\$status" -v -sD - -H "accept: application/json" -H "Authorization: Bearer ${BEARER_TOKEN}")
URLS=$(echo "$RESPONSE" | grep ExplanationOfBenefit)

sleep 5

# If there are no results, wait x seconds and try again
while [ "$URLS" == '' ]
do
    # If response is unauthorized refresh token and try again
    HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP/" | awk  '{print $2}')

    if [ "$HTTP_CODE" == 403 ]
    then
        echo "Token expired refreshing and then attempting to check status again"
        BEARER_TOKEN=$(fn_get_token "$IDP_URL" "$AUTH_FILE")
        sleep 30
        RESPONSE=$(curl "${API_URL}/Job/${JOB}/\$status" -v -sD - -H "accept: application/json" -H "Authorization: Bearer ${BEARER_TOKEN}")
    elif [ "$HTTP_CODE" != 202 ] && [ "$HTTP_CODE" != 200 ]
    then
        echo "Error making rest call $HTTP_CODE"
        echo "Exiting without saving results"
        exit 1
    else

        echo "$RESPONSE"
        URLS=$(echo "$RESPONSE" | grep ExplanationOfBenefit)

        # Sleep and increment counter
        if [ "$URLS" == '' ]
        then
            sleep 60

            COUNTER=$(( COUNTER +1 ))

            # Log every ten seconds
            if [ $((COUNTER % 10)) == 0 ]
            then
              echo "Running for $COUNTER minutes"
            fi

            RESPONSE=$(curl "${API_URL}/Job/${JOB}/\$status" -v -sD - -H "accept: application/json" -H "Authorization: Bearer ${BEARER_TOKEN}")
        fi

    fi
done

echo "Job finished with
$RESPONSE"

echo "$RESPONSE" > "$DIRECTORY/response.json"

echo "Saved response to $DIRECTORY/response.json"

# ------ Download results for job
echo "Download results for job"

URLS=$(cat "$DIRECTORY/response.json" | grep ExplanationOfBenefit | jq --raw-output ".output[].url")

# Download each file by url
COUNTER=0

echo "List of files to download $URLS"

for URL in ${URLS}
do
    FILE_NAME="$DIRECTORY"/$(echo ${URL} | sed 's/.*.file.//')

    echo "$URL"

    if [ -f "$FILE_NAME" ]
    then
        echo "$FILE_NAME already exists, skipping"
    else
        curl --header "Accept: application/fhir+ndjson" \
          --header "Authorization: Bearer ${BEARER_TOKEN}" \
          "$URL" > "$FILE_NAME"

        COUNTER=$(( COUNTER +1 ))

        echo "Updating bearer token"
        BEARER_TOKEN=$(fn_get_token "$IDP_URL" "$AUTH_FILE")
    fi
done


