extension microsoftGraphV1

@description('Unique name for the Microsoft Entra application used by the secure webhook.')
param applicationUniqueName string

@description('Display name for the Microsoft Entra application used by the secure webhook.')
param applicationDisplayName string

@description('Optional owner object ID for the Microsoft Entra application.')
param ownerObjectId string = ''

@description('Application ID of the built-in Azure Monitor Action Group enterprise application.')
param actionGroupServicePrincipalAppId string = '461e8683-5575-4561-ac7f-899cc907d62a'

@description('Identifier URI accepted by the secure webhook.')
param audience string = 'api://${applicationUniqueName}'

var webhookRoleName = 'ActionGroupsSecureWebhook'
var webhookRoleId = guid(applicationUniqueName, webhookRoleName)

resource webhookApplication 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: applicationUniqueName
  displayName: applicationDisplayName
  signInAudience: 'AzureADMyOrg'
  identifierUris: [
    audience
  ]
  api: {
    requestedAccessTokenVersion: 2
  }
  appRoles: [
    {
      allowedMemberTypes: [
        'Application'
      ]
      description: '${webhookRoleName} role for secure webhook access'
      displayName: webhookRoleName
      id: webhookRoleId
      isEnabled: true
      value: webhookRoleName
    }
  ]
  owners: {
    relationshipSemantics: 'append'
    relationships: empty(ownerObjectId) ? [] : [
      ownerObjectId
    ]
  }
}

resource webhookServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = {
  appId: webhookApplication.appId
}

resource actionGroupServicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' existing = {
  appId: actionGroupServicePrincipalAppId
}

resource actionGroupWebhookRoleAssignment 'Microsoft.Graph/appRoleAssignedTo@v1.0' = {
  appRoleId: webhookRoleId
  principalId: actionGroupServicePrincipal.id
  resourceDisplayName: webhookServicePrincipal.displayName
  resourceId: webhookServicePrincipal.id
}

output clientId string = webhookApplication.appId
output objectId string = webhookApplication.id
output servicePrincipalId string = webhookServicePrincipal.id
output audience string = audience
