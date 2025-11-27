#!/bin/bash
# ============================================================================
# Script de Deploy - Container App (apenas infraestrutura)
# ============================================================================
# PRÉ-REQUISITOS:
# 1. ACR já criado com a imagem construída
# 2. Variáveis de ambiente configuradas na imagem Docker
# 
# Este script apenas cria o Container App apontando para o ACR existente
# ============================================================================

set -e

# Cores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Deploy: Container App (infraestrutura apenas)          ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"

# ============================================================================
# PARÂMETROS - Ajuste conforme necessário
# ============================================================================
RESOURCE_GROUP="rg-ai-container-demo"
LOCATION="eastus"
CONTAINER_APP_NAME="ai-container-app"
ACR_NAME="SEU_ACR_EXISTENTE"  # ⚠️ EDITE: nome do ACR já existente
CONTAINER_IMAGE_NAME="ai-container-app:latest"
AZURE_OPENAI_ENDPOINT="https://SEU-MODELO.openai.azure.com/"  # ⚠️ EDITE: endpoint do seu modelo
AZURE_OPENAI_DEPLOYMENT="gpt-4o"
OPENAI_RESOURCE_ID="/subscriptions/SUB_ID/resourceGroups/RG_NAME/providers/Microsoft.CognitiveServices/accounts/OPENAI_NAME"  # ⚠️ EDITE

# ============================================================================
# VALIDAÇÃO DE PRÉ-REQUISITOS
# ============================================================================
echo -e "\n${YELLOW}🔍 Verificando pré-requisitos...${NC}"

# Verifica se o ACR existe
if ! az acr show --name $ACR_NAME --query "id" -o tsv &>/dev/null; then
    echo -e "${RED}❌ ERRO: ACR '$ACR_NAME' não encontrado!${NC}"
    echo -e "${YELLOW}Execute primeiro:${NC}"
    echo -e "  1. Crie o ACR: az acr create --name <nome> --resource-group <rg> --sku Basic"
    echo -e "  2. Construa a imagem: az acr build --registry <nome> --image $CONTAINER_IMAGE_NAME --file ../container-app/Dockerfile ../container-app"
    exit 1
fi

# Verifica se a imagem existe no ACR
if ! az acr repository show --name $ACR_NAME --repository "${CONTAINER_IMAGE_NAME%:*}" &>/dev/null; then
    echo -e "${RED}❌ ERRO: Imagem '$CONTAINER_IMAGE_NAME' não encontrada no ACR!${NC}"
    echo -e "${YELLOW}Execute:${NC}"
    echo -e "  az acr build --registry $ACR_NAME --image $CONTAINER_IMAGE_NAME --file ../container-app/Dockerfile ../container-app"
    exit 1
fi

echo -e "${GREEN}✅ ACR e imagem encontrados!${NC}"

# ============================================================================
# CONFIRMAÇÃO
# ============================================================================
echo -e "\n${YELLOW}📋 Parâmetros do Deploy:${NC}"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Location: $LOCATION"
echo "  Container App: $CONTAINER_APP_NAME"
echo "  ACR Existente: $ACR_NAME"
echo "  Imagem: $CONTAINER_IMAGE_NAME"

read -p "$(echo -e ${YELLOW}Continuar com o deploy? [y/N]: ${NC})" -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deploy cancelado."
    exit 1
fi

# ============================================================================
# STEP 1: Criar Resource Group (se não existir)
# ============================================================================
echo -e "\n${BLUE}📦 Criando/verificando Resource Group...${NC}"
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --output none

# ============================================================================
# STEP 2: Deploy do Container App
# ============================================================================
echo -e "\n${BLUE}🚀 Fazendo deploy do Container App...${NC}"

az deployment group create \
  --resource-group $RESOURCE_GROUP \
  --template-file container-app-complete.bicep \
  --parameters \
    containerAppName=$CONTAINER_APP_NAME \
    acrName=$ACR_NAME \
    containerImageName=$CONTAINER_IMAGE_NAME \
    azureOpenAIEndpoint="$AZURE_OPENAI_ENDPOINT" \
    azureOpenAIDeployment="$AZURE_OPENAI_DEPLOYMENT" \
    openAiResourceId="$OPENAI_RESOURCE_ID"

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
