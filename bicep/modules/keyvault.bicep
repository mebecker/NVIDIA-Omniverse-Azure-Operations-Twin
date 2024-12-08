param keyVaultName string
param location string
param rbacAssignments array = []

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enablePurgeProtection: true
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource rbacAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  [for rbacAssignment in rbacAssignments: {
  name: guid(keyVaultName, rbacAssignment.roleDefinitionID, rbacAssignment.principalId, resourceGroup().id)
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', rbacAssignment.roleDefinitionID)
    principalId: rbacAssignment.principalId
    principalType: 'User'
  }
} ]
