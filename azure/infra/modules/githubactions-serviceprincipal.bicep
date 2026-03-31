param resourceToken string
param location string = resourceGroup().location
param githubOwner string
param githubRepo string
param subject string = 'repo:${githubOwner}/${githubRepo}:ref:refs/heads/main'

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${resourceToken}'
  location: location
}

resource fic 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2025-01-31-preview' = {
  parent: uami
  name: 'github-main'
  properties: {
    audiences: [
      'api://AzureADTokenExchange'
    ]
    issuer: 'https://token.actions.githubusercontent.com'
    subject: subject
  }
}

output id string = uami.id
output principalId string = uami.properties.principalId
