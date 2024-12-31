#! /bin/bash
set -euo pipefail # fail on unset parameters, error on any command failure, print each command before executing

SCRIPT_PATH=$(dirname "$(realpath "$0")")
KIT_APP_WORKING_DIR=$(mktemp -d)
echo "Created temporary working directory $KIT_APP_WORKING_DIR"

source $SCRIPT_PATH/exports.sh

echo "Cloning the kit app template repository to $KIT_APP_WORKING_DIR"

git clone https://github.com/NVIDIA-Omniverse/kit-app-template $KIT_APP_WORKING_DIR

cp -r $SCRIPT_PATH/../kit-app-source/source $KIT_APP_WORKING_DIR

cat >> $KIT_APP_WORKING_DIR/premake5.lua<< EOF
-- Apps: for each app generate batch files and a project based on kit files (e.g. my_name.my_app.kit)
define_app("msft.usd_viewer.kit")
define_app("msft.usd_viewer_streaming.kit")
EOF

cat >> $KIT_APP_WORKING_DIR/tools/containers/kit_args.txt<< EOF

"--/app/auto_load_usd=\${USD_PATH}"
EOF

python3 -m venv $KIT_APP_WORKING_DIR/venv
source $KIT_APP_WORKING_DIR/venv/bin/activate
pip install toml-cli

toml set --toml-path $KIT_APP_WORKING_DIR/repo.toml repo_precache_exts.apps '["${root}/source/apps/msft.usd_viewer.kit","${root}/source/apps/msft.usd_viewer_streaming.kit"]' --to-array
toml unset --toml-path $KIT_APP_WORKING_DIR/repo.toml repo_precache_exts.registries

$KIT_APP_WORKING_DIR/repo.sh build

# $KIT_APP_WORKING_DIR/repo.sh launch -- --/app/auto_load_usd="\${app}/../samples/stage01.usd".

docker login nvcr.io --username '$oauthtoken' --password $NGC_API_TOKEN

$KIT_APP_WORKING_DIR/repo.sh package --container
# docker image list

TOKEN_NAME=omniverse01-push
TOKEN_PWD=$(az acr token create --name $TOKEN_NAME --registry $ACR_NAME --scope-map _repositories_push_metadata_write --expiration $(date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%SZ") --query "credentials.passwords[0].value" --output tsv)

echo $TOKEN_PWD | docker login --username $TOKEN_NAME --password-stdin $ACR_NAME.azurecr.io

docker tag kit_app_template $ACR_NAME.azurecr.io/$KIT_APP_NAME:$KIT_APP_VERSION
docker push $ACR_NAME.azurecr.io/$KIT_APP_NAME:$KIT_APP_VERSION

echo "Removing temporary working directory $KIT_APP_WORKING_DIR"
rm -rf $KIT_APP_WORKING_DIR
