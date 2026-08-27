#!/usr/bin/env bash
# Rebuilds the AMSEL Mobile API image in Azure Container Registry from the
# GitHub repo, then points the Web App at the new image and restarts it.
#
# Run this in Azure Cloud Shell (Bash) whenever you've pushed new code and
# want the deployed API updated. Requires GITHUB_PAT to be set first:
#
#   export GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxx
#   bash deploy-to-azure.sh
#
# (Re-paste this whole file into Cloud Shell if you don't want to clone the
# repo there — it doesn't need to run from inside the repo itself.)

set -euo pipefail

# ---- Fill these in / confirm they match your resources ----
RESOURCE_GROUP="amsel-mobile-rg"
REGISTRY_NAME="amselmobileacr"
WEBAPP_NAME="amsel-mobile-api"
IMAGE_NAME="amsel-mobile-api"
IMAGE_TAG="latest"
GITHUB_REPO="github.com/yuvarajit60/MYS-POS-Mobile-Application.git"
GITHUB_BRANCH="main"
DOCKER_CONTEXT="MYS.MOBILE/MYS.MOBILEAPI"
# -------------------------------------------------------------

if [ -z "${GITHUB_PAT:-}" ]; then
  echo "ERROR: set GITHUB_PAT first, e.g.:"
  echo "  export GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxx"
  exit 1
fi

echo "==> Building image in ACR from ${GITHUB_REPO}#${GITHUB_BRANCH}:${DOCKER_CONTEXT}"
az acr build \
  --registry "$REGISTRY_NAME" \
  --image "${IMAGE_NAME}:${IMAGE_TAG}" \
  "https://${GITHUB_PAT}@${GITHUB_REPO}#${GITHUB_BRANCH}:${DOCKER_CONTEXT}" \
  --file Dockerfile

echo "==> Pointing the Web App at the freshly built image"
LOGIN_SERVER=$(az acr show --name "$REGISTRY_NAME" --query loginServer --output tsv)
az webapp config container set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --container-image-name "${LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}" \
  --container-registry-url "https://${LOGIN_SERVER}"

echo "==> Restarting the Web App to pick up the new image"
az webapp restart --name "$WEBAPP_NAME" --resource-group "$RESOURCE_GROUP"

echo "==> Done. Give it a minute, then check:"
echo "    curl https://${WEBAPP_NAME}.azurewebsites.net/health"
echo "    curl https://${WEBAPP_NAME}.azurewebsites.net/api/company"
