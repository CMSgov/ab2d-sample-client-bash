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