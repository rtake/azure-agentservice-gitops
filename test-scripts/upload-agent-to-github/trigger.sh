#!/usr/bin/env bash

set -a
source .env
set +a

payload=$(jq -n \
  --arg subscriptionId "$SUBSCRIPTION_ID" \
  --arg resourceGroup "$RESOURCE_GROUP" \
  --arg accountName "$ACCOUNT_NAME" \
  --arg projectName "$PROJECT_NAME" \
  --arg appName "$APP_NAME" \
  --arg deploymentName "$DEPLOYMENT_NAME" \
  '{
    data: {
      alertContext: {
        operationName: "Microsoft.CognitiveServices/accounts/projects/applications/agentdeployments/write",
        properties: {
          entity: "/subscriptions/\($subscriptionId)/resourceGroups/\($resourceGroup)/providers/Microsoft.CognitiveServices/accounts/\($accountName)/projects/\($projectName)/applications/\($appName)/agentDeployments/\($deploymentName)",
          message: "Microsoft.CognitiveServices/accounts/projects/applications/agentdeployments/write"
        }
      }
    }
  }' \
)

response=$(curl -s -X POST "$FUNCTION_URL" \
  -H "Content-Type: application/json" \
  -H "x-functions-key: $FUNCTION_KEY" \
  -d "$payload")
echo "Response from Azure Function: $response"