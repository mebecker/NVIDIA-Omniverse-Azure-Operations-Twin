#! /bin/bash
DOMAINS=$1
EMAIL=$2
KEY_VAULT_NAME=$3
PASSWORD=$(openssl rand -base64 32)

IFS=',' read -r -a array <<< "$DOMAINS"

for DOMAIN in "${array[@]}"; do
    certbot --config-dir ./ --work-dir ./ --logs-dir ./ --manual --preferred-challenges dns certonly -d "*.$DOMAIN" -m $EMAIL --agree-tos   
    openssl pkcs12 -export -in "./live/$DOMAIN/cert.pem" -inkey "./live/$DOMAIN/privkey.pem" -out "$DOMAIN.pfx" -password pass:$PASSWORD
    az keyvault certificate import --file "$DOMAIN.pfx" --name "${DOMAIN//./-}" --vault-name $KEY_VAULT_NAME --password $PASSWORD 
done