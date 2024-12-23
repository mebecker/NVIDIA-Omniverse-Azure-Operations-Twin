targetScope='resourceGroup'

param location string
param keyVaultName string
param vnetAddressPrefix string
param aksSubnetAddressPrefix string
param wafSubnetAddressPrefix string
param apimSubnetAddressPrefix string
param nsgNameExternal string
param nsgNameInternal string
param virtualNetworkName string
param backendDnsZoneName string
param keyVaultOperatorId string
param logAnalyticsName string

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enablePurgeProtection: true
    enableRbacAuthorization: false
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        objectId: keyVaultOperatorId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
            'list'
            'set'
          ]
          certificates: [
            'get'
            'list'
            'set'
          ]
        }
      }
      {
        objectId: appGwMsi.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          certificates: [
            'get'
            'list'
          ]
        }
      }
      {
        objectId: apimMsi.properties.principalId
        tenantId: subscription().tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
          certificates: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

resource keyvaultDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'Log Analytics'
  scope: keyVault
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
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
  name: backendDnsZoneName
  properties: {}
}



// resource rbacAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  [for rbacAssignment in rbacAssignments: {
//   name: guid(keyVaultName, rbacAssignment.roleDefinitionID, rbacAssignment.principalId, resourceGroup().id)
//   scope: keyVault
//   properties: {
//     roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', rbacAssignment.roleDefinitionID)
//     principalId: rbacAssignment.principalId
//     principalType: 'User'
//   }
// } ]

resource appGwMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: location
  name: 'msi-appgw'
}

resource apimMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: location
  name:  'msi-apim'
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  location: location
  name: logAnalyticsName
  properties: {
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    retentionInDays: 30
    sku: {
      name: 'pergb2018'
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}



