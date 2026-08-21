#!/usr/bin/env bash

source fn_get_token.sh

if [ "$1" == "--help" ] || [ "$#" == 0 ]
then
  printf \
"Usage: \n
  download-results-v3.sh --auth <passwordfile.base64> --contract <contract>
  --jobid <jobid> [--directory <dir>]\n
  Arguments:\n
    --auth      -- base64 encoded \"clientid:password\"
    --contract  -- contract number
    --jobid     -- job id
    --directory -- if you want files saved to specific directory"
  exit 0;
fi

# Process command line args
DIRECTORY=$(pwd)
IDP_URL="https://idm.cms.gov/oauth2/aus2ytanytjdaF9cr297/v1/token"
API_URL="https://api.ab2d.cms.gov/api/v3/fhir"

while (($#)) ;
do
  case $1 in
     "--auth")
        export AUTH_FILE=$2
        shift
        ;;
      "--contract")
        CONTRACT=$2_
        shift
        ;;
      "--jobid")
        JOB_ID=$2
        shift
        ;;
     "--directory")
        DIRECTORY=$2
        shift
        ;;
  esac
  shift
done

ERROR=false
if [ "$AUTH_FILE" == "" ]
then
  ERROR=true
  printf "The auth information must be specified --auth passwordfile.base64\n"
fi
if [ "$JOB_ID" == "" ]
then
  ERROR=true
  printf "The job id must be specified --jobid <jobid>\n"
fi
if [ "$CONTRACT" == "" ]
then
  ERROR=true
  printf "The contract must be specified --contract <contract_number>\n"
fi
if [ "$ERROR" == "true" ]
then
  exit 1
fi

echo "Using okta url: $IDP_URL"
echo "Connecting to AB2D API at: $API_URL"
echo "Saving data to: $DIRECTORY"

BEARER_TOKEN=$(fn_get_token "$IDP_URL" "$AUTH_FILE")
if [ "$BEARER_TOKEN" == "null" ]
then
    printf "Failed to retrieve bearer token is base64 token accurate?\nIs %s available from this computer?\n", $IDP_URL
    exit 1
fi

echo "Downloading results for job: $JOB_ID"

FILE_DOWNLOAD_HEADERS="$DIRECTORY/file_download_headers.txt"
COMMON_URL="$API_URL/Job/$JOB_ID/file"

COUNTER=0

for i in $(seq -w 1 1000);
do
    FILE_NAME="$DIRECTORY/$CONTRACT$i.ndjson.gz"
    URL="$COMMON_URL/$CONTRACT$i.ndjson"

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
                    -H "Accept-Encoding: gzip" \
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
                elif [[ "$HTTP_CODE" == 404 || "$HTTP_CODE" == 500 ]]; then
                    rm -f "$FILE_NAME"
                    echo "No more files to download"
                    break 2
                elif [ "$HTTP_CODE" != 200 ]; then
                    echo "Error downloading file. Status code: $HTTP_CODE"
                    cat "$FILE_DOWNLOAD_HEADERS"
                    cat "$FILE_NAME"
                    rm -f "$FILE_NAME"
                    break 2
                else
                    COUNTER=$(( COUNTER +1 ))
                    break
                fi
        done
    fi
done
find "$DIRECTORY" -size 0 -delete
echo "Done. Total number of files downloaded: $COUNTER"
