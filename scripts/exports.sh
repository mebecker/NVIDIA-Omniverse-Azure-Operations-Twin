#! /bin/bash
# set -euxo pipefail # fail on unset parameters, error on any command failure, print each command before executing

export BASE_DOMAIN="beckerobrien.com"
export DOMAIN_FILTER=$BASE_DOMAIN 
export NGINX_HOST_NAME=123.appgw.omniverse-frontend.$BASE_DOMAIN 
export AKS_MANAGED_RESOURCE_GROUP=MC_rg-nvidia_aks-nvidia_centralus 
export AKS_SUBNET=subnet-aks 
export AGENT_POOL=agentpool 
export CACHE_POOL=cachepool 
export GPU_POOL=gpu-pool 
export NGC_API_TOKEN=dThxdGhpYTFmYXE4dGRsZHZzaW1pdmtkZTk6ZjA0ZDA2ODAtZTdjMi00ZTc4LWE3ZjktYmMyMGMzOGVjYjIz 
export API_INGRESS_URL=api.omniverse-backend.$BASE_DOMAIN 
export STREAMING_BASE_DOMAIN=appgw.omniverse-frontend.$BASE_DOMAIN 
export AKS_RESOURCE_GROUP=rg-nvidia 
export AKS_CLUSTER_NAME=aks-nvidia 
export DOMAINS="appgw.omniverse-frontend.$BASE_DOMAIN,omniverse-frontend.$BASE_DOMAIN,omniverse-backend.$BASE_DOMAIN" 
export EMAIL="mike.becker@gmail.com"
export KEYVAULT_NAME="kv-omni-mbecker"
export RESOURCE_GROUP_NAME="rg-omni-mbecker"
export LOCATION="eastus2"