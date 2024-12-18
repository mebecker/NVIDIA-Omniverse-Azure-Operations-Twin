
```bash
export BASE_DOMAIN=<your-domain-name>
export DOMAIN_FILTER=$BASE_DOMAIN
export NGINX_HOST_NAME=123.appgw.omniverse-frontend.$BASE_DOMAIN
export AKS_MANAGED_RESOURCE_GROUP=MC_rg-nvidia_aks-nvidia_centralus
export AKS_SUBNET=subnet-aks
export AGENT_POOL=agentpoolds
export CACHE_POOL=cachepool
export GPU_POOL=gpu-pool
export NGC_API_TOKEN=<snip>
export API_INGRESS_URL=api.omniverse-backend.$BASE_DOMAIN
export STREAMING_BASE_DOMAIN=appgw.omniverse-frontend.$BASE_DOMAIN
export AKS_RESOURCE_GROUP=rg-nvidia
export AKS_CLUSTER_NAME=aks-nvidia
```

```bash
az aks get-credentials --format azure --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME

export KUBECONFIG=/home/${USER}/.kube/config

kubelogin convert-kubeconfig –l azurecli
```


```bash
./k8s/install.sh
```