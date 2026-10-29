#!/usr/bin/env bash

source fn_get_token.sh

BEARER_TOKEN=$(fn_get_token "$IDP_URL" "$AUTH_FILE")
if [ "$BEARER_TOKEN" == "null" ]
then
    printf "Failed to retrieve bearer token is base64 token accurate?\nIs %s available from this computer?\n", $IDP_URL
    exit 1
fi

URLS=$(cat "$DIRECTORY/response.json" | grep ExplanationOfBenefit | jq --raw-output ".output[].url")

# Download each file by url
COUNTER=0

echo "List of files to download $URLS"

for URL in ${URLS}
do
    FILE_NAME="$DIRECTORY"/$(echo ${URL} | sed 's/.*.file.//')
    ACCEPT_ENCODING='identity'

    if [ "$AB2D_USE_GZIP" = 'true' ]
    then
      FILE_NAME="$FILE_NAME.gz"
      ACCEPT_ENCODING='gzip'
    fi

    echo "$URL"

    if [ -f "$FILE_NAME" ]
    then
        echo "$FILE_NAME already exists, skipping"
    else
        HTTP_CODE=$(curl --header "Accept: application/fhir+ndjson" \
          --header "Accept-Encoding: $ACCEPT_ENCODING" \
          --header "Authorization: Bearer ${BEARER_TOKEN}" \
          -w "%{http_code}" \
          -o "$FILE_NAME" \
          "$URL")

        if [ "$HTTP_CODE" != 200 ]
        then
            echo "Error downloading file. Status code: $HTTP_CODE"
            cat "$FILE_NAME"
            echo
            # Remove the error body so a re-run does not mistake it for a downloaded file
            rm -f "$FILE_NAME"

            if [ "$HTTP_CODE" == 403 ] && [ "$AB2D_ENDPOINT" == "v3" ]
            then
                echo "A 403 here usually means V3 access has not been enabled for this contract yet. Contact the AB2D team."
            fi
        else
            COUNTER=$(( COUNTER +1 ))
        fi

        echo "Updating bearer token"
        BEARER_TOKEN=$(fn_get_token "$IDP_URL" "$AUTH_FILE")
    fi
done

echo "Done. Total number of files downloaded: $COUNTER"