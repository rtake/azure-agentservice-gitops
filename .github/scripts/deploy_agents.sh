#!/usr/bin/env bash

set -euo pipefail

command_name="${1:-}"

if [ -z "$command_name" ]; then
  echo "Usage: $0 <collect-agents|upsert-applications|create-deployments|link-deployments>" >&2
  exit 1
fi

readonly SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:?AZURE_SUBSCRIPTION_ID is required}"
readonly AIFOUNDRY_ACCOUNT_NAME="${AIFOUNDRY_ACCOUNT_NAME:?AIFOUNDRY_ACCOUNT_NAME is required}"
readonly RESOURCE_GROUP_NAME="${RESOURCE_GROUP_NAME:?RESOURCE_GROUP_NAME is required}"
readonly PROJECT_NAME="${PROJECT_NAME:?PROJECT_NAME is required}"
readonly API_VERSION="${API_VERSION:?API_VERSION is required}"

foundry_base_url() {
  printf 'https://%s.services.ai.azure.com' "$AIFOUNDRY_ACCOUNT_NAME"
}

arm_base_url() {
  printf 'https://management.azure.com/subscriptions/%s/resourceGroups/%s/providers/Microsoft.CognitiveServices/accounts/%s/projects/%s' \
    "$SUBSCRIPTION_ID" \
    "$RESOURCE_GROUP_NAME" \
    "$AIFOUNDRY_ACCOUNT_NAME" \
    "$PROJECT_NAME"
}

application_url() {
  local app_name="$1"
  printf '%s/applications/%s?api-version=%s' "$(arm_base_url)" "$app_name" "$API_VERSION"
}

deployment_url() {
  local app_name="$1"
  printf '%s/applications/%s/agentDeployments/%s?api-version=%s' "$(arm_base_url)" "$app_name" "$app_name" "$API_VERSION"
}

fallback_deployment_id() {
  local app_name="$1"
  local deployment_name="$2"
  printf '/subscriptions/%s/resourceGroups/%s/providers/Microsoft.CognitiveServices/accounts/%s/projects/%s/applications/%s/agentDeployments/%s' \
    "$SUBSCRIPTION_ID" \
    "$RESOURCE_GROUP_NAME" \
    "$AIFOUNDRY_ACCOUNT_NAME" \
    "$PROJECT_NAME" \
    "$app_name" \
    "$deployment_name"
}

agent_file_to_name() {
  local agent_file="$1"
  basename "$agent_file" .json
}

agent_field() {
  local agent_json="$1"
  local field_name="$2"
  jq -r --arg field "$field_name" '.[$field]' <<< "$agent_json"
}

log_response() {
  local label="$1"
  local response="$2"
  echo "${label}: ${response}"
}

write_output_json() {
  local output_name="$1"
  local output_value="$2"

  {
    echo "${output_name}<<EOF"
    echo "$output_value"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"
}

append_agent() {
  local current_json="$1"
  local agent_json="$2"
  jq -c --argjson item "$agent_json" '. + [$item]' <<< "$current_json"
}

require_json_field() {
  local json_payload="$1"
  local jq_filter="$2"
  local error_message="$3"
  local value

  value=$(jq -r "$jq_filter" <<< "$json_payload")
  if [ -z "$value" ] || [ "$value" = "null" ]; then
    echo "$error_message"
    echo "$json_payload"
    exit 1
  fi

  printf '%s' "$value"
}

put_json() {
  local url="$1"
  local token="$2"
  local body="$3"

  curl --fail-with-body --silent --show-error \
    -X PUT \
    "$url" \
    -H "Authorization: Bearer ${token}" \
    -H "Content-Type: application/json" \
    -d "$body"
}

collect_agents() {
  local files="${FILES:-}"
  local foundry_token="${FOUNDRY_TOKEN:?FOUNDRY_TOKEN is required}"
  local agents_json

  agents_json=$(jq -cn '[]')

  while IFS= read -r agent_file; do
    [ -z "$agent_file" ] && continue

    local agent_name get_url get_response status agent_response create_body update_body
    local agent_id agent_version safe_agent_version app_name deployment_name agent_state

    agent_name=$(agent_file_to_name "$agent_file")
    echo "=== Processing ${agent_name} ==="

    get_url="$(foundry_base_url)/api/projects/${PROJECT_NAME}/agents/${agent_name}?api-version=v1"
    get_response=$(curl --silent --show-error \
      -w "%{http_code}" \
      -H "Authorization: Bearer ${foundry_token}" \
      "$get_url" || true)
    status="${get_response: -3}"
    agent_response="${get_response%???}"

    if [ "$status" = "404" ]; then
      echo "Creating agent ${PROJECT_NAME}/${agent_name}"
      create_body=$(jq -n \
        --arg name "$agent_name" \
        --slurpfile def "$agent_file" \
        '{
          name: $name,
          definition: $def[0]
        }')
      agent_response=$(
        curl --fail-with-body --silent --show-error \
          -X POST \
          "$(foundry_base_url)/api/projects/${PROJECT_NAME}/agents?api-version=v1" \
          -H "Authorization: Bearer ${foundry_token}" \
          -H "Content-Type: application/json" \
          -d "$create_body"
      )
    elif [ "$status" = "200" ]; then
      echo "Updating agent ${PROJECT_NAME}/${agent_name}"
      update_body=$(jq -n \
        --slurpfile def "$agent_file" \
        '{
          definition: $def[0]
        }')
      agent_response=$(
        curl --fail-with-body --silent --show-error \
          -X POST \
          "$(foundry_base_url)/api/projects/${PROJECT_NAME}/agents/${agent_name}?api-version=v1" \
          -H "Authorization: Bearer ${foundry_token}" \
          -H "Content-Type: application/json" \
          -d "$update_body"
      )
    else
      echo "Failed to check existing agent ${PROJECT_NAME}/${agent_name}: HTTP ${status}"
      [ -n "$agent_response" ] && echo "$agent_response"
      exit 1
    fi

    log_response "Agent response" "$agent_response"

    agent_id=$(require_json_field "$agent_response" '.id' "Failed to resolve agent id")
    agent_version=$(require_json_field "$agent_response" '.versions.latest.version' "Failed to resolve agent version")
    safe_agent_version=$(printf '%s' "$agent_version" | tr -c '[:alnum:]-' '-')
    app_name="$agent_name"
    deployment_name="v-${safe_agent_version}"

    agent_state=$(jq -c -n \
      --arg agentName "$agent_name" \
      --arg agentFile "$agent_file" \
      --arg agentId "$agent_id" \
      --arg agentVersion "$agent_version" \
      --arg appName "$app_name" \
      --arg deploymentName "$deployment_name" \
      '{
        agentName: $agentName,
        agentFile: $agentFile,
        agentId: $agentId,
        agentVersion: $agentVersion,
        appName: $appName,
        deploymentName: $deploymentName
      }')

    agents_json=$(append_agent "$agents_json" "$agent_state")
  done <<< "$files"

  write_output_json "agents" "$agents_json"
}

upsert_applications() {
  local agents="${AGENTS:?AGENTS is required}"
  local arm_token="${ARM_TOKEN:?ARM_TOKEN is required}"

  while IFS= read -r agent; do
    local agent_name agent_id app_name app_body app_response

    agent_name=$(agent_field "$agent" "agentName")
    agent_id=$(agent_field "$agent" "agentId")
    app_name=$(agent_field "$agent" "appName")

    echo "=== Creating or updating application ${app_name} ==="

    app_body=$(jq -n \
      --arg displayName "$agent_name" \
      --arg description "Published agent application for ${agent_name}" \
      --arg agentId "$agent_id" \
      --arg agentName "$agent_name" \
      '{
        properties: {
          agents: [
            {
              agentId: $agentId,
              agentName: $agentName
            }
          ],
          displayName: $displayName,
          description: $description
        }
      }')

    app_response=$(put_json "$(application_url "$app_name")" "$arm_token" "$app_body")
    log_response "Application response" "$app_response"
  done < <(jq -c '.[]' <<< "$agents")
}

create_deployments() {
  local agents="${AGENTS:?AGENTS is required}"
  local arm_token="${ARM_TOKEN:?ARM_TOKEN is required}"
  local deployed_agents_json

  deployed_agents_json=$(jq -cn '[]')

  while IFS= read -r agent; do
    local agent_name agent_version app_name deployment_name deploy_body deploy_response deployment_id deployed_agent

    agent_name=$(agent_field "$agent" "agentName")
    agent_version=$(agent_field "$agent" "agentVersion")
    app_name=$(agent_field "$agent" "appName")
    deployment_name=$(agent_field "$agent" "deploymentName")

    echo "=== Creating deployment for ${app_name} ==="

    deploy_body=$(jq -n \
      --arg agentName "$agent_name" \
      --arg agentVersion "$agent_version" \
      --arg displayName "${agent_name} deployment" \
      '{
        properties: {
          agents: [
            {
              agentName: $agentName,
              agentVersion: $agentVersion
            }
          ],
          deploymentType: "Managed",
          displayName: $displayName,
          protocols: [
            {
              protocol: "Responses",
              version: "1.0"
            }
          ],
          state: "Starting"
        }
      }')

    deploy_response=$(put_json "$(deployment_url "$app_name")" "$arm_token" "$deploy_body")
    log_response "Deployment response" "$deploy_response"

    deployment_id=$(jq -r '.properties.deploymentId' <<< "$deploy_response")
    if [ -z "$deployment_id" ] || [ "$deployment_id" = "null" ]; then
      deployment_id=$(fallback_deployment_id "$app_name" "$deployment_name")
    fi

    deployed_agent=$(jq -c \
      --arg deploymentId "$deployment_id" \
      '. + { deploymentId: $deploymentId }' \
      <<< "$agent")

    deployed_agents_json=$(append_agent "$deployed_agents_json" "$deployed_agent")
  done < <(jq -c '.[]' <<< "$agents")

  write_output_json "agents" "$deployed_agents_json"
}

link_deployments() {
  local agents="${AGENTS:?AGENTS is required}"
  local arm_token="${ARM_TOKEN:?ARM_TOKEN is required}"

  while IFS= read -r agent; do
    local agent_name agent_id app_name deployment_id app_link_body app_link_response

    agent_name=$(agent_field "$agent" "agentName")
    agent_id=$(agent_field "$agent" "agentId")
    app_name=$(agent_field "$agent" "appName")
    deployment_id=$(agent_field "$agent" "deploymentId")

    echo "=== Linking deployment for ${app_name} ==="

    app_link_body=$(jq -n \
      --arg displayName "$agent_name" \
      --arg description "Published agent application for ${agent_name}" \
      --arg agentId "$agent_id" \
      --arg agentName "$agent_name" \
      --arg deploymentId "$deployment_id" \
      '{
        properties: {
          agents: [
            {
              agentId: $agentId,
              agentName: $agentName
            }
          ],
          displayName: $displayName,
          description: $description,
          authorizationPolicy: {
            authorizationScheme: "Default"
          },
          trafficRoutingPolicy: {
            protocol: "FixedRatio",
            rules: [
              {
                ruleId: "default",
                description: "Default rule routing all traffic to the first deployment",
                deploymentId: $deploymentId,
                trafficPercentage: 100
              }
            ]
          }
        }
      }')

    app_link_response=$(put_json "$(application_url "$app_name")" "$arm_token" "$app_link_body")
    log_response "Application link response" "$app_link_response"
  done < <(jq -c '.[]' <<< "$agents")
}

case "$command_name" in
  collect-agents)
    collect_agents
    ;;
  upsert-applications)
    upsert_applications
    ;;
  create-deployments)
    create_deployments
    ;;
  link-deployments)
    link_deployments
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    exit 1
    ;;
esac
