#! /bin/bash
set -euxo pipefail

SCRIPT_PATH=$(dirname "$(realpath "$0")")

mkdir -p $SCRIPT_PATH/working/external-dns $SCRIPT_PATH/working/nginx-ingress-controller $SCRIPT_PATH/working/nginx-service $SCRIPT_PATH/working/memcached $SCRIPT_PATH/working/flux2 $SCRIPT_PATH/working/kit-appstreaming-manager $SCRIPT_PATH/working/kit-appstreaming-applications $SCRIPT_PATH/working/kit-appstreaming-rmcp

envsubst < $SCRIPT_PATH/templates/external-dns/manifest.yaml > $SCRIPT_PATH/working/external-dns/manifest.yaml
envsubst < $SCRIPT_PATH/templates/nginx-ingress-controller/values-internal.yaml > $SCRIPT_PATH/working/nginx-ingress-controller/values-internal.yaml
envsubst < $SCRIPT_PATH/templates/nginx-service/manifest.yaml > $SCRIPT_PATH/working/nginx-service/manifest.yaml
envsubst < $SCRIPT_PATH/templates/memcached/values.yaml > $SCRIPT_PATH/working/memcached/values.yaml
envsubst < $SCRIPT_PATH/templates/flux2/values.yaml > $SCRIPT_PATH/working/flux2/values.yaml
envsubst < $SCRIPT_PATH/templates/kit-appstreaming-manager/values.yaml > $SCRIPT_PATH/working/kit-appstreaming-manager/values.yaml
envsubst < $SCRIPT_PATH/templates/kit-appstreaming-applications/values.yaml > $SCRIPT_PATH/working/kit-appstreaming-applications/values.yaml
envsubst < $SCRIPT_PATH/templates/kit-appstreaming-rmcp/values.yaml > $SCRIPT_PATH/working/kit-appstreaming-rmcp/values.yaml

SCRIPT_PATH=$(dirname "$(realpath "$0")")

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

echo "Installing nginx-ingress-controller"
helm upgrade --install nginx-ingress-controller-internal -n nginx-ingress-controller --create-namespace -f $SCRIPT_PATH/working/nginx-ingress-controller/values-internal.yaml bitnami/nginx-ingress-controller

echo "Installing memcached"
helm upgrade --install memcached oci://registry-1.docker.io/bitnamicharts/memcached -n omni-streaming --create-namespace -f $SCRIPT_PATH/working/memcached/values.yaml

echo "Installing flux2"
kubectl create namespace flux-operators
helm upgrade --install --namespace flux-operators -f $SCRIPT_PATH/working/flux2/values.yaml fluxcd fluxcd-community/flux2

echo "Installing NVIDIA GPU Operator"
kubectl create secret -n omni-streaming docker-registry regcred --docker-server=nvcr.io --docker-username='$oauthtoken' --docker-password=$NGC_API_TOKEN --dry-run=client -o json | kubectl apply -f -
helm install --wait --generate-name -n gpu-operator --create-namespace --repo https://helm.ngc.nvidia.com/nvidia gpu-operator --set driver.version=535.104.05

echo "Installing NVIDIA RMCP"
helm upgrade --install --namespace omni-streaming -f $SCRIPT_PATH/working/kit-appstreaming-rmcp/values.yaml rmcp omniverse/kit-appstreaming-rmcp

echo "Installing NVIDIA Streaming Manager"
helm upgrade --install --namespace omni-streaming -f $SCRIPT_PATH/working/kit-appstreaming-manager/values.yaml streaming omniverse/kit-appstreaming-manager

echo "Installing NVIDIA Application"
helm upgrade --install --namespace omni-streaming -f $SCRIPT_PATH/working/kit-appstreaming-applications/values.yaml applications omniverse/kit-appstreaming-applications 

k8sInternalLoadBalancerPrivateIP=$(az network lb show -g $(az aks show -g rg-nvidia -n aks-nvidia --query nodeResourceGroup -o tsv) -n kubernetes-internal --query "frontendIPConfigurations[0].privateIPAddress" -o tsv)

az network private-dns record-set a add-record --ipv4-address $k8sInternalLoadBalancerPrivateIP --record-set-name api2 --resource-group $RESOURCE_GROUP --zone-name $PRIVATE_DNS_ZONE_NAME
