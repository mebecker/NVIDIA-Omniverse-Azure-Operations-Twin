#! /bin/bash
set -euo pipefail # fail on unset parameters, error on any command failure, print each command before executing

SCRIPT_PATH=$(dirname "$(realpath "$0")")
source $SCRIPT_PATH/exports.sh

TEMPLATE_FOLDER=$SCRIPT_PATH/../k8s/templates
WORKING_FOLDER=$SCRIPT_PATH/../k8s/working

mkdir -p $WORKING_FOLDER

envsubst < $TEMPLATE_FOLDER/external-dns/manifest.yaml > $WORKING_FOLDER/external_dns-manifest.yaml
envsubst < $TEMPLATE_FOLDER/nginx-ingress-controller/values-internal.yaml > $WORKING_FOLDER/nginx-ingress-controller_values-internal.yaml
# envsubst < $TEMPLATE_FOLDER/nginx-service/manifest.yaml > $WORKING_FOLDER/nginx-service_manifest.yaml
envsubst < $TEMPLATE_FOLDER/memcached/values.yaml > $WORKING_FOLDER/memcached_values.yaml
envsubst < $TEMPLATE_FOLDER/flux2/values.yaml > $WORKING_FOLDER/flux2_values.yaml
envsubst < $TEMPLATE_FOLDER/kit-appstreaming-rmcp/values.yaml > $WORKING_FOLDER/kit-appstreaming-rmcp_values.yaml
envsubst < $TEMPLATE_FOLDER/kit-appstreaming-manager/values.yaml > $WORKING_FOLDER/kit-appstreaming-manager_values.yaml
envsubst < $TEMPLATE_FOLDER/kit-appstreaming-applications/values.yaml > $WORKING_FOLDER/kit-appstreaming-applications_values.yaml

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo remove omniverse
helm repo add omniverse https://helm.ngc.nvidia.com/nvidia/omniverse/ --username='$oauthtoken' --password=$NGC_API_TOKEN
helm repo update

kubectl create namespace omni-streaming --dry-run=client -o yaml | kubectl apply -f -


kubectl delete secret -n omni-streaming regcred --ignore-not-found
kubectl delete secret -n omni-streaming ngc-omni-user --ignore-not-found
kubectl create secret -n omni-streaming docker-registry regcred --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_API_TOKEN --dry-run=client -o json | kubectl apply -f -
kubectl create secret -n omni-streaming generic ngc-omni-user --from-literal=username='$oauthtoken' --from-literal=password=$NGC_API_TOKEN --dry-run=client -o json | kubectl apply -f -

echo "Installing external-dns"
kubectl apply -f $WORKING_FOLDER/external_dns-manifest.yaml

echo "Installing nginx-ingress-controller"
helm upgrade --install nginx-ingress-controller-internal -n nginx-ingress-controller --create-namespace -f $WORKING_FOLDER/nginx-ingress-controller_values-internal.yaml bitnami/nginx-ingress-controller

echo "Installing memcached"
helm upgrade --install memcached oci://registry-1.docker.io/bitnamicharts/memcached -n omni-streaming --create-namespace -f $WORKING_FOLDER/memcached_values.yaml

echo "Installing flux2"
helm upgrade --install --namespace flux-operators --create-namespace  -f $WORKING_FOLDER/flux2_values.yaml fluxcd fluxcd-community/flux2

echo "Installing NVIDIA GPU Operator"
GPU_OPERATOR_NAME=$(helm ls -n gpu-operator --short)
if [[ -n "$GPU_OPERATOR_NAME" ]]; then
    echo "Uninstalling existing GPU Operator"
    helm uninstall $GPU_OPERATOR_NAME -n gpu-operator
fi

helm install --wait --generate-name -n gpu-operator --create-namespace --repo https://helm.ngc.nvidia.com/nvidia gpu-operator --set driver.version=535.104.05

echo "Installing NVIDIA RMCP"
helm upgrade --install --namespace omni-streaming -f $WORKING_FOLDER/kit-appstreaming-rmcp_values.yaml rmcp omniverse/kit-appstreaming-rmcp

echo "Installing NVIDIA Streaming Manager"
helm upgrade --install --namespace omni-streaming -f $WORKING_FOLDER/kit-appstreaming-manager_values.yaml streaming omniverse/kit-appstreaming-manager

echo "Installing NVIDIA Application"
helm upgrade --install --namespace omni-streaming -f $WORKING_FOLDER/kit-appstreaming-applications_values.yaml applications omniverse/kit-appstreaming-applications 

# K8S_INTERNAL_LOAD_BALANCER_PRIVATE_IP=$(az network lb show -g $(az aks show -g $RESOURCE_GROUP_NAME -n $AKS_CLUSTER_NAME --query nodeResourceGroup -o tsv) -n kubernetes-internal --query "frontendIPConfigurations[0].privateIPAddress" -o tsv)

# az network private-dns record-set a add-record --ipv4-address $K8S_INTERNAL_LOAD_BALANCER_PRIVATE_IP --record-set-name api --resource-group $RESOURCE_GROUP_NAME --zone-name $PRIVATE_DNS_ZONE_NAME
