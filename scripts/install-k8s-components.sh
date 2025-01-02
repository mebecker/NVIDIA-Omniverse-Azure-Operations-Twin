#! /bin/bash
set -euo pipefail # fail on unset parameters, error on any command failure, print each command before executing

# =====================================================================================================================
# Initial setup - add helm repos, create variables, namespaces, and secrets needed for the installation process
# =====================================================================================================================

SCRIPT_PATH=$(dirname "$(realpath "$0")")
source $SCRIPT_PATH/exports.sh

TEMPLATE_FOLDER=$SCRIPT_PATH/../k8s/templates
WORKING_FOLDER=$SCRIPT_PATH/../k8s/working

mkdir -p $WORKING_FOLDER
rm -r $WORKING_FOLDER/*

AKS_INFO=$(az aks show -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP_NAME)
export AKS_MANAGED_RESOURCE_GROUP=$(echo $AKS_INFO | jq -r .nodeResourceGroup)
export AKS_IDENTITY_CLIENT_ID=$(az identity show --name $AKS_IDENTITY_NAME --resource-group $RESOURCE_GROUP_NAME --query clientId --output tsv)
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo add omniverse https://helm.ngc.nvidia.com/nvidia/omniverse/ --username='$oauthtoken' --password=$NGC_API_TOKEN
helm repo update

kubectl create namespace omni-streaming --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret -n omni-streaming docker-registry regcred --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_API_TOKEN \
    --save-config --dry-run=client -o json | kubectl apply -f -

kubectl create secret -n omni-streaming generic ngc-omni-user --from-literal=username='$oauthtoken' --from-literal=password=$NGC_API_TOKEN \
    --save-config --dry-run=client -o json | kubectl apply -f -

# =====================================================================================================================
# Install ExternalDNS. Our config expects to operate against Azure DNS using Workload Identity. If you are using a 
# different DNS provider, or have different authentication requirements, you will need to modify the external-dns 
# manifest as needed. You can find instructions here: https://github.com/kubernetes-sigs/external-dns.
# =====================================================================================================================

echo "Installing external-dns"
envsubst < $TEMPLATE_FOLDER/external-dns/manifest.yaml > $WORKING_FOLDER/external-dns_manifest.yaml
envsubst < $TEMPLATE_FOLDER/external-dns/azure.json > $WORKING_FOLDER/azure.json

kubectl create secret generic azure-config-file --namespace "default" --from-file $WORKING_FOLDER/azure.json \
    --save-config --dry-run=client -o json | kubectl apply -f -

az identity federated-credential create --name $AKS_IDENTITY_NAME --identity-name $AKS_IDENTITY_NAME \
    --resource-group $RESOURCE_GROUP_NAME --issuer $(echo $AKS_INFO | jq -r .oidcIssuerProfile.issuerUrl) --subject "system:serviceaccount:default:external-dns"

kubectl apply -f $WORKING_FOLDER/external-dns_manifest.yaml

# =====================================================================================================================
# Install nginx-ingress-controller. AKS should create an internal load balancer as part of this process. We will
# wait for a minute by default for that to complete before attempting to add the A record for the API endpoint. 
# You can increase or decrease the delay as needed via the NGINX_WAIT_TIME environment variable. 
# FYI, this is the one we use: https://kubernetes.github.io/ingress-nginx/, not this one: 
# https://docs.nginx.com/nginx-ingress-controller/
# =====================================================================================================================

echo "Installing nginx-ingress-controller"
envsubst < $TEMPLATE_FOLDER/nginx-ingress-controller/values-internal.yaml > $WORKING_FOLDER/nginx-ingress-controller_values-internal.yaml

helm upgrade --install nginx-ingress-controller-internal -n nginx-ingress-controller --create-namespace \
    -f $WORKING_FOLDER/nginx-ingress-controller_values-internal.yaml bitnami/nginx-ingress-controller

echo "Giving nginx-ingresss-controller $NGINX_WAIT_TIME seconds to create internal load balancer. Override this behavior by setting the environment variable NGINX_WAIT_TIME to 0"
sleep $NGINX_WAIT_TIME

K8S_INTERNAL_LOAD_BALANCER_PRIVATE_IP=$(az network lb show -g $AKS_MANAGED_RESOURCE_GROUP -n kubernetes-internal --query "frontendIPConfigurations[0].privateIPAddress" -o tsv)

records=$(az network private-dns record-set a list --resource-group $RESOURCE_GROUP_NAME --zone-name $PRIVATE_DNS_ZONE_NAME --query "[].name")
if  echo $records | grep -w api; then 
    echo 'Record exists'
else
    echo 'Creating record'
    az network private-dns record-set a add-record --ipv4-address $K8S_INTERNAL_LOAD_BALANCER_PRIVATE_IP --record-set-name api --resource-group $RESOURCE_GROUP_NAME --zone-name $PRIVATE_DNS_ZONE_NAME
fi

# =====================================================================================================================
# Install memcached. https://www.memcached.org/
# =====================================================================================================================

echo "Installing memcached"
envsubst < $TEMPLATE_FOLDER/memcached/values.yaml > $WORKING_FOLDER/memcached_values.yaml
helm upgrade --install memcached oci://registry-1.docker.io/bitnamicharts/memcached -n omni-streaming --create-namespace -f $WORKING_FOLDER/memcached_values.yaml

# =====================================================================================================================
# Install fluxcd. https://github.com/fluxcd/flux2
# =====================================================================================================================

echo "Installing flux2"
envsubst < $TEMPLATE_FOLDER/flux2/values.yaml > $WORKING_FOLDER/flux2_values.yaml
helm upgrade --install --namespace flux-operators --create-namespace  -f $WORKING_FOLDER/flux2_values.yaml fluxcd fluxcd-community/flux2

# =====================================================================================================================
# Install NVIDIA GPU Operator. https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/overview.html
# =====================================================================================================================

echo "Installing NVIDIA GPU Operator"
helm upgrade --install --wait --namespace gpu-operator --create-namespace gpu-operator nvidia/gpu-operator --set driver.version=535.104.05

# =====================================================================================================================
# Install NVIDIA Core services - Resource Management Control Plane, Application Store, Streaming Session Manager.
# https://docs.omniverse.nvidia.com/ovas/latest/deployments/infra/core-services.html
# =====================================================================================================================

echo "Installing NVIDIA RMCP"
envsubst < $TEMPLATE_FOLDER/kit-appstreaming-rmcp/values.yaml > $WORKING_FOLDER/kit-appstreaming-rmcp_values.yaml
helm upgrade --install --namespace omni-streaming -f $WORKING_FOLDER/kit-appstreaming-rmcp_values.yaml rmcp omniverse/kit-appstreaming-rmcp

echo "Installing NVIDIA Streaming Manager"
envsubst < $TEMPLATE_FOLDER/kit-appstreaming-manager/values.yaml > $WORKING_FOLDER/kit-appstreaming-manager_values.yaml
kubectl apply -n omni-streaming -f $SCRIPT_PATH/../k8s/templates/ngc-omniverse.yaml 
helm upgrade --install --namespace omni-streaming -f $WORKING_FOLDER/kit-appstreaming-manager_values.yaml streaming omniverse/kit-appstreaming-manager

echo "Installing NVIDIA Application"
envsubst < $TEMPLATE_FOLDER/kit-appstreaming-applications/values.yaml > $WORKING_FOLDER/kit-appstreaming-applications_values.yaml
helm upgrade --install --namespace omni-streaming -f $WORKING_FOLDER/kit-appstreaming-applications_values.yaml applications omniverse/kit-appstreaming-applications 
TOKEN_NAME=omniverse01-pull
ACR_TOKEN=$(az acr token create --name $TOKEN_NAME --registry $ACR_NAME --scope-map _repositories_push_metadata_write --expiration $(date -u -d "+1 year" +"%Y-%m-%dT%H:%M:%SZ") --query "credentials.passwords[0].value" --output tsv)
kubectl create secret -n omni-streaming docker-registry myregcred --docker-server=$ACR_NAME.azurecr.io --docker-username=$TOKEN_NAME --docker-password=$ACR_TOKEN \
    --save-config --dry-run=client -o json | kubectl apply -f -

# =====================================================================================================================
# Install Omniverse Kit App CRDs - Application, ApplicationVersion, ApplicationProfile
# https://docs.omniverse.nvidia.com/ovas/latest/deployments/apps/index.html
# =====================================================================================================================

echo "Installing application CRD"
envsubst < $TEMPLATE_FOLDER/application.yaml > $WORKING_FOLDER/application.yaml
kubectl apply -n omni-streaming -f $WORKING_FOLDER/application.yaml

echo "Installing applicationversion CRD"
envsubst < $TEMPLATE_FOLDER/application-version.yaml > $WORKING_FOLDER/application-version.yaml
kubectl apply -n omni-streaming -f $WORKING_FOLDER/application-version.yaml

echo "Installing applicationprofile CRD"
envsubst < $TEMPLATE_FOLDER/application-profile-wss.yaml > $WORKING_FOLDER/application-profile-wss.yaml
kubectl create secret -n omni-streaming tls stream-tls-secret --cert=$SCRIPT_PATH/../certificates/live/$STREAMING_BASE_DOMAIN/fullchain.pem --key=$SCRIPT_PATH/../certificates/live/$STREAMING_BASE_DOMAIN/privkey.pem \
    --save-config --dry-run=client -o json | kubectl apply -f -
kubectl apply -n omni-streaming -f $WORKING_FOLDER/application-profile-wss.yaml