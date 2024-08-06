#!/usr/bin/env bash

if [ "$1" == "--help" ]
then
  printf \
"Usage: \n
  <command> (-prod | -sandbox) --auth <passwordfile.base64> [--directory <dir>] [--since <since>] [--until <until>] --fhir (R4 | STU3)\n
Arguments:\n
  -sandbox    -- if running against ab2d sandbox environment
  -prod       -- if running against ab2d production environment
  --auth      -- base64 encoded \"clientid:password\"
  --directory -- if you want files and job info saved to specific directory
  --since     -- if you only want claims data updated or filed after a certain date specify this parameter.
                 The expected format is yyyy-MM-dd'T'HH:mm:ss.SSSXXX+/-ZZ:ZZ.
                 Example March 1, 2020 at 3 PM EST -> 2020-03-01T15:00:00.000-05:00
  --until     -- if you only want claims data updated or filed before a certain date specify this parameter.
                 This parameter is only available with version 2 (FHIR R4) of the API.
                 The expected format is yyyy-MM-dd'T'HH:mm:ss.SSSXXX+/-ZZ:ZZ.
                 Example March 1, 2024 at 3 PM EST -> 2024-03-01T15:00:00.000-05:00
  --fhir      -- The FHIR version\n\n"
  exit 0;
fi

# Process command line args
DIRECTORY=$(pwd)
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
    "--directory")
      DIRECTORY=$2
      shift
      ;;
    "--since")
      export SINCE=$(echo "$2" | sed "s/:/%3A/g")
      shift
      ;;
    "--until")
      export UNTIL=$(echo "$2" | sed "s/:/%3A/g")
      shift
      ;;
    "--fhir")
      export FHIR_VERSION=$2
      shift
      ;;
  esac
  shift
done

error=false
if [ "$AUTH_FILE" == "" ]
then
  error=true
  printf "The auth information must be specified --auth passwordfile.base64\n"
fi
if [ "${FHIR_VERSION}" == "" ]
then
  error=true
  printf "The FHIR version must be specified --fhir [R4 | STU3]\n"
fi
if [ "${FHIR_VERSION}" == "STU3" ] && [ "${UNTIL}" != "" ]
then
  error=true
  printf "The _until parameter is only available with version 2 (FHIR R4) of the API\n"
fi
if [ "${error}" == true ]
then
  exit 1
fi

if [ "${FHIR_VERSION}" == "R4" ]
then
  export API_URL="${API_URL_PT1}v2/fhir"
else
  export API_URL="${API_URL_PT1}v1/fhir"
fi

export DIRECTORY="$DIRECTORY"