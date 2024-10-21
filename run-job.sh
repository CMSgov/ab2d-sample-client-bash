#!/usr/bin/env bash

# the -e flag tells the script to exit if any of its commands exit with a non zero code.
# For instance, if any of the subscripts exit with a 1 (like if we fail to export a job)
# we should exit this script automatically. 
set -e

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

echo "Starting job"

./start-job.sh

echo "Monitoring job"

./monitor-job.sh

echo "Download results for job"

./download-results.sh

