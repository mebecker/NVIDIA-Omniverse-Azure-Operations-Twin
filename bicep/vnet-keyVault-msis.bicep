targetScope='resourceGroup'

param location string
param keyVaultName string
param rbacAssignments array = []
param vnetAddressPrefix string
param aksSubnetAddressPrefix string
param wafSubnetAddressPrefix string
param apimSubnetAddressPrefix string
param nsgNameExternal string
param nsgNameInternal string
param virtualNetworkName string
param dnsZoneName string

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

resource nsgInternal 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgNameInternal
  location: location
  properties: {
    securityRules: [
      {
          name: 'AllowCidrBlockCustom80'
          properties: {
              protocol: 'Tcp'
              sourceAddressPrefix: '10.0.0.0/8'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '80'
              direction: 'Inbound'
              access: 'Allow'
              priority: 100
          }
      }
      {
          name: 'AllowCidrBlockCustom443'
          properties: {
              protocol: 'Tcp'
              sourceAddressPrefix: '10.0.0.0/8'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '443'
              direction: 'Inbound'
              access: 'Allow'
              priority: 110
          }
      }
      {
          name: 'AllowTagCustom3443Inbound'
          properties: {
              protocol: 'Tcp'
              sourceAddressPrefix: 'ApiManagement'
              sourcePortRange: '*'
              destinationAddressPrefix: 'VirtualNetwork'
              destinationPortRange: '3443'
              direction: 'Inbound'
              access: 'Allow'
              priority: 120
          }
      }            
      {
          name: 'AllowCidrBlockCustom31000-31002Inbound'
          properties: {
              protocol: 'Tcp'
              sourceAddressPrefix: '10.0.0.0/8'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '31000-31002'
              direction: 'Inbound'
              access: 'Allow'
              priority: 130
          }
      }
      {
          name: 'AllowCidrBlockCustom31000-31002InboundUdp'
          properties: {
              protocol: 'Udp'
              sourceAddressPrefix: '10.0.0.0/8'
              sourcePortRange: '*'
              destinationAddressPrefix: '*'
              destinationPortRange: '31000-31002'
              direction: 'Inbound'
              access: 'Allow'
              priority: 140
          }
      }
    ]
  }
}

resource nsgExternal 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: nsgNameExternal
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowCidrBlockCustom80'
        properties: {
            protocol: 'Tcp'
            sourceAddressPrefix: '*'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '80'
            direction: 'Inbound'
            access: 'Allow'
            priority: 100
        }
      }
      {
        name: 'AllowCidrBlockCustom443'
        properties: {
            protocol: 'Tcp'
            sourceAddressPrefix: '*'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '443'
            direction: 'Inbound'
            access: 'Allow'
            priority: 110
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
            protocol: 'Tcp'
            sourceAddressPrefix: 'GatewayManager'
            sourcePortRange: '*'
            destinationAddressPrefix: '*'
            destinationPortRange: '65200-65535'
            direction: 'Inbound'
            access: 'Allow'
            priority: 120
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
          name: 'subnet-aks'
          properties: {
              addressPrefix: aksSubnetAddressPrefix
              networkSecurityGroup: {
                  id: nsgInternal.id
              }
          }
      }
      {
          name: 'subnet-waf'
          properties: {
              addressPrefix: wafSubnetAddressPrefix
              networkSecurityGroup: {
                id: nsgExternal.id
            }
          }
      }
      {
          name: 'subnet-apim'
          properties: {
              addressPrefix: apimSubnetAddressPrefix
              networkSecurityGroup: {
                  id: nsgInternal.id
              }
          }
      }
    ]
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  location: 'Global'
  name: dnsZoneName
  properties: {}
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: privateDnsZone
  location: 'Global'
  name: 'link-${virtualNetwork.name}'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetwork.id
    }
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

resource appGwMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: location
  name: 'msi-appgw'
}

resource apimMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: location
  name:  'msi-apim'
}

var keyVaultSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6'

resource appGwSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultName, apimMsi.name, keyVaultSecretsUserRoleId, resourceGroup().id)
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: apimMsi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource apimSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultName, appGwMsi.name, keyVaultSecretsUserRoleId, resourceGroup().id)
  scope: keyVault
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleId)
    principalId: appGwMsi.properties.principalId
    principalType: 'ServicePrincipal'
  }
}



