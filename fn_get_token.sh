#!/usr/bin/env bash

fn_get_token()
{
  IDP_URL=$1
  AUTH_FILE=$2
  if [[  -f "$AUTH_FILE" ]]; then
      TOKEN=$(cat "$AUTH_FILE")
  else
      echo "Auth token file does not exist"
  fi

  if [[ "$TOKEN" == *".base64" ]]; then
    TOKEN=$(cat "$TOKEN")
  fi

  BEARER_TOKEN=$(curl -X POST "$IDP_URL?grant_type=client_credentials&scope=clientCreds" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -H "Accept: application/json" \
      -H "Authorization: Basic ${TOKEN}" | jq --raw-output ".access_token")

  echo "$BEARER_TOKEN"
}