#!/bin/bash

# Azure Container Apps Deployment Script
# This script builds the container image and deploys to Azure Container Apps

set -e

# Variables (customize these)
RESOURCE_GROUP="rg-ai-container-demo"
LOCATION="eastus"
ACR_NAME="acraicondemo"
CONTAINER_APP_NAME="ai-container-app"
CONTAINER_APP_ENV="cae-ai-container-app"
LOG_ANALYTICS_NAME="law-ai-container-app"
AZURE_OPENAI_ENDPOINT="https://ansiqueira-3288-resource.cognitiveservices.azure.com/openai/v1/"
AZURE_OPENAI_DEPLOYMENT="gpt-5.1"
AZURE_OPENAI_RESOURCE_GROUP="rg-ansiqueira-3288"
IMAGE_NAME="ai-container-app"
IMAGE_TAG="latest"

echo "🚀 Starting deployment..."

# 1. Create resource group
echo "📦 Creating resource group..."
az group create --name $RESOURCE_GROUP --location $LOCATION

# 2. Create ACR
echo "🐳 Creating Azure Container Registry..."
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled true

# 3. Build and push image to ACR
echo "🔨 Building container image..."
cd ../container-app
az acr build \
  --registry $ACR_NAME \
  --image $IMAGE_NAME:$IMAGE_TAG \
  --file Dockerfile \
  .

cd ../infrastructure

# 4. Create Log Analytics Workspace
echo "📊 Creating Log Analytics Workspace..."
az monitor log-analytics workspace create \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_NAME \
  --location $LOCATION

LOG_ANALYTICS_ID=$(az monitor log-analytics workspace show \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_NAME \
  --query customerId -o tsv)

LOG_ANALYTICS_KEY=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group $RESOURCE_GROUP \
  --workspace-name $LOG_ANALYTICS_NAME \
  --query primarySharedKey -o tsv)

# 5. Create Container Apps Environment
echo "🌍 Creating Container Apps Environment..."
az containerapp env create \
  --name $CONTAINER_APP_ENV \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --logs-workspace-id $LOG_ANALYTICS_ID \
  --logs-workspace-key $LOG_ANALYTICS_KEY

# 6. Get ACR credentials
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query passwords[0].value -o tsv)

# 7. Create Container App with Managed Identity
echo "🚢 Creating Container App..."
az containerapp create \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --environment $CONTAINER_APP_ENV \
  --image ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG} \
  --target-port 8000 \
  --ingress external \
  --cpu 0.25 \
  --memory 0.5Gi \
  --min-replicas 0 \
  --max-replicas 10 \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --env-vars \
    AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT \
    AZURE_OPENAI_DEPLOYMENT=$AZURE_OPENAI_DEPLOYMENT \
  --system-assigned

# 8. Get Managed Identity Principal ID
echo "🔐 Configuring Managed Identity..."
PRINCIPAL_ID=$(az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query identity.principalId -o tsv)

# 9. Assign role to access Azure OpenAI
echo "🔑 Assigning Cognitive Services OpenAI User role..."
OPENAI_SCOPE=$(az cognitiveservices account show \
  --name ansiqueira-3288-resource \
  --resource-group $AZURE_OPENAI_RESOURCE_GROUP \
  --query id -o tsv)

az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee $PRINCIPAL_ID \
  --scope $OPENAI_SCOPE

# 10. Get Container App URL
CONTAINER_APP_URL=$(az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn -o tsv)

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "🌐 Container App URL: https://$CONTAINER_APP_URL"
echo "🔐 Managed Identity Principal ID: $PRINCIPAL_ID"
echo ""
echo "📝 Next steps:"
echo "1. Test the application: curl https://$CONTAINER_APP_URL"
echo "2. View logs: az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --follow"
echo "3. Update image: az acr build --registry $ACR_NAME --image $IMAGE_NAME:$IMAGE_TAG ./container-app && az containerapp update --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --image ${ACR_LOGIN_SERVER}/${IMAGE_NAME}:${IMAGE_TAG}"
