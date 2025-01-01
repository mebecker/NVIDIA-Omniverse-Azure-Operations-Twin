#! /bin/bash
set -euo pipefail # fail on unset parameters, error on any command failure, print each command before executing

SCRIPT_PATH=$(dirname "$(realpath "$0")")
source $SCRIPT_PATH/exports.sh

TEMPLATE_FOLDER=$SCRIPT_PATH/../k8s/templates
WORKING_FOLDER=$SCRIPT_PATH/../k8s/working

mkdir -p $WORKING_FOLDER

export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
export AKS_IDENTITY_CLIENT_ID=$(az identity show --name $AKS_IDENTITY_NAME --resource-group $RESOURCE_GROUP_NAME --query clientId --output tsv)

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo remove omniverse
helm repo add omniverse https://helm.ngc.nvidia.com/nvidia/omniverse/ --username='$oauthtoken' --password=$NGC_API_TOKEN
helm repo update

kubectl create namespace omni-streaming --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret -n omni-streaming docker-registry regcred --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_API_TOKEN --save-config --dry-run=client -o json | kubectl apply -f -
kubectl create secret -n omni-streaming generic ngc-omni-user --from-literal=username='$oauthtoken' --from-literal=password=$NGC_API_TOKEN --save-config --dry-run=client -o json | kubectl apply -f -

echo "Installing external-dns"
envsubst < $TEMPLATE_FOLDER/external-dns/manifest.yaml > $WORKING_FOLDER/external-dns_manifest.yaml
envsubst < $TEMPLATE_FOLDER/external-dns/azure.json > $WORKING_FOLDER/azure.json
kubectl create secret generic azure-config-file --namespace "default" --from-file $WORKING_FOLDER/azure.json --save-config --dry-run=client -o json | kubectl apply -f -
OIDC_ISSUER_URL="$(az aks show -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP_NAME --query "oidcIssuerProfile.issuerUrl" -otsv)"
az identity federated-credential create --name $AKS_IDENTITY_NAME --identity-name $AKS_IDENTITY_NAME --resource-group $RESOURCE_GROUP_NAME --issuer "$OIDC_ISSUER_URL" --subject "system:serviceaccount:default:external-dns"
kubectl apply -f $WORKING_FOLDER/external-dns_manifest.yaml

echo "Installing nginx-ingress-controller"
envsubst < $TEMPLATE_FOLDER/nginx-ingress-controller/values-internal.yaml > $WORKING_FOLDER/nginx-ingress-controller_values-internal.yaml
helm upgrade --install nginx-ingress-controller-internal -n nginx-ingress-controller --create-namespace -f $WORKING_FOLDER/nginx-ingress-controller_values-internal.yaml bitnami/nginx-ingress-controller

echo "Giving nginx-ingresss-controller 1 miunte to create internal load balancer. Override this behavior by setting the environment variable NGINX_WAIT_TIME to 0"
sleep $NGINX_WAIT_TIME

K8S_INTERNAL_LOAD_BALANCER_PRIVATE_IP=$(az network lb show -g $(az aks show -g $RESOURCE_GROUP_NAME -n $AKS_CLUSTER_NAME --query nodeResourceGroup -o tsv) -n kubernetes-internal --query "frontendIPConfigurations[0].privateIPAddress" -o tsv)

records=$(az network private-dns record-set a list --resource-group $RESOURCE_GROUP_NAME --zone-name $PRIVATE_DNS_ZONE_NAME --query "[].name")
if  echo $records | grep -w api; then 
    echo 'Record exists'
else
    echo 'Creating record'
    az network private-dns record-set a add-record --ipv4-address $K8S_INTERNAL_LOAD_BALANCER_PRIVATE_IP --record-set-name api --resource-group $RESOURCE_GROUP_NAME --zone-name $PRIVATE_DNS_ZONE_NAME
fi

echo "Installing memcached"
envsubst < $TEMPLATE_FOLDER/memcached/values.yaml > $WORKING_FOLDER/memcached_values.yaml
helm upgrade --install memcached oci://registry-1.docker.io/bitnamicharts/memcached -n omni-streaming --create-namespace -f $WORKING_FOLDER/memcached_values.yaml

echo "Installing flux2"
envsubst < $TEMPLATE_FOLDER/flux2/values.yaml > $WORKING_FOLDER/flux2_values.yaml
helm upgrade --install --namespace flux-operators --create-namespace  -f $WORKING_FOLDER/flux2_values.yaml fluxcd fluxcd-community/flux2

echo "Installing NVIDIA GPU Operator"
GPU_OPERATOR_NAME=$(helm ls -n gpu-operator --short)
if [[ -n "$GPU_OPERATOR_NAME" ]]; then
    echo "Uninstalling existing GPU Operator"
    helm uninstall $GPU_OPERATOR_NAME -n gpu-operator --no-hooks
    kubectl delete --all pods --namespace=gpu-operator --force --grace-period=0                                                                                        
fi

helm install --wait --generate-name -n gpu-operator --create-namespace --repo https://helm.ngc.nvidia.com/nvidia gpu-operator --set driver.version=535.104.05

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
kubectl create secret -n omni-streaming docker-registry myregcred --docker-server=$ACR_NAME.azurecr.io --docker-username=$TOKEN_NAME --docker-password=$ACR_TOKEN --save-config --dry-run=client -o json | kubectl apply -f -

echo "Installing application CRD"
envsubst < $TEMPLATE_FOLDER/application.yaml > $WORKING_FOLDER/application.yaml
kubectl apply -n omni-streaming -f $WORKING_FOLDER/application.yaml

echo "Installing applicationversion CRD"
envsubst < $TEMPLATE_FOLDER/application-version.yaml > $WORKING_FOLDER/application-version.yaml
kubectl apply -n omni-streaming -f $WORKING_FOLDER/application-version.yaml

echo "Installing applicationprofile CRD"
envsubst < $TEMPLATE_FOLDER/application-profile-wss.yaml > $WORKING_FOLDER/application-profile-wss.yaml
kubectl create secret -n omni-streaming tls stream-tls-secret --cert=$SCRIPT_PATH/../certificates/live/$STREAMING_BASE_DOMAIN/fullchain.pem --key=$SCRIPT_PATH/../certificates/live/$STREAMING_BASE_DOMAIN/privkey.pem --save-config --dry-run=client -o json | kubectl apply -f -
kubectl apply -n omni-streaming -f $WORKING_FOLDER/application-profile-wss.yaml