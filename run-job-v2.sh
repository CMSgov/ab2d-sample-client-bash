#!/usr/bin/env bash

source bootstrap.sh "$@"

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

PATIENT_HEADERS_FILE="$DIRECTORY/patient_headers.txt"
HTTP_CODE=$(curl "$URL" \
    -s \
    -w "%{http_code}" \
    -D "$PATIENT_HEADERS_FILE" \
    -H "accept: application/json" \
    -H "Accept: application/fhir+json" \
    -H "Prefer: respond-async" \
    -H "Authorization: Bearer ${BEARER_TOKEN}")

cat "$PATIENT_HEADERS_FILE"

if [ "$HTTP_CODE" != 202 ]
then
    echo "Could not export job"
    exit 1
else
    JOB=$(grep "\(content-location\|Content-Location\)" "$PATIENT_HEADERS_FILE" | sed 's/.*Job.//' | sed 's/..status//' | tr -d '[:space:]')

    if [ "$JOB" == '' ]
    then
      echo "Could not parse response for job id. Make sure to save the job id located on the line with 'content-location'"
      exit 1
    fi
fi

# ------ Monitoring job
echo "Monitoring job with job id $JOB"

JOB_HEADERS_FILE="$DIRECTORY/job_headers.txt"
JOB_RESPONSE_FILE="$DIRECTORY/job_response.txt"

# Empty response file to avoid getting URLs from a previous run
echo -n "" > "$JOB_RESPONSE_FILE"

JOB_JSON=""
COUNTER=0

while [ "$JOB_JSON" == '' ]; do
    # Sleep and increment counter
    sleep 60
    COUNTER=$(( COUNTER +1 ))
    echo "Running for $COUNTER minutes"

    HTTP_CODE=$(curl "${API_URL}/Job/${JOB}/\$status" \
        -s \
        -w "%{http_code}" \
        -D "$JOB_HEADERS_FILE" \
        -o "$JOB_RESPONSE_FILE" \
        -H "accept: application/json" \
        -H "Authorization: Bearer ${BEARER_TOKEN}")

    cat "$JOB_HEADERS_FILE"
    cat "$JOB_RESPONSE_FILE"

    if [ "$HTTP_CODE" == 403 ]; then
        # If response is unauthorized refresh token and try again
        echo "Token expired. Refreshing and then attempting to check status again"
        BEARER_TOKEN="$(fn_get_token "$IDP_URL" "$AUTH_FILE")"
    elif [ "$HTTP_CODE" != 202 ] && [ "$HTTP_CODE" != 200 ]; then
        echo "Error making rest call. Status code: $HTTP_CODE"
        exit 1
    else
        JOB_JSON="$(grep ExplanationOfBenefit "$JOB_RESPONSE_FILE")"
    fi
done

echo "Saved response to $JOB_RESPONSE_FILE"

# ------ Download results for job
echo "Downloading results for job"

URLS="$(echo "$JOB_JSON" | jq --raw-output ".output[].url")"
echo "List of files to download: $URLS"
FILE_DOWNLOAD_HEADERS="$DIRECTORY/file_download_headers.txt"
COUNTER=0

for URL in $URLS; do
    FILE_NAME="$DIRECTORY/$(echo "$URL" | sed 's/.*.file.//')"

    echo "Downloading file to $FILE_NAME from $URL"

    if [ -f "$FILE_NAME" ]; then
        echo "$FILE_NAME already exists, skipping"
    else
        while true; do
            HTTP_CODE=$(curl "$URL" \
                -w "%{http_code}" \
                -o "$FILE_NAME" \
                -D "$FILE_DOWNLOAD_HEADERS" \
                -H "Accept: application/fhir+json" \
                -H "Authorization: Bearer ${BEARER_TOKEN}")

            if [ "$HTTP_CODE" == 403 ]; then
                # If response is unauthorized refresh token and try again
                echo "Bearer token expired. Refreshing, then attempting to download again"
                BEARER_TOKEN="$(fn_get_token "$IDP_URL" "$AUTH_FILE")"
            elif [ "$HTTP_CODE" != 200 ]; then
                echo "Error downloading file. Status code: $HTTP_CODE"
                cat "$FILE_DOWNLOAD_HEADERS"
                cat "$FILE_NAME"
                break
            else
                COUNTER=$(( COUNTER +1 ))
                break
            fi
        done
    fi
done

echo "Done. Total number of files downloaded: $COUNTER"
