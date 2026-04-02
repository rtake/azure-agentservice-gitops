#!/bin/bash
set -euo pipefail

# App registration: existing app is reused by az ad app create
APP_NAME="github-workflow-function-app"

APP_ID=$(az ad app create \
  --display-name "$APP_NAME" \
  --query appId -o tsv)

echo "appId: $APP_ID"

## Add owner
APP_OBJECT_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)
echo "app object id: $APP_OBJECT_ID"

### Prefer signed-in user if available; otherwise fall back to the current service principal.
OWNER_OBJECT_ID=""
if OWNER_OBJECT_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null); then
  echo "owner object id (signed-in user): $OWNER_OBJECT_ID"
else
  if [ -n "${AZURE_CLIENT_ID:-}" ]; then
    OWNER_OBJECT_ID=$(az ad sp show --id "$AZURE_CLIENT_ID" --query id -o tsv)
    echo "owner object id (service principal): $OWNER_OBJECT_ID"
  else
    echo "Could not determine owner object id." >&2
    exit 1
  fi
fi

### Avoid duplicate owner assignment.
EXISTING_OWNER_COUNT=$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/applications/$APP_OBJECT_ID/owners/\$ref" \
  --query "value[?id=='$OWNER_OBJECT_ID'] | length(@)" -o tsv 2>/dev/null)
echo "existing owner count: $EXISTING_OWNER_COUNT"

if [ "$EXISTING_OWNER_COUNT" -eq 0 ]; then
  az rest --method POST \
    --uri "https://graph.microsoft.com/v1.0/applications/$APP_OBJECT_ID/owners/\$ref" \
    --headers "Content-Type=application/json" \
    --body "{
      \"@odata.id\": \"https://graph.microsoft.com/v1.0/directoryObjects/$OWNER_OBJECT_ID\"
    }"
  echo "Owner added."
else
  echo "Owner already assigned. Skipping."
fi

## API exposure
APP_JSON=$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='$APP_ID')" \
  -o json)

UPDATED_BODY=$(printf '%s' "$APP_JSON" | jq -c \
  --arg identifier_uri "api://$APP_ID" '
{
  api: (
    .api
    | .requestedAccessTokenVersion = 2
  ),
  identifierUris: [$identifier_uri]
}')

az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='$APP_ID')" \
  --headers "Content-Type=application/json" \
  --body "$UPDATED_BODY"

echo "API identifier URI set to api://$APP_ID"

## Ensure service principal exists for the app
if ! az ad sp show --id "$APP_ID" >/dev/null 2>&1; then
  az ad sp create --id "$APP_ID" >/dev/null
fi

# Create or update app role
## Deterministic app role ID
ROLE_NAMESPACE="00000000-0000-0000-0000-000000000000" # dummy, namespace は UUID 形式であれば何でも良い
ROLE_NAME="ActionGroupsSecureWebhook"
ROLE_VALUE="ActionGroupsSecureWebhook"

ROLE_ID=$(ROLE_NAMESPACE="$ROLE_NAMESPACE" ROLE_NAME="$ROLE_NAME" python3 - <<'PY'
import os
import uuid

print(uuid.uuid5(
    uuid.UUID(os.environ["ROLE_NAMESPACE"]),
    os.environ["ROLE_NAME"],
))
PY
)
echo "roleId: $ROLE_ID"

## Assign app role to the app registration
### If this step fails, manually disable the app role in Azure Portal
APP_JSON=$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='$APP_ID')" \
  -o json)

UPDATED_BODY=$(printf '%s' "$APP_JSON" | jq -c \
  --arg role_id "$ROLE_ID" \
  --arg role_name "$ROLE_NAME" \
  --arg role_value "$ROLE_VALUE" '
{
  appRoles: (
    (.appRoles // [])
    | map(select(.id != $role_id and .value != $role_value))
    + [
      {
        allowedMemberTypes: ["Application"],
        description: ($role_name + " role for secure webhook access"),
        displayName: $role_name,
        id: $role_id,
        isEnabled: true,
        value: $role_value
      }
    ]
  )
}
')

az rest --method PATCH \
  --uri "https://graph.microsoft.com/v1.0/applications(appId='$APP_ID')" \
  --headers "Content-Type=application/json" \
  --body "$UPDATED_BODY"

# Assign app role to the target enterprise application (service principal)
TARGET_SP_APP_ID="461e8683-5575-4561-ac7f-899cc907d62a" # App ID for Action Group

TARGET_SP_OBJECT_ID=$(az ad sp show \
  --id "$TARGET_SP_APP_ID" \
  --query id -o tsv)

RESOURCE_SP_OBJECT_ID=$(az ad sp show \
  --id "$APP_ID" \
  --query id -o tsv)

EXISTING=$(az rest --method GET \
  --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$TARGET_SP_OBJECT_ID/appRoleAssignments" \
  --query "value[?resourceId=='$RESOURCE_SP_OBJECT_ID' && appRoleId=='$ROLE_ID'] | length(@)" \
  -o tsv)

if [ "$EXISTING" -eq 0 ]; then
  echo "Assigning app role..."

  az rest --method POST \
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$TARGET_SP_OBJECT_ID/appRoleAssignments" \
    --headers "Content-Type=application/json" \
    --body "{
      \"principalId\": \"$TARGET_SP_OBJECT_ID\",
      \"resourceId\": \"$RESOURCE_SP_OBJECT_ID\",
      \"appRoleId\": \"$ROLE_ID\"
    }"
else
  echo "App role already assigned. Skipping."
fi