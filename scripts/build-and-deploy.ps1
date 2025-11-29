# ============================================================================
# Build and Deploy - Azure Container Demo
# ============================================================================
# Este script faz o build das imagens no ACR e deploy completo da infraestrutura
# Pode ser executado localmente ou no Azure Cloud Shell
# ============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "rg-ai-container-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [string]$ACRName = "acraicondemo",
    
    [Parameter(Mandatory=$false)]
    [string]$ContainerAppName = "ai-container-app"
)

# Cores para output
function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERRO] $Message" -ForegroundColor Red
}

# ============================================================================
# 1. VERIFICAR SUBSCRIPTION
# ============================================================================
Write-Step "Verificando subscription Azure..."
$subscription = az account show --query name -o tsv
if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Nao conectado ao Azure. Execute: az login"
    exit 1
}
Write-Success "Usando subscription: $subscription"

# ============================================================================
# 2. CRIAR RESOURCE GROUP (se nao existir)
# ============================================================================
Write-Step "Verificando Resource Group..."
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "false") {
    Write-Host "Criando Resource Group $ResourceGroup..."
    az group create --name $ResourceGroup --location $Location --output none
    Write-Success "Resource Group criado"
} else {
    Write-Success "Resource Group ja existe"
}

# ============================================================================
# 3. CRIAR AZURE CONTAINER REGISTRY (se nao existir)
# ============================================================================
Write-Step "Verificando Azure Container Registry..."
$acrExists = az acr show --name $ACRName --resource-group $ResourceGroup 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Criando Azure Container Registry $ACRName..."
    az acr create `
        --resource-group $ResourceGroup `
        --name $ACRName `
        --sku Basic `
        --admin-enabled true `
        --output none
    Write-Success "ACR criado"
} else {
    Write-Success "ACR ja existe"
}

# Pegar login server do ACR
$acrLoginServer = az acr show --name $ACRName --query loginServer -o tsv
Write-Success "ACR Login Server: $acrLoginServer"

# ============================================================================
# 4. BUILD IMAGEM CONTAINER APP NO ACR
# ============================================================================
Write-Step "Fazendo build da imagem Container App no ACR..."
Write-Host "Isso pode levar alguns minutos (build acontece na nuvem)..."

az acr build `
    --registry $ACRName `
    --image "ai-container-app:latest" `
    --image "ai-container-app:$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --file "../container-app/Dockerfile" `
    ../container-app

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Falha no build da imagem Container App"
    exit 1
}
Write-Success "Imagem Container App criada com sucesso"

# ============================================================================
# 5. BUILD IMAGEM AZURE FUNCTIONS NO ACR
# ============================================================================
Write-Step "Fazendo build da imagem Azure Functions no ACR..."
Write-Host "Isso pode levar alguns minutos (build acontece na nuvem)..."

az acr build `
    --registry $ACRName `
    --image "ai-functions:latest" `
    --image "ai-functions:$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    --file "../azure-functions/Dockerfile" `
    ../azure-functions

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Falha no build da imagem Azure Functions"
    exit 1
}
Write-Success "Imagem Azure Functions criada com sucesso"

# ============================================================================
# 6. LISTAR IMAGENS NO ACR
# ============================================================================
Write-Step "Imagens disponiveis no ACR:"
az acr repository list --name $ACRName --output table
Write-Host ""
Write-Host "Tags da imagem ai-container-app:"
az acr repository show-tags --name $ACRName --repository ai-container-app --output table
Write-Host ""
Write-Host "Tags da imagem ai-functions:"
az acr repository show-tags --name $ACRName --repository ai-functions --output table

# ============================================================================
# 7. CRIAR MANAGED IDENTITY (antes do deploy)
# ============================================================================
Write-Step "Criando Managed Identity para Container App..."

$identityName = "id-$ContainerAppName"
$identityExists = az identity show --name $identityName --resource-group $ResourceGroup 2>$null

