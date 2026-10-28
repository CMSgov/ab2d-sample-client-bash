#!/usr/bin/env bash

if [ "$1" == "--help" ] || [ "$#" == 0 ]
then
  printf \
"Usage: \n
  run-job-v3.sh --auth <passwordfile.base64> [--directory <dir>] [--gzip]
  [--since <since>] [--until <until>] [--service-date <service-date>]\n
Arguments:\n
  --auth         -- base64 encoded \"clientid:password\"
  --directory    -- if you want files and job info saved to specific directory
  --gzip         -- if you want to download files in compressed gzip format
  --since        -- if you only want claims data updated or filed after a certain date specify this
                    parameter. The expected format is yyyy-MM-dd'T'HH:mm:ss.SSSXXX+/-ZZ:ZZ.
                    V3 has no claims data before 2026-04-01T00:00:00.000-05:00.
                    Example June 16, 2026 at midnight UTC -> 2026-06-16T00:00:00.000-00:00
  --until        -- if you only want claims data updated or filed before a certain date specify this
                    parameter. The expected format is yyyy-MM-dd'T'HH:mm:ss.SSSXXX+/-ZZ:ZZ.
                    Example July 1, 2026 at midnight UTC -> 2026-07-01T00:00:00.000-00:00
  --service-date -- V3 only. Filter claims by date of service instead of by when the claim was
                    filed or updated.
                    Example FHIR date param format is gt2026-01-01 or gt2026-01-01,lt2026-02-01\n
  The --fhir and --ab2d-endpoint arguments are not needed. V3 is FHIR R4 only, so this script
  always runs against R4 and the v3 endpoint.\n\n"

  exit 0;
fi

SERVICE_DATES=""
BOOTSTRAP_ARGS=()
while (($#)) ;
do
  case $1 in
    "--service-date")
      SERVICE_DATES=$2
      shift
      ;;
    *)
      BOOTSTRAP_ARGS+=("$1")
      ;;
  esac
  shift
done

source bootstrap.sh "${BOOTSTRAP_ARGS[@]}" --fhir R4 --ab2d-endpoint v3

echo "Using okta url: $IDP_URL"
echo "Connecting to AB2D API at: $API_URL"
echo "Saving data to: $DIRECTORY"
echo "FHIR Version: $FHIR_VERSION (AB2D endpoint $AB2D_ENDPOINT)"

V3_EARLIEST_SINCE_DATE="2026-04-01"

if [ "$SINCE" != '' ] && [[ "${SINCE:0:10}" < "$V3_EARLIEST_SINCE_DATE" ]]
then
  echo "Warning: V3 has no claims data before ${V3_EARLIEST_SINCE_DATE}. The API will reject this _since value."
fi

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

# If a since date is provided
if [ "$SINCE" != '' ]; then
  URL="$URL&_since=$SINCE"
fi

# If an until date is provided
if [ "$UNTIL" != '' ]; then
  URL="$URL&_until=$UNTIL"
fi

if [ "$SERVICE_DATES" != '' ]; then
  TYPE_FILTER="ExplanationOfBenefit?service-date=$(echo "$SERVICE_DATES" | sed 's/,/\&service-date=/g')"

  TYPE_FILTER=$(echo "$TYPE_FILTER" | sed -e 's/%/%25/g' -e 's/?/%3F/g' -e 's/=/%3D/g' \
      -e 's/&/%26/g' -e 's/:/%3A/g' -e 's/+/%2B/g')

  URL="$URL&_typeFilter=$TYPE_FILTER"
fi

echo "Attempting to start job using $URL"

PATIENT_HEADERS_FILE="$DIRECTORY/patient_headers.txt"
PATIENT_RESPONSE_FILE="$DIRECTORY/patient_response.txt"
HTTP_CODE=$(curl "$URL" \
    -s \
    -w "%{http_code}" \
    -D "$PATIENT_HEADERS_FILE" \
    -o "$PATIENT_RESPONSE_FILE" \
    -H "accept: application/json" \
    -H "Accept: application/fhir+json" \
    -H "Prefer: respond-async" \
    -H "Authorization: Bearer ${BEARER_TOKEN}")

cat "$PATIENT_HEADERS_FILE"

if [ "$HTTP_CODE" != 202 ]
then
    echo "Could not export job. Status code: $HTTP_CODE"

    if [ -f "$PATIENT_RESPONSE_FILE" ]
    then
      cat "$PATIENT_RESPONSE_FILE"
      echo  # Add newline after response output
    fi

    if [ "$HTTP_CODE" == 403 ]
    then
      echo "A 403 here usually means V3 access has not been enabled for this contract yet. Contact the AB2D team."
    fi

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
# V3 answers both an expired token and a contract without V3 access with a 403, so give up on a
# 403 that a fresh token did not fix rather than refreshing forever.
FORBIDDEN_COUNT=0

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
    echo  # Add newline after response output

    if [ "$HTTP_CODE" == 403 ]; then
        FORBIDDEN_COUNT=$(( FORBIDDEN_COUNT +1 ))

        if [ "$FORBIDDEN_COUNT" -gt 1 ]; then
            echo "Still forbidden after refreshing the token. V3 access may not be enabled for this contract."
            exit 1
        fi

        # If response is unauthorized refresh token and try again
        echo "Token expired. Refreshing and then attempting to check status again"
        BEARER_TOKEN="$(fn_get_token "$IDP_URL" "$AUTH_FILE")"
    elif [ "$HTTP_CODE" != 202 ] && [ "$HTTP_CODE" != 200 ]; then
        echo "Error making rest call. Status code: $HTTP_CODE"
        exit 1
    else
        FORBIDDEN_COUNT=0
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

ACCEPT_ENCODING='identity'
if [ "$AB2D_USE_GZIP" == 'true' ]; then
    ACCEPT_ENCODING='gzip'
fi

for URL in $URLS; do
    FILE_NAME="$DIRECTORY/$(echo "$URL" | sed 's/.*.file.//')"

    if [ "$AB2D_USE_GZIP" == 'true' ]; then
        FILE_NAME="$FILE_NAME.gz"
    fi

    echo "Downloading file to $FILE_NAME from $URL"

    if [ -f "$FILE_NAME" ]; then
        echo "$FILE_NAME already exists, skipping"
    else
        FORBIDDEN_COUNT=0

        while true; do
            HTTP_CODE=$(curl "$URL" \
                -w "%{http_code}" \
                -o "$FILE_NAME" \
                -D "$FILE_DOWNLOAD_HEADERS" \
                -H "Accept: application/fhir+ndjson" \
                -H "Accept-Encoding: $ACCEPT_ENCODING" \
                -H "Authorization: Bearer ${BEARER_TOKEN}")

            if [ "$HTTP_CODE" == 403 ]; then
                FORBIDDEN_COUNT=$(( FORBIDDEN_COUNT +1 ))

                if [ "$FORBIDDEN_COUNT" -gt 1 ]; then
                    echo "Still forbidden after refreshing the token. V3 access may not be enabled for this contract."
                    cat "$FILE_DOWNLOAD_HEADERS"
                    break 2
                fi

                # If response is unauthorized refresh token and try again
                echo "Bearer token expired. Refreshing, then attempting to download again"
                BEARER_TOKEN="$(fn_get_token "$IDP_URL" "$AUTH_FILE")"
            elif [ "$HTTP_CODE" != 200 ]; then
                echo "Error downloading file. Status code: $HTTP_CODE"
                cat "$FILE_DOWNLOAD_HEADERS"
                cat "$FILE_NAME"
                # Remove the error body so a re-run does not mistake it for a downloaded file
                rm -f "$FILE_NAME"
                break
            else
                COUNTER=$(( COUNTER +1 ))
                break
            fi
        done
    fi
done

echo "Done. Total number of files downloaded: $COUNTER"
