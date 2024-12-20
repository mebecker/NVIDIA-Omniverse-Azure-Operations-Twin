#! /bin/bash
set -euxo pipefail # fail on unset parameters, error on any command failure, print each command before executing

export BASE_DOMAIN=<your base domain - will be concatenated with the subdomains below>
export DOMAIN_FILTER=$BASE_DOMAIN # used for external-dns service. should match BASE_DOMAIN but if necessary override here
export AKS_MANAGED_RESOURCE_GROUP=<your managed resource group> # you can get this via "az aks show -g rg-nvidia -n aks-nvidia --query nodeResourceGroup" or from the properties blade of your aks resource.
export AKS_SUBNET=<your subnet name - get it from your bicep parameters file>
export AGENT_POOL=<also get this from bicep parameters file>
export CACHE_POOL=<also get this from bicep parameters file> 
export GPU_POOL=<also get this from bicep parameters file> 
export NGC_API_TOKEN=<there are instructions in README.md that explain how to get this> 
export API_INGRESS_URL=api.omniverse-backend.$BASE_DOMAIN 
export STREAMING_BASE_DOMAIN=appgw.omniverse-frontend.$BASE_DOMAIN 
export AKS_CLUSTER_NAME=<also get this from bicep parameters file> 
export DOMAINS="appgw.omniverse-frontend.$BASE_DOMAIN,omniverse-frontend.$BASE_DOMAIN,omniverse-backend.$BASE_DOMAIN" 
export EMAIL=<your email - for letsencrypt>
export KEYVAULT_NAME=<also get this from bicep parameters file> 
export RESOURCE_GROUP_NAME=<resource group to deploy all resources to>
export LOCATION=<azure region to deploy all resources to>