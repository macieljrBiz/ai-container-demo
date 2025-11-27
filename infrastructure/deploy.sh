#!/bin/bash
# ============================================================================
# Script de Deploy - Container App com Azure OpenAI
# ============================================================================

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Deploy: Container App + Azure OpenAI                   ║${NC}"
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"

# ============================================================================
# PARÂMETROS (ajuste conforme necessário)
# ============================================================================
RESOURCE_GROUP="rg-ai-container-demo"
LOCATION="eastus"
CONTAINER_APP_NAME="ai-container-app"
ACR_NAME="acrai$(openssl rand -hex 4)"  # Nome único
AZURE_OPENAI_ENDPOINT="https://YOUR_OPENAI_ENDPOINT.openai.azure.com/"
AZURE_OPENAI_DEPLOYMENT="gpt-4o"

# ============================================================================
# VALIDAÇÃO
# ============================================================================
echo -e "\n${YELLOW}📋 Parâmetros do Deploy:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  Container App: $CONTAINER_APP_NAME"
echo "  ACR: $ACR_NAME"
echo "  OpenAI Endpoint: $AZURE_OPENAI_ENDPOINT"
echo "  OpenAI Deployment: $AZURE_OPENAI_DEPLOYMENT"

read -p "$(echo -e ${YELLOW}Continuar? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deploy cancelado."
    exit 1
fi

# ============================================================================
# STEP 1: Criar Resource Group
# ============================================================================
echo -e "\n${BLUE}📦 Criando Resource Group...${NC}"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION

# ============================================================================
# STEP 2: Build da Imagem no ACR
# ============================================================================
echo -e "\n${BLUE}🔨 Fazendo build da imagem no ACR...${NC}"
echo "Isso pode levar alguns minutos..."

# Primeiro cria o ACR
az acr create \
  --resource-group $RESOURCE_GROUP \
  --name $ACR_NAME \
  --sku Basic \
  --admin-enabled false

# Depois faz o build
az acr build \
  --registry $ACR_NAME \
  --image ai-container-app:latest \
  --file ../container-app/Dockerfile \
  ../container-app

echo -e "${GREEN}✅ Imagem construída com sucesso!${NC}"

# ============================================================================
# STEP 3: Deploy do Template Bicep
# ============================================================================
echo -e "\n${BLUE}🚀 Fazendo deploy da infraestrutura...${NC}"

az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file container-app-complete.bicep \
  --parameters \
    containerAppName=$CONTAINER_APP_NAME \
    acrName=$ACR_NAME \
    azureOpenAIEndpoint=$AZURE_OPENAI_ENDPOINT \
    azureOpenAIDeployment=$AZURE_OPENAI_DEPLOYMENT

# ============================================================================
# OUTPUTS
# ============================================================================
echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ Deploy Concluído!                                    ║${NC}"
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"

FQDN=$(az containerapp show \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --query properties.configuration.ingress.fqdn \
  -o tsv)

echo -e "\n${BLUE}🌐 URL da Aplicação:${NC}"
echo -e "   ${GREEN}https://$FQDN${NC}"

echo -e "\n${BLUE}📊 Ver logs:${NC}"
echo "   az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --follow"

echo -e "\n${BLUE}🗑️  Deletar tudo:${NC}"
echo "   az group delete --name $RESOURCE_GROUP --yes --no-wait"
