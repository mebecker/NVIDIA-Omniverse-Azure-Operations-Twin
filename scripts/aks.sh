
az aks get-credentials --format azure --resource-group $1 --name $2
export KUBECONFIG=/home/${USER}/.kube/config
kubelogin convert-kubeconfig -l azurecli

kubectl get nodes

kubectl create namespace omni-streaming

#todo - get this token!!
kubectl create secret -n omni-streaming docker-registry regcred \
    --docker-server=nvcr.io \
    --docker-username='$oauthtoken' \
    --docker-password=$3 \
    --dry-run=client -o json | \
    kubectl apply -f -

helm install --wait --generate-name \
   -n gpu-operator --create-namespace \
   --repo https://helm.ngc.nvidia.com/nvidia \
   gpu-operator \
   --set driver.version=535.104.05

helm upgrade --install memcached oci://registry-1.docker.io/bitnamicharts/memcached -n omni-streaming --create-namespace -f helm/memcached/values.yml

kubectl create namespace flux-operators

helm upgrade --install \
  --namespace flux-operators \
  -f helm/flux2/values.yaml \
fluxcd fluxcd-community/flux2

helm upgrade --install \
  --namespace omni-streaming \
  -f helm/kit-appstreaming-rmcp/values.yaml  \
  rmcp omniverse/kit-appstreaming-rmc

helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

helm upgrade -i nginx-ingress-controller-internal -n nginx-ingress-controller --create-namespace -f helm/nginx-ingress-controller/values-internal.yaml bitnami/nginx-ingress-controller
