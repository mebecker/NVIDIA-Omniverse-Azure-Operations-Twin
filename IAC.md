# Bicep Automation for Azure "Back-end" Components

## Overview

This automation is meant to significantly simplify the deployment and configuration of the "back-end" components of the solution. By "back-end" I mean the Virtual Network, Application Gateway, API Management, Azure Kubernetes Services, Key Vault, Log Analytics, etc.

This is meant to be a reasonably complete deployment with Managed Identities used wherever possible, Log Analytics integration configured, etc. It is not however meant to be production-ready or security-hardened. For example, while the network is segmented to allow for separation of "public" and "private" access, the Key Vault and AKS data planes are open to the internet to facilite ease of use as a proof of concept / learning tool.

## Prerequisites

A number of tools are required in order to complete the installation and configuration. The primary ones include:

1. [AZ CLI](https://learn.microsoft.com/en-us/cli/azure/) (Be sure to upgrade to the latest version via `az upgrade` -- at least 2.64.0)
2. [Certbot](https://certbot.eff.org/)
3. [OpenSSL](https://www.openssl.org/) (Probably included in your Linux distro)
4. [Kubectl](https://kubernetes.io/docs/reference/kubectl/)
5. [Kubelogin](https://learn.microsoft.com/en-us/azure/aks/kubelogin-authentication)

All of the automation was developed and tested in Ubuntu 24.04.01 running in [WSL](https://learn.microsoft.com/en-us/windows/wsl/about). There is nothing in the automation that specifically *requires* Linux, but running directly under Windows will likely require some modifications to commands, strings, etc.

## Deplyoment steps

1. Update all of the values in the json files in the ./bicep/paramaters/contoso folder

2. Create a copy of exports.sh.template named exports.sh and update all variable values appropriately.

3. Login to AZ CLI, create resource group and deploy Key Vault, MSIs, and VNet.

    ```bash
    source ./scripts/exports.sh

    az login
    az group create --location $LOCATION --name $RESOURCE_GROUP_NAME
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ./bicep/step-1.bicep --parameters ./bicep/parameters/contoso/step-1.json  
    ```

4. Create certificates and upload to Key Vault

    You can generate your certificates however you please. Howeer, in order to configure Application Gateway and API Management, the certificates need to be uploaded into Key Vault in PKCS 12 format.

    If you have registered a domain and have control of DNS, you can use the "create-and-upload-certificates.sh" script that I have provided which will use [Certbot](https://certbot.eff.org/) to generate free [Let's Encrypt](https://letsencrypt.org/) certificates and upload them to the Key Vault that was created in step 2. This script takes a comma delimited list of FQDNs for which it will create *wildcard certificates.* If your requirements are different, feel free to modify as needed. Note that the script does a manual dns challenge for domain ownership verification. If you are familiar with how to set up certbot plugins, you can easily modify this to automate the verification.

    ```bash
    DOMAINS="" #comma-delimited list of domains for which to create and upload certificates. you should have one for the "front end" and one for the "back end"
    EMAIL="" #contact email for letsencrypt
    KEYVAULT_NAME="" #your key vault name

    ./certificates/create-and-upload-certificates.sh $DOMAINS $EMAIL $KEYVAULT_NAME
    ```

5. Deploy Application Gateway, APIM, AKS. This step will take a while (up to 45 minutes) since APIM takes a long time to deploy.

    ```bash
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ./bicep/step-2.bicep --parameters ./bicep/parameters/contoso/step-2.json
    ```
