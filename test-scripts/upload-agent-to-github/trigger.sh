#!/usr/bin/env bash

set -a
source .env
set +a

curl -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "x-functions-key: $FUNCTION_KEY" \
  -d @payload.json