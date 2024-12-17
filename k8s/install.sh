az aks get-credentials --format azure --resource-group rg-nvidia --name aks-nvidia

export KUBECONFIG=/home/${USER}/.kube/config

kubelogin convert-kubeconfig –l azurecli

helm upgrade -i nginx-ingress-controller-internal -n nginx-ingress-controller --create-namespace -f ../kas_installation/helm/nginx-ingress-controller/values-internal.yaml bitnami/nginx-ingress-controller