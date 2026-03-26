#!/usr/bin/env bash

build_agent_create_body() {
  local agent_name="$1"
  local agent_file="$2"

  jq -n \
    --arg name "$agent_name" \
    --slurpfile def "$agent_file" \
    '{
      name: $name,
      definition: $def[0]
    }'
}

build_agent_update_body() {
  local agent_file="$1"

  jq -n \
    --slurpfile def "$agent_file" \
    '{
      definition: $def[0]
    }'
}

build_agent_state() {
  local agent_name="$1"
  local agent_file="$2"
  local agent_id="$3"
  local agent_version="$4"
  local deployment_name="$5"
  local model_deployment_name="$6"
  local model_name="$7"
  local model_format="$8"
  local model_version="$9"
  local model_publisher="${10}"
  local sku_name="${11}"
  local sku_capacity="${12}"
  local deployment_state="${13}"
  local service_tier="${14}"
  local version_upgrade_option="${15}"

  jq -c -n \
    --arg agentName "$agent_name" \
    --arg agentFile "$agent_file" \
    --arg agentId "$agent_id" \
    --arg agentVersion "$agent_version" \
    --arg deploymentName "$deployment_name" \
    --arg modelDeploymentName "$model_deployment_name" \
    --arg modelName "$model_name" \
    --arg modelFormat "$model_format" \
    --arg modelVersion "$model_version" \
    --arg modelPublisher "$model_publisher" \
    --arg skuName "$sku_name" \
    --arg deploymentState "$deployment_state" \
    --arg serviceTier "$service_tier" \
    --arg versionUpgradeOption "$version_upgrade_option" \
    --argjson skuCapacity "$sku_capacity" \
    '{
      agentName: $agentName,
      agentFile: $agentFile,
      agentId: $agentId,
      agentVersion: $agentVersion,
      deploymentName: $deploymentName,
      modelDeploymentName: $modelDeploymentName,
      modelName: $modelName,
      modelFormat: $modelFormat,
      modelVersion: $modelVersion,
      modelPublisher: $modelPublisher,
      skuName: $skuName,
      skuCapacity: $skuCapacity,
      deploymentState: $deploymentState,
      serviceTier: $serviceTier,
      versionUpgradeOption: $versionUpgradeOption
    }'
}
