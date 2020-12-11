#!/usr/bin/env bash

fn_get_token()
{
  IDP_URL=$1
  AUTH_FILE=$2

  # Load credentials for retrieving bearer token
  if [[  -f "$AUTH_FILE" ]]; then
      TOKEN=$(cat "$AUTH_FILE")
  else
      echo "Auth token file does not exist"
  fi

  BEARER_TOKEN=$(curl -X POST "$IDP_URL?grant_type=client_credentials&scope=clientCreds" \
      -H "Content-Type: application/x-www-form-urlencoded" \
      -H "Accept: application/json" \
      -H "Authorization: Basic ${TOKEN}" | jq --raw-output ".access_token")

  echo "$BEARER_TOKEN"
}