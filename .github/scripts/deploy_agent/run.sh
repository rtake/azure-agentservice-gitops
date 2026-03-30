#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load shared building blocks in dependency order so each layer can focus on one concern.
source "${script_dir}/env.sh"
source "${script_dir}/utils.sh"
source "${script_dir}/http.sh"
source "${script_dir}/payloads.sh"
source "${script_dir}/commands.sh"

command_name="${1:-}"

if [ -z "$command_name" ]; then
  echo "Usage: $0 <collect-agents|deploy-models|deploy-agent-infra>" >&2
  exit 1
fi

case "$command_name" in
  collect-agents)
    collect_agents
    ;;
  deploy-models)
    deploy_models
    ;;
  deploy-agent-infra)
    deploy_agent_infra
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    exit 1
    ;;
esac
