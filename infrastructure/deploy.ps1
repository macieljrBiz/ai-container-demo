# ============================================================================
# Script de Deploy - Container App (apenas infraestrutura)
# ============================================================================
# PRÉ-REQUISITOS:
# 1. ACR já criado com a imagem construída
# 2. Variáveis de ambiente configuradas na imagem Docker
# 
# Este script apenas cria o Container App apontando para o ACR existente
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  Deploy: Container App (infraestrutura apenas)          ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# ============================================================================
# PARÂMETROS - Ajuste conforme necessário
# ============================================================================
$RESOURCE_GROUP = "rg-ai-container-demo"
$LOCATION = "eastus"
$CONTAINER_APP_NAME = "ai-container-app"
$ACR_NAME = "SEU_ACR_EXISTENTE"  # ⚠️ EDITE: nome do ACR já existente
$CONTAINER_IMAGE_NAME = "ai-container-app:latest"

# ============================================================================
# VALIDAÇÃO DE PRÉ-REQUISITOS
# ============================================================================
Write-Host "`n🔍 Verificando pré-requisitos..." -ForegroundColor Yellow

# Verifica se o ACR existe
try {
    az acr show --name $ACR_NAME --query "id" -o tsv 2>$null | Out-Null
} catch {
    Write-Host "❌ ERRO: ACR '$ACR_NAME' não encontrado!" -ForegroundColor Red
    Write-Host "Execute primeiro:" -ForegroundColor Yellow
    Write-Host "  1. Crie o ACR: az acr create --name <nome> --resource-group <rg> --sku Basic"
    Write-Host "  2. Construa a imagem: az acr build --registry <nome> --image $CONTAINER_IMAGE_NAME --file ../container-app/Dockerfile ../container-app"
    exit 1
}

# Verifica se a imagem existe no ACR
$imageRepo = $CONTAINER_IMAGE_NAME -replace ':.*$', ''
try {
    az acr repository show --name $ACR_NAME --repository $imageRepo 2>$null | Out-Null
} catch {
    Write-Host "❌ ERRO: Imagem '$CONTAINER_IMAGE_NAME' não encontrada no ACR!" -ForegroundColor Red
    Write-Host "Execute:" -ForegroundColor Yellow
    Write-Host "  az acr build --registry $ACR_NAME --image $CONTAINER_IMAGE_NAME --file ../container-app/Dockerfile ../container-app"
    exit 1
}

Write-Host "✅ ACR e imagem encontrados!" -ForegroundColor Green

# ============================================================================
# CONFIRMAÇÃO
# ============================================================================
Write-Host "`n📋 Parâmetros do Deploy:" -ForegroundColor Yellow
Write-Host "  Resource Group: $RESOURCE_GROUP"
Write-Host "  Location: $LOCATION"
Write-Host "  Container App: $CONTAINER_APP_NAME"
Write-Host "  ACR Existente: $ACR_NAME"
Write-Host "  Imagem: $CONTAINER_IMAGE_NAME"

$confirmation = Read-Host "`nContinuar com o deploy? [y/N]"
if ($confirmation -ne 'y') {
    Write-Host "Deploy cancelado." -ForegroundColor Red
    exit
}

# ============================================================================
# STEP 1: Criar Resource Group (se não existir)
# ============================================================================
Write-Host "`n📦 Criando/verificando Resource Group..." -ForegroundColor Cyan
az group create `
  --name $RESOURCE_GROUP `
  --location $LOCATION `
  --output none

# ============================================================================
# STEP 2: Deploy do Container App
# ============================================================================
Write-Host "`n🚀 Fazendo deploy do Container App..." -ForegroundColor Cyan

az deployment group create `
  --resource-group $RESOURCE_GROUP `
  --template-file container-app-complete.bicep `
  --parameters `
    containerAppName=$CONTAINER_APP_NAME `
    acrName=$ACR_NAME `
    containerImageName=$CONTAINER_IMAGE_NAME

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
