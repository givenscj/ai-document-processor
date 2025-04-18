@description('Location for the Static Web App and Azure Function App. Only the following locations are allowed: centralus, eastus2, westeurope, westus2, southeastasia')
@allowed([
  'centralus'
  'eastus2'
  'westeurope'
  'westus2'
  'southeastasia'
])
param location string

@description('Location for the Azure OpenAI account')
@allowed([
  'East US'
  'East US 2'
  'France Central'
  'Germany West Central'
  'Japan East'
  'Korea Central'
  'North Central US'
  'Norway East'
  'Poland Central'
  'South Africa North'
  'South Central US'
  'South India'
  'Southeast Asia'
  'Spain Central'
  'Sweden Central'
  'Switzerland North'
  'Switzerland West'
  'UAE North'
  'UK South'
  'West Europe'
  'West US'
  'West US 3'
])
param aoaiLocation string

@description('Forked Git repository URL for the Static Web App')
param user_gh_url string = ''
param userPrincipalId string
param suffix string = uniqueString('${location}${resourceGroup().id}')
// Environment name. This is automatically set by the 'azd' tool.
@description('Environment name used as a tag for all resources. This is directly mapped to the azd-environment.')
// param environmentName string = 'dev'
param processingFunctionAppName string = 'processing-${suffix}'
param webBackendFunctionAppName string = 'webbackend-${suffix}'
param staticWebAppName string = 'static-${suffix}'
var tenantId = tenant().tenantId
param processingStorageAccountName string = 'proc${suffix}'
param webBackendStorageAccountName string = 'wb${suffix}'
param keyVaultName string = 'keyvault-${suffix}'
param aoaiName string = 'aoai-${suffix}'
param aiServicesName string = 'aiServices-${suffix}'
param cosmosAccountName string = 'cosmos-${suffix}'
param promptsContainer string = 'promptscontainer'
param configContainerName string = 'config'
param cosmosDatabaseName string = 'openaiPromptsDB'
param aiMultiServicesName string = 'aimultiservices-${suffix}'
@description('Deploy a front end UI (static web app)? Set to true to deploy, false to skip.')
param deployStaticWebApp bool

// @description('How would you like to manage your prompts (COMSOS or YAML)? If you deployed the static webapp, we recommend COSMOS. This can be changed later.')
// @allowed([
//   'COSMOS'
//   'YAML'
// ])
// param promptFormat string

// 1. Key Vault
module keyVault './modules/keyVault.bicep' = {
  name: 'keyVaultModule'
  params: {
    vaultName: keyVaultName
    location: location
    tenantId: tenantId
  }
}

// 2. OpenAI
module aoai './modules/aoai.bicep' = {
  name: 'aoaiModule'
  params: {
    location: aoaiLocation
    name: aoaiName
    aiServicesName: aiServicesName
  }
}

// 4. Cosmos DB
module cosmos './modules/cosmos.bicep' = if (deployStaticWebApp) {
  name: 'cosmosModule'
  params: {
    location: location
    accountName: cosmosAccountName
    databaseName: cosmosDatabaseName
    containerName: promptsContainer
    configContainerName: configContainerName
  }
}

// Web Backend Function App
module webBackendFunctionApp './modules/functionApp.bicep' = if (deployStaticWebApp) {
  name: 'webBackendFunctionAppModule'
  params: {
    appName: webBackendFunctionAppName
    appPurpose: 'webbackend'
    location: location
    storageAccountName: webBackendStorageAccountName
    aoaiEndpoint: aoai.outputs.AOAI_ENDPOINT
    cosmosName: cosmos.outputs.accountName
    aiMultiServicesEndpoint: aiMultiServices.outputs.aiMultiServicesEndpoint
    deployStaticWebApp: deployStaticWebApp
  }
}

// 5. Static Web App
module staticWebApp './modules/staticWebapp.bicep' = if (deployStaticWebApp) {
  name: 'staticWebAppModule'
  params: {
    staticWebAppName: staticWebAppName
    functionAppResourceId: webBackendFunctionApp.outputs.id // Updated to use web backend app
    user_gh_url: user_gh_url
    location: location
    cosmosId: cosmos.outputs.cosmosResourceId
  }
}


// File Processing Function App
module processingFunctionApp './modules/functionApp.bicep' = {
  name: 'processingFunctionAppModule'
  params: {
    appName: processingFunctionAppName
    appPurpose: 'processing'
    location: location
    storageAccountName: processingStorageAccountName
    aoaiEndpoint: aoai.outputs.AOAI_ENDPOINT
    cosmosName: deployStaticWebApp ? cosmos.outputs.accountName : ''
    aiMultiServicesEndpoint: aiMultiServices.outputs.aiMultiServicesEndpoint
    allowedOrigins: deployStaticWebApp ? ['https://${staticWebApp.outputs.uri}'] : []
    deployStaticWebApp: deployStaticWebApp
  }
}

// 6. Azure AI Multi Services
module aiMultiServices './modules/aimultiservices.bicep' = {
  name: 'aiMultiServicesModule'
  params: {
    aiMultiServicesName: aiMultiServicesName
    location: location
  }
}

// Invoke the role assignment module for Storage Queue Data Contributor
module cosmosContributor './modules/rbac/cosmos-contributor.bicep' = if (deployStaticWebApp) {
  name: 'cosmosContributorModule'
  scope: resourceGroup() // Role assignment applies to the storage account
  params: {
    principalIds: [webBackendFunctionApp.outputs.identityPrincipalId, processingFunctionApp.outputs.identityPrincipalId]
    resourceName: cosmos.outputs.accountName
  }
}

// Invoke the role assignment module for Storage Queue Data Contributor
module cosmosContributorUser './modules/rbac/cosmos-contributor.bicep' = if (deployStaticWebApp) {
  name: 'cosmosContributorUserModule'
  scope: resourceGroup() // Role assignment applies to the storage account
  params: {
    principalIds: [userPrincipalId]
    resourceName: cosmos.outputs.accountName
  }
}

// Invoke the role assignment module for Storage Blob Data Contributor
module blobStorageDataContributor './modules/rbac/blob-contributor.bicep' = {
  name: 'blobRoleAssignmentModule'
  scope: resourceGroup() // Role assignment applies to the storage account
  params: {
    principalIds: deployStaticWebApp ? [webBackendFunctionApp.outputs.identityPrincipalId, processingFunctionApp.outputs.identityPrincipalId, aiMultiServices.outputs.identityPrincipalId] : [processingFunctionApp.outputs.identityPrincipalId, aiMultiServices.outputs.identityPrincipalId]
    resourceName: processingFunctionApp.outputs.storageAccountName
  }
}

// Invoke the role assignment module for Storage Queue Data Contributor
module blobQueueContributor './modules/rbac/blob-queue-contributor.bicep' = {
  name: 'blobQueueAssignmentModule'
  scope: resourceGroup() // Role assignment applies to the storage account
  params: {
    principalIds: [processingFunctionApp.outputs.identityPrincipalId]
    resourceName: processingFunctionApp.outputs.storageAccountName
  }
}

// Invoke the role assignment module for Storage Queue Data Contributor
module aiServicesOpenAIUser './modules/rbac/cogservices-openai-user.bicep' = {
  name: 'aiServicesOpenAIUserModule'
  scope: resourceGroup() // Role assignment applies to the storage account
  params: {
    principalIds: [processingFunctionApp.outputs.identityPrincipalId]
    resourceName: aoai.outputs.name
  }
}

// Invoke the role assignment module for Azure AI Multi Services User
module aiMultiServicesUser './modules/rbac/aiservices-user.bicep' = {
  name: 'aiMultiServicesUserModule'
  scope: resourceGroup() // Role assignment applies to the Azure Function App
  params: {
    principalIds: [processingFunctionApp.outputs.identityPrincipalId]
    resourceName: aiMultiServices.outputs.aiMultiServicesName
  }
}

// Invoke the role assignment module for Storage Queue Data Contributor
module blobContributor './modules/rbac/blob-contributor.bicep' = if (userPrincipalId != '') {
  name: 'blobStorageUserAssignmentModule'
  scope: resourceGroup() // Role assignment applies to the storage account
  params: {
    principalIds: [userPrincipalId]
    resourceName: processingFunctionApp.outputs.storageAccountName
    principalType: 'User'
  }
}

output RESOURCE_GROUP string = resourceGroup().name
output PROCESSING_AZURE_STORAGE_ACCOUNT string = processingFunctionApp.outputs.storageAccountName
output PROCESSING_BLOB_ENDPOINT string = processingFunctionApp.outputs.blobEndpoint
output PROMPT_FILE string = processingFunctionApp.outputs.promptFile
output OPENAI_API_VERSION string = processingFunctionApp.outputs.openaiApiVersion
output OPENAI_API_BASE string = processingFunctionApp.outputs.openaiApiBase
output OPENAI_MODEL string = processingFunctionApp.outputs.openaiModel
output STATIC_WEB_APP_NAME string = deployStaticWebApp ? staticWebApp.outputs.name : '0'
output COSMOS_DB_PROMPTS_CONTAINER string = deployStaticWebApp ? promptsContainer : ''
output COSMOS_DB_CONFIG_CONTAINER string = deployStaticWebApp ? configContainerName : ''
output COSMOS_DB_PROMPTS_DB string = deployStaticWebApp ? cosmosDatabaseName : ''
output COSMOS_DB_ACCOUNT_NAME string = deployStaticWebApp ? cosmos.outputs.accountName : ''
output COSMOS_DB_URI string = deployStaticWebApp ? 'https://${cosmosAccountName}.documents.azure.com:443/' : ''
output AIMULTISERVICES_NAME string = aiMultiServices.outputs.aiMultiServicesName
output AIMULTISERVICES_ENDPOINT string = aiMultiServices.outputs.aiMultiServicesEndpoint
output PROCESSING_FUNCTION_APP_NAME string = processingFunctionApp.outputs.name
output PROCESSING_FUNCTION_URL string = processingFunctionApp.outputs.uri
output WEB_BACKEND_FUNCTION_APP_NAME string = deployStaticWebApp ? webBackendFunctionApp.outputs.name : ''
output WEB_BACKEND_FUNCTION_URL string = deployStaticWebApp ? webBackendFunctionApp.outputs.uri : ''
