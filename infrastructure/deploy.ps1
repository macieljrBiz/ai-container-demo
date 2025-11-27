# ============================================================================
# Script de Deploy - Container App com Azure OpenAI
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Deploy: Container App + Azure OpenAI                   ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ============================================================================
# PARÂMETROS (ajuste conforme necessário)
# ============================================================================
$RESOURCE_GROUP = "rg-ai-container-demo"
$LOCATION = "eastus"
$CONTAINER_APP_NAME = "ai-container-app"
$ACR_NAME = "acrai$(Get-Random -Maximum 99999)"  # Nome único
$AZURE_OPENAI_ENDPOINT = "https://YOUR_OPENAI_ENDPOINT.openai.azure.com/"
$AZURE_OPENAI_DEPLOYMENT = "gpt-4o"
$CONTAINER_IMAGE_NAME = "ai-container-app:latest"

# ============================================================================
# VALIDAÇÃO
# ============================================================================
Write-Host "`n📋 Parâmetros do Deploy:" -ForegroundColor Yellow
Write-Host "  Resource Group: $RESOURCE_GROUP"
Write-Host "  Location: $LOCATION"
Write-Host "  Container App: $CONTAINER_APP_NAME"
Write-Host "  ACR: $ACR_NAME"
Write-Host "  Container Image: $CONTAINER_IMAGE_NAME"
Write-Host "  OpenAI Endpoint: $AZURE_OPENAI_ENDPOINT"
Write-Host "  OpenAI Deployment: $AZURE_OPENAI_DEPLOYMENT"

$confirmation = Read-Host "`nContinuar? [y/N]"
if ($confirmation -ne 'y') {
    Write-Host "Deploy cancelado." -ForegroundColor Red
    exit
}

# ============================================================================
# STEP 1: Criar Resource Group
# ============================================================================
Write-Host "`n📦 Criando Resource Group..." -ForegroundColor Cyan
az group create `
  --name $RESOURCE_GROUP `
  --location $LOCATION

# ============================================================================
# STEP 2: Build da Imagem no ACR
# ============================================================================
Write-Host "`n🔨 Fazendo build da imagem no ACR..." -ForegroundColor Cyan
Write-Host "Isso pode levar alguns minutos..."

# Primeiro cria o ACR
az acr create `
  --resource-group $RESOURCE_GROUP `
  --name $ACR_NAME `
  --sku Basic `
  --admin-enabled false

# Depois faz o build
az acr build `
  --registry $ACR_NAME `
  --image $CONTAINER_IMAGE_NAME `
  --file ../container-app/Dockerfile `
  ../container-app

Write-Host "✅ Imagem construída com sucesso!" -ForegroundColor Green

# ============================================================================
# STEP 3: Deploy do Template Bicep
# ============================================================================
Write-Host "`n🚀 Fazendo deploy da infraestrutura..." -ForegroundColor Cyan

az deployment group create `
  --resource-group $RESOURCE_GROUP `
  --template-file container-app-complete.bicep `
  --parameters `
    containerAppName=$CONTAINER_APP_NAME `
    acrName=$ACR_NAME `
    containerImageName=$CONTAINER_IMAGE_NAME `
    azureOpenAIEndpoint=$AZURE_OPENAI_ENDPOINT `
    azureOpenAIDeployment=$AZURE_OPENAI_DEPLOYMENT

# ============================================================================
# OUTPUTS
# ============================================================================
Write-Host "`n╔══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  ✅ Deploy Concluído!                                    ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Green

$FQDN = az containerapp show `
  --name $CONTAINER_APP_NAME `
  --resource-group $RESOURCE_GROUP `
  --query properties.configuration.ingress.fqdn `
  -o tsv

Write-Host "`n🌐 URL da Aplicação:" -ForegroundColor Cyan
Write-Host "   https://$FQDN" -ForegroundColor Green

Write-Host "`n📊 Ver logs:" -ForegroundColor Cyan
Write-Host "   az containerapp logs show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --follow"

Write-Host "`n🗑️  Deletar tudo:" -ForegroundColor Cyan
Write-Host "   az group delete --name $RESOURCE_GROUP --yes --no-wait"
