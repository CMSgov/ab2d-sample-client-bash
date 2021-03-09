#!/usr/bin/env bash

if [ "$1" == "--help" ]
then
  printf \
"Usage: \n
  <command> (-prod | -sandbox) --auth <base64 username:password> [--contract <contract number>] [--directory <dir>] [--since <since>] [--fhir (STU3 | R4)]\n
Arguments:\n
  -sandbox    -- if running against ab2d sandbox environment
  -prod       -- if running against ab2d production environment
  --auth      -- base64 encoded \"clientid:password\"
  --contract  -- if searching specific contract then give contract number ex. Z0001
  --directory -- if you want files and job info saved to specific directory
  --since     -- if you only want claims data updated or filed after a certain date specify this parameter.
                 The expected format is yyyy-MM-dd'T'HH:mm:ss.SSSXXX+/-ZZ:ZZ.
                 Example March 1, 2020 at 3 PM EST -> 2020-03-01T15:00:00.000-05:00
  --fhir      -- if you want to specify the FHIR version (STU3 is the default)\n\n"
fi

# Process command line args
DIRECTORY=$(pwd)
# default FHIR version
export FHIR_VERSION="STU3"
while (($#)) ;
do
  case $1 in
    "-sandbox")
      export IDP_URL="https://test.idp.idm.cms.gov/oauth2/aus2r7y3gdaFMKBol297/v1/token"
      API_URL_PT1="https://sandbox.ab2d.cms.gov/api/"
      ;;
    "-prod")
      export IDP_URL="https://idm.cms.gov/oauth2/aus2ytanytjdaF9cr297/v1/token"
      API_URL_PT1="https://api.ab2d.cms.gov/api/"
      ;;
    "--auth")
      export AUTH_FILE=$2
      shift
      ;;
    "--contract")
      export CONTRACT=$2
      shift
      ;;
    "--directory")
      DIRECTORY=$2
      shift
      ;;
    "--since")
      export SINCE=$(echo "$2" | sed "s/:/%3A/g")
      shift
      ;;
    "--fhir")
      export FHIR_VERSION=$2
      shift
      ;;
  esac
  shift
done

if [ "${FHIR_VERSION}" == "R4" ]
then
  export API_URL="${API_URL_PT1}v2/fhir"
else
  export API_URL="${API_URL_PT1}v1/fhir"
fi

export DIRECTORY="$DIRECTORY"