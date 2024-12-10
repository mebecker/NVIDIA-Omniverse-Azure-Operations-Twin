targetScope='resourceGroup'

param location string
param apimPublisherName string
param apimPublisherEmail string
param apimGwHostName string
param apimMgmtHostName string
param customDomainHostNameSslCertKeyVaultId string
param virtualNetworkName string
param serviceUrl string
param apiManagementServiceName string
param applicationGatewayName string
param apimSku string = 'Developer'
param apimSkuCount int = 1
param appGwPublicIpName string = '${applicationGatewayName}-pip'
param appGwSize string = 'Standard_v2'
@description('Minimum instance count for Application Gateway')
param minCapacity int = 2

@description('Maximum instance count for Application Gateway')
param maxCapacity int = 3
param cookieBasedAffinity string = 'Disabled'
param sslCertName string = 'contoso-omniverse-wildcard'
param appgwHostName string = 'appgw.contoso-omniverse.com'

param aksClusterName string
param dnsPrefix string
param agentNodeCount int = 3

param cacheNodeCount int = 1

param gpuNodeCount int = 1

param agentMaxPods int = 30

param agentVMSize string
param cacheVMSize string
param gpuVMSize string

param aksRbacAssignments array = []

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: virtualNetworkName
}

resource appGwMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: 'msi-appgw'
}

resource apimMsi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: 'msi-apim'
}

