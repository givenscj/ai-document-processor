param principalIds array
param resourceName string
param principalType string = 'ServicePrincipal'

resource resource 'Microsoft.Storage/storageAccounts@2021-04-01' existing = {
  name: resourceName
}

var roleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor role

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for principalId in principalIds: {
  name: guid(resourceGroup().id, principalId, roleDefinitionId)
  scope: resource
  properties: {
    roleDefinitionId: roleDefinitionId
    principalId: principalId
    principalType: principalType
  }
}]