if ($LASTEXITCODE -ne 0) {
    az identity create `
        --name $identityName `
        --resource-group $ResourceGroup `
        --output none
    Write-Success "Managed Identity criada: $identityName"
} else {
    Write-Success "Managed Identity ja existe: $identityName"
}

# ============================================================================
# 8. DEPLOY INFRAESTRUTURA COMPLETA (Bicep)
# ============================================================================
Write-Step "Fazendo deploy da infraestrutura completa com Bicep..."
Write-Host "Isso pode levar alguns minutos..."

# Gerar nome unico para Azure OpenAI
$uniqueSuffix = (Get-Random -Minimum 1000 -Maximum 9999)
$azureOpenAIName = "aoai-demo-$uniqueSuffix"

# Deploy com Bicep
az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "../infrastructure/main.bicep" `
    --parameters `
        acrName=$ACRName `
        containerAppName=$ContainerAppName `
        azureOpenAIName=$azureOpenAIName `
    --output json | Out-File -FilePath "deployment-output.json"

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Falha no deploy da infraestrutura"
    exit 1
}

# Ler outputs do deployment
$deploymentOutput = Get-Content "deployment-output.json" | ConvertFrom-Json
$acrLoginServer = $deploymentOutput.properties.outputs.acrLoginServer.value
$AzureOpenAIEndpoint = $deploymentOutput.properties.outputs.azureOpenAIEndpoint.value
$AzureOpenAIDeployment = $deploymentOutput.properties.outputs.azureOpenAIDeployment.value
$aiFoundryUrl = $deploymentOutput.properties.outputs.aiFoundryPortalUrl.value

Write-Success "Infraestrutura deployada com sucesso"
Write-Host "  Azure OpenAI: $AzureOpenAIEndpoint" -ForegroundColor Gray
Write-Host "  Model Deployment: $AzureOpenAIDeployment" -ForegroundColor Gray
Write-Host "  AI Foundry: $aiFoundryUrl" -ForegroundColor Gray

# ============================================================================
# 9. ATUALIZAR CONTAINER APP COM IMAGEM DO ACR
# ============================================================================
Write-Step "Atualizando Container App com a imagem do ACR..."

az containerapp update `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --image "$acrLoginServer/ai-container-app:latest" `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-ErrorMsg "Falha ao atualizar Container App"
    exit 1
}
Write-Success "Container App atualizado com sucesso"

# ============================================================================
# 10. OBTER URLS DOS RECURSOS
# ============================================================================
Write-Step "Informacoes dos recursos deployados:"

# Container App URL
$containerAppUrl = az containerapp show `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --query properties.configuration.ingress.fqdn -o tsv

if (-not [string]::IsNullOrEmpty($containerAppUrl)) {
    Write-Host ""
    Write-Host "Container App URL:" -ForegroundColor Cyan
    Write-Host "   https://$containerAppUrl" -ForegroundColor Green
}

# ACR Repositories
Write-Host ""
Write-Host "Container Registry:" -ForegroundColor Cyan
Write-Host "   $acrLoginServer" -ForegroundColor Green
Write-Host "   - ai-container-app:latest" -ForegroundColor Gray
Write-Host "   - ai-functions:latest" -ForegroundColor Gray

# Azure OpenAI
Write-Host ""
Write-Host "Azure OpenAI:" -ForegroundColor Cyan
Write-Host "   Endpoint: $AzureOpenAIEndpoint" -ForegroundColor Green
Write-Host "   Deployment: $AzureOpenAIDeployment" -ForegroundColor Green

# AI Foundry Portal
Write-Host ""
Write-Host "AI Foundry Portal:" -ForegroundColor Cyan
Write-Host "   $aiFoundryUrl" -ForegroundColor Green

# ============================================================================
# FINALIZADO
# ============================================================================
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "DEPLOY COMPLETO!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Proximos passos:" -ForegroundColor Cyan
Write-Host "1. Acesse a URL do Container App para testar" -ForegroundColor White
Write-Host "2. Verifique os logs no Azure Portal" -ForegroundColor White
Write-Host "3. Configure alertas e monitoramento conforme necessario" -ForegroundColor White
Write-Host ""
