#! /bin/bash
set -euxo pipefail # fail on unset parameters, error on any command failure, print each command before executing
SCRIPT_PATH=$(dirname "$(realpath "$0")")

DOMAINS=$1
EMAIL=$2
KEY_VAULT_NAME=$3
PASSWORD=$(openssl rand -base64 32)

mkdir -p $SCRIPT_PATH/../certificates

IFS=',' read -r -a array <<< "$DOMAINS"

for DOMAIN in "${array[@]}"; do
    certbot --config-dir $SCRIPT_PATH/../certificates --work-dir $SCRIPT_PATH/../certificates --logs-dir $SCRIPT_PATH/../certificates --manual --preferred-challenges dns certonly -d "*.$DOMAIN" -m $EMAIL --agree-tos   
    openssl pkcs12 -export -in "$SCRIPT_PATH/../certificates/live/$DOMAIN/fullchain.pem" -inkey "$SCRIPT_PATH/../certificates/live/$DOMAIN/privkey.pem" -out "$SCRIPT_PATH/../certificates/$DOMAIN.pfx" -password pass:$PASSWORD
    az keyvault certificate import --file "$SCRIPT_PATH/../certificates/$DOMAIN.pfx" --name "${DOMAIN//./-}" --vault-name $KEY_VAULT_NAME --password $PASSWORD 
done