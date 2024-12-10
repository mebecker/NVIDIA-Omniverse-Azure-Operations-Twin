targetScope='subscription'

param resourceGroupName string
param location string
param apimPublisherName string
param apimPublisherEmail string
param apimGwHostName string
param apimMgmtHostName string
param customDomainHostNameSslCertKeyVaultId string
param virtualNetworkName string


resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup
}

module apim './modules/apim.bicep' = {
  scope: resourceGroup
  name: 'apimDeploy'
  params: {
    serviceUrl: 'asvsd'
      apiManagementServiceName: 'apim-nvidia'
      location: location
      publisherName: apimPublisherName
      publisherEmail: apimPublisherEmail
      subnetId: '${vnet.id}/subnets/subnet-apim'
      // serviceUrl: 'https://${apimGwHostName}'
      hostNameConfigurations: [
          {
              type: 'Proxy'
              hostName: apimGwHostName
              defaultSslBinding: true
              negotiateClientCertificate: false
              certificateSource: 'KeyVault'
              keyVaultId: customDomainHostNameSslCertKeyVaultId
          }
          {
              type: 'Management'
              hostName: apimMgmtHostName
              certificateSource: 'KeyVault'
              keyVaultId: customDomainHostNameSslCertKeyVaultId
          }
      ]
  }
}
