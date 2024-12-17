# foo

## Prerequisites

1. AZ CLI
2. Certbot
3. OpenSSL

Caveat - All of the automation was developed and tested in Ubuntu 24.04.01 running in WSL. There is nothing in the automation that specifically *requires* Linux, but running directly under Windows will likely require some modifications to commands, strings, etc.

## Deplyoment steps

1. Login to AZ CLI, create resource group and deploy Key Vault, MSIs, and VNet.

    ```bash
    RESOURCE_GROUP_NAME=""
    LOCATION=""

    az login
    az group create --location $LOCATION --name $RESOURCE_GROUP_NAME
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ./bicep/vnet-keyVault-msis.bicep --parameters ./bicep/parameters/contoso/keyvault-and-msis.json  
    ```

2. Create certificates and upload to Key Vault

    ```bash
    DOMAINS="" #comma-delimited list of domains for which to create and upload certificates. you should have one for the "front end" and one for the "back end"
    EMAIL="" #contact email for letsencrypt
    KEYVAULT_NAME="" #your key vault name

    ./create-and-upload-certificates.sh $DOMAINS $EMAIL $KEYVAULT_NAME
    ```

3. Deploy Application Gateway, APIM, AKS. This step will take a while (up to 45 minutes) since APIM takes a long time to deploy.

    ```bash
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ./bicep/apim-appgw-aks.bicep --parameters ./bicep/parameters/contoso/appgw-apim-aks.json
    ```
