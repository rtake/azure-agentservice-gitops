#!/usr/bin/env bash

readonly AIFOUNDRY_ACCOUNT_NAME="${AIFOUNDRY_ACCOUNT_NAME:?AIFOUNDRY_ACCOUNT_NAME is required}"
readonly RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:?RESOURCE_GROUP_NAME is required}"
readonly PROJECT_NAME="${PROJECT_NAME:?PROJECT_NAME is required}"
readonly MODEL_CONFIG_FILE="${MODEL_CONFIG_FILE:-azure/infra/model-config.json}"

foundry_base_url() {
  printf 'https://%s.services.ai.azure.com' "$AIFOUNDRY_ACCOUNT_NAME"
}
