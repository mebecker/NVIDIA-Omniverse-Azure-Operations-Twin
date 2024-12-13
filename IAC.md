# foo

## Prerequisites

1. AZ CLI
2. Certbot
3. OpenSSL
4. Kubectl
5. Kubelogin

Caveat - All of the automation was developed and tested in Ubuntu 24.04.01 running in WSL. There is nothing in the automation that specifically *requires* Linux, but running directly under Windows will likely require some modifications to commands, strings, etc.

## Deplyoment steps

1. Update all of the values in the json files in the ./bicep/paramaters/contoso folder.

2. Login to AZ CLI, create resource group and deploy Key Vault, MSIs, and VNet.

    ```bash
    RESOURCE_GROUP_NAME=""
    LOCATION=""

    az login
    az group create --location $LOCATION --name $RESOURCE_GROUP_NAME
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ./bicep/step-1.bicep --parameters ./bicep/parameters/contoso/step-1.json  
    ```

3. Create certificates and upload to Key Vault

    ```bash
    DOMAINS="" #comma-delimited list of domains for which to create and upload certificates. you should have one for the "front end" and one for the "back end"
    EMAIL="" #contact email for letsencrypt
    KEYVAULT_NAME="" #your key vault name

    ./create-and-upload-certificates.sh $DOMAINS $EMAIL $KEYVAULT_NAME
    ```

4. Deploy Application Gateway, APIM, AKS. This step will take a while (up to 45 minutes) since APIM takes a long time to deploy.

    ```bash
    az deployment group create --resource-group $RESOURCE_GROUP_NAME --template-file ./bicep/step-2.bicep --parameters ./bicep/parameters/contoso/step-2.json
    ```

5. Deploy nginx-ingress-controller

    Update ./k8s/nginx-ingress-controller/values-internal.yaml 

    1. Set "service.beta.kubernetes.io/azure-load-balancer-resource-group" to the managed resource group for your AKS cluster. You can get that via `az aks show --resource-group $RESOURCE_GROUP_NAME --name $CLUSTER_NAME --
query nodeResourceGroup`
    2. Set "service.beta.kubernetes.io/azure-load-balancer-internal-subnet" to your AKS subnet
    3. Run the following commands

        ```bash
        az aks get-credentials --format azure --resource-group rg-nvidia --name aks-nvidia
        export KUBECONFIG=/home/${USER}/.kube/config
        kubelogin convert-kubeconfig –l azurecli

        helm upgrade -i nginx-ingress-controller-internal -n nginx-ingress-controller --create-namespace -f ./k8s/nginx-ingress-controller/values-internal.yaml bitnami/nginx-ingress-controller
        ```
