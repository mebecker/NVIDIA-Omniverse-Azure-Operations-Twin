targetScope='subscription'

param resourceGroupName string
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

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: virtualNetworkName
  scope: resourceGroup
}

module apim 'modules/apim.bicep' = {
  scope: resourceGroup
  name: 'apimDeploy'
  params: {
      apiManagementServiceName: apiManagementServiceName
      location: location
      publisherName: apimPublisherName
      publisherEmail: apimPublisherEmail
      subnetId: '${vnet.id}/subnets/subnet-apim'
      serviceUrl: serviceUrl
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

module appgw 'modules/appgateway.bicep' = {
  scope: resourceGroup
  name: 'appGatewayDeploy'
  params: {
      keyVaultName: 'asdfk'
      applicationGatewayName: applicationGatewayName
      appgwHostName: 'appgw.contoso-omniverse.com'
      sslCertName: 'contoso-omniverse-wildcard'
      customDomainHostNameSslCertKeyVaultId: customDomainHostNameSslCertKeyVaultId
      location: location
      subnetId: '${vnet.id}/subnets/subnet-waf'
      minCapacity: 2
      maxCapacity: 3
      cookieBasedAffinity: 'Disabled'
  }
}