resource publicIP 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: appGwPublicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource applicationGateway 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: applicationGatewayName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appGwMsi.id}': {}
    }
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: appGwSize
      tier: 'Standard_v2'
    }
    autoscaleConfiguration: {
      minCapacity: minCapacity
      maxCapacity: maxCapacity
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/subnet-waf'
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: publicIP.id
          }
          privateIPAddress: '10.2.1.10'
        }
      }
    ]
    frontendPorts: [
      {
        name: 'httpPort'
        properties: {
          port: 80
        }
      }
      {
        name: 'httpsPort'
        properties: {
          port: 443
        }
      }      
    ]
    backendAddressPools: [
      {
        name: 'appGatewayBackendPool'
        properties: {
          
          backendAddresses: [
            {
              fqdn: apimGwHostName
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'https'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: cookieBasedAffinity
          requestTimeout: 20
          pickHostNameFromBackendAddress: true
          probe: { 
            id: resourceId('Microsoft.Network/applicationGateways/probes', applicationGatewayName, 'appGatewayProbe')
          }
        }
      }
    ]

    // sslCertificates: [
    //   {
    //     name: sslCertName
    //     properties: {
    //       keyVaultSecretId: customDomainHostNameSslCertKeyVaultId
    //     }
    //   }
    // ]

    httpListeners: [
      {
        name: 'http'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'httpPort')
          }
          protocol: 'Http'
        }
      }
      // {
      //   name: 'https'
      //   properties: {
      //     frontendIPConfiguration: {
      //       id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', applicationGatewayName, 'appGatewayFrontendIP')
      //     }
      //     frontendPort: {
      //       id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', applicationGatewayName, 'httpsPort')
      //     }
      //     protocol: 'Https'
      //     sslCertificate: {
      //       id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', sslCertName)
      //     }
      //     hostNames: [
      //       appgwHostName
      //     ]
      //     requireServerNameIndication: true
      //     customErrorConfigurations: []
      //   }
      // }      
    ]
    // redirectConfigurations: [
    //   {
    //     name: 'redirectConfig'
    //     properties: {
    //       redirectType: 'Permanent'
    //       targetListener: {
    //         id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'https')
    //       }
    //       includePath: true
    //       includeQueryString: true
    //       requestRoutingRules: [
    //         {
    //           id: resourceId('Microsoft.Network/applicationGateways/requestRoutingRules', applicationGatewayName, 'http')
    //         }
    //       ]
    //     }
    //   }
    // ]
    requestRoutingRules: [
      {
        name: 'http'
        properties: {
          ruleType: 'Basic'
          priority: 10
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'http')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'appGatewayBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'https')
          }
        }
      } 
      // {
      //   name: 'http'
      //   properties: {
      //     ruleType: 'Basic'
      //     priority: 100
      //     httpListener: {
      //       id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'http')
      //     }
      //     backendHttpSettings: {
      //       id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'appGatewayBackendHttpSettings')
      //     }
      //   }
      // }
      // {
      //   name: 'https'
      //   properties: {
      //     ruleType: 'Basic'
      //     priority: 10
      //     httpListener: {
      //       id: resourceId('Microsoft.Network/applicationGateways/httpListeners', applicationGatewayName, 'https')
      //     }
      //     backendAddressPool: {
      //       id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', applicationGatewayName, 'appGatewayBackendPool')
      //     }
      //     backendHttpSettings: {
      //       id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', applicationGatewayName, 'appGatewayBackendHttpSettings')
      //     }
      //   }
      // }      
    ]
    probes: [
      {
        name: 'appGatewayProbe'
        properties: {
          protocol: 'Https'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          minServers: 1
          pickHostNameFromBackendHttpSettings: true
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
  }
}

#disable-next-line BCP081
resource apiManagementService 'Microsoft.ApiManagement/service@2024-06-01-preview' = {
  name: apiManagementServiceName
  location: location
  sku: {
    name: apimSku
    capacity: apimSkuCount
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${apimMsi.id}': {}
    }
  }
  properties: {
    publisherEmail: apimPublisherEmail
    publisherName: apimPublisherName
    virtualNetworkConfiguration: {
      subnetResourceId: '${vnet.id}/subnets/subnet-apim'
    }
    virtualNetworkType: 'Internal'
    hostnameConfigurations: [
      {
          type: 'Proxy'
          hostName: apimGwHostName
          defaultSslBinding: true
          negotiateClientCertificate: false
          certificateSource: 'KeyVault'
          identityClientId: apimMsi.properties.clientId
          keyVaultId: customDomainHostNameSslCertKeyVaultId
      }
      {
          type: 'Management'
          hostName: apimMgmtHostName
          certificateSource: 'KeyVault'
          identityClientId: apimMsi.properties.clientId
          keyVaultId: customDomainHostNameSslCertKeyVaultId
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApi 'Microsoft.ApiManagement/service/apis@2024-06-01-preview' = {
  parent: apiManagementService
  name: 'http'
  properties: {
    apiType: 'http'
    displayName: 'http'
    apiRevision: '1'
    isCurrent: true
    path: ''
    protocols: [
      'https'
    ]
    serviceUrl: serviceUrl
    type: 'http'
    subscriptionRequired: false
  }
}

#disable-next-line BCP081
resource httpApiGet 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiGetDeploy'
  properties: {
    displayName: 'Get'
    method: 'GET'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApiPost 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiPostDeploy'
  properties: {
    displayName: 'Post'
    method: 'POST'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApiPut 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiPutDeploy'
  properties: {
    displayName: 'Put'
    method: 'PUT'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApiDelete 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiDeleteDeploy'
  properties: {
    displayName: 'Delete'
    method: 'DELETE'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

#disable-next-line BCP081
resource httpApiOptions 'Microsoft.ApiManagement/service/apis/operations@2024-06-01-preview' = {
  parent: httpApi
  name: 'httpApiOptionsDeploy'
  properties: {
    displayName: 'Options'
    method: 'OPTIONS'
    urlTemplate: '/*'
    request: {
      queryParameters: []
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: []
      }
    ]
  }
}

resource aks 'Microsoft.ContainerService/managedClusters@2024-06-02-preview' = {
  name: aksClusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    aadProfile: {
      managed: true
      enableAzureRBAC: true
    }
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpoolds'
        count: agentNodeCount
        vmSize: agentVMSize
        osType: 'Linux'
        mode: 'System'
        maxPods: agentMaxPods
        enableAutoScaling: false
        vnetSubnetID: '${vnet.id}/subnets/subnet-aks'
      }
      {
        name: 'cachepool'
        count: cacheNodeCount
        vmSize: cacheVMSize
        osType: 'Linux'
        mode: 'User'
        enableAutoScaling: false
        vnetSubnetID: '${vnet.id}/subnets/subnet-aks'
      }
      {
        name: 'gpupool'
        count: gpuNodeCount
        vmSize: gpuVMSize
        osType: 'Linux'
        mode: 'User'
        enableAutoScaling: false
        vnetSubnetID: '${vnet.id}/subnets/subnet-aks'
      }
    ]
    networkProfile: {
      serviceCidr: '10.0.0.0/16'
      dnsServiceIP: '10.0.0.10'
      networkPolicy: 'none'
    }
  }
}

resource aksRbacAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  [for rbacAssignment in aksRbacAssignments: {
  name: guid(aksClusterName, rbacAssignment.roleDefinitionID, rbacAssignment.principalId, resourceGroup().id)
  scope: aks
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', rbacAssignment.roleDefinitionID)
    principalId: rbacAssignment.principalId
    principalType: rbacAssignment.principalType
  }
} ]

var networkContribRoleDefinitionID = '4d97b98b-1d4f-4787-a291-c67834d212e7'
var roleAssignmentName = guid(aksClusterName, networkContribRoleDefinitionID, resourceGroup().id)

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: roleAssignmentName
  scope: vnet
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', networkContribRoleDefinitionID)
    principalId: aks.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

