param accountName string
param deploymentName string
param modelName string
param modelFormat string = 'OpenAI'
param modelVersion string = ''
param modelPublisher string = ''
param skuName string = 'Standard'
param skuCapacity int = 1
param deploymentState string = 'Running'
param serviceTier string = 'Default'
param versionUpgradeOption string = 'OnceNewDefaultVersionAvailable'

var deploymentModel = union(
  {
    format: modelFormat
    name: modelName
  },
  empty(modelVersion) ? {} : {
    version: modelVersion
  },
  empty(modelPublisher) ? {} : {
    publisher: modelPublisher
  }
)

resource account 'Microsoft.CognitiveServices/accounts@2025-10-01-preview' existing = {
  name: accountName
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-10-01-preview' = {
  parent: account
  name: deploymentName
  sku: {
    name: skuName
    capacity: skuCapacity
  }
  properties: {
    model: deploymentModel
    deploymentState: deploymentState
    serviceTier: serviceTier
    versionUpgradeOption: versionUpgradeOption
  }
}

output deploymentResourceId string = modelDeployment.id
