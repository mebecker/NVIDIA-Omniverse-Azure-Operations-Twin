
## Steps

All steps assume that your current path is the scripts folder in the root of this repo.

1. If you didn't already do so in the IAC deployment, create a copy of exports.sh.template named exports.sh and update all variable values appropriately.

2. Source exports.sh and log into az cli and kubectl

    ```bash
    source ./exports.sh

    az login
    az aks get-credentials --format azure --resource-group $AKS_RESOURCE_GROUP --name $AKS_CLUSTER_NAME
    kubelogin convert-kubeconfig –l azurecli
    ```

3. Make sure you're authenticated and talking to the cluster you expect to be 

    ```bash
    kubectl cluster-info
    ```

4. Run the install script and cross your fingers!

    ```bash
    ./install-k8s-components.sh
    ```
