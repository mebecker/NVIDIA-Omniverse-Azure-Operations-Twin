targetScope='subscription'

param resourceGroupName string
param location string
param keyVaultName string = 'kv-nvidia'
param rbacAssignments array = []

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

module keyVault 'modules/keyvault.bicep' = {
  scope: resourceGroup
  name: 'keyVaultDeploy'
  params: {
    rbacAssignments: rbacAssignments
    keyVaultName: keyVaultName
    location: location
  }
}
