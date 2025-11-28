# ============================================================================
# Build and Deploy - Azure Container Demo
# ============================================================================
# Este script faz o build das imagens no ACR e deploy completo da infraestrutura
# Pode ser executado localmente ou no Azure Cloud Shell
# ============================================================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$ACRName,
    
    [Parameter(Mandatory=$true)]
    [string]$ContainerAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$FunctionAppName,
    
    [Parameter(Mandatory=$false)]
    [string]$AzureOpenAIEndpoint = "",
    
    [Parameter(Mandatory=$false)]
    [string]$AzureOpenAIDeployment = "gpt-4"
)

# Cores para output
function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# ============================================================================
# 1. VERIFICAR SUBSCRIPTION
# ============================================================================
Write-Step "Verificando subscription Azure..."
$subscription = az account show --query name -o tsv
if ($LASTEXITCODE -ne 0) {
    Write-Error "Não conectado ao Azure. Execute: az login"
    exit 1
}
Write-Success "Usando subscription: $subscription"

# ============================================================================
# 2. CRIAR RESOURCE GROUP (se não existir)
# ============================================================================
Write-Step "Verificando Resource Group..."
$rgExists = az group exists --name $ResourceGroup
if ($rgExists -eq "false") {
    Write-Host "Criando Resource Group $ResourceGroup..."
    az group create --name $ResourceGroup --location $Location --output none
    Write-Success "Resource Group criado"
} else {
    Write-Success "Resource Group já existe"
}

# ============================================================================
# 3. CRIAR AZURE CONTAINER REGISTRY (se não existir)
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
    Write-Success "ACR já existe"
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
    --file "./container-app/Dockerfile" `
    ./container-app

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha no build da imagem Container App"
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
    --file "./azure-functions/Dockerfile" `
    ./azure-functions

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha no build da imagem Azure Functions"
    exit 1
}
Write-Success "Imagem Azure Functions criada com sucesso"

# ============================================================================
# 6. LISTAR IMAGENS NO ACR
# ============================================================================
Write-Step "Imagens disponíveis no ACR:"
az acr repository list --name $ACRName --output table
Write-Host ""
Write-Host "Tags da imagem ai-container-app:"
az acr repository show-tags --name $ACRName --repository ai-container-app --output table
Write-Host ""
Write-Host "Tags da imagem ai-functions:"
az acr repository show-tags --name $ACRName --repository ai-functions --output table

# ============================================================================
# 7. DEPLOY CONTAINER APP (Bicep)
# ============================================================================
Write-Step "Fazendo deploy do Container App com Bicep..."

if ([string]::IsNullOrEmpty($AzureOpenAIEndpoint)) {
    Write-Host "Azure OpenAI Endpoint não fornecido. Buscando recursos existentes..."
    $openaiResources = az cognitiveservices account list --query "[?kind=='OpenAI'].{name:name, endpoint:properties.endpoint}" -o json | ConvertFrom-Json
    
    if ($openaiResources.Count -gt 0) {
        $AzureOpenAIEndpoint = $openaiResources[0].endpoint
        Write-Success "Usando Azure OpenAI: $AzureOpenAIEndpoint"
    } else {
        Write-Error "Nenhum recurso Azure OpenAI encontrado. Por favor, forneça o parâmetro -AzureOpenAIEndpoint"
        exit 1
    }
}

# Deploy com Bicep
az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "./infrastructure/container-app.bicep" `
    --parameters `
        acrName=$ACRName `
        containerImage="$acrLoginServer/ai-container-app:latest" `
        azureOpenAIEndpoint=$AzureOpenAIEndpoint `
        azureOpenAIDeployment=$AzureOpenAIDeployment `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha no deploy do Container App"
    exit 1
}
Write-Success "Container App deployado com sucesso"

# ============================================================================
# 8. CONFIGURAR MANAGED IDENTITY NO CONTAINER APP
# ============================================================================
Write-Step "Configurando Managed Identity para Container App..."

# Habilitar system-assigned identity
az containerapp identity assign `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --system-assigned `
    --output none

# Pegar o principal ID da managed identity
$containerAppIdentity = az containerapp identity show `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --query principalId -o tsv

Write-Success "Managed Identity configurada: $containerAppIdentity"

# ============================================================================
# 9. CONFIGURAR PERMISSÕES ACR PULL
# ============================================================================
Write-Step "Configurando permissões ACR Pull para Managed Identity..."

$acrId = az acr show --name $ACRName --query id -o tsv

az role assignment create `
    --assignee $containerAppIdentity `
    --role AcrPull `
    --scope $acrId `
    --output none

Write-Success "Permissão AcrPull atribuída"

# ============================================================================
# 10. CONFIGURAR PERMISSÃO AZURE OPENAI (se necessário)
# ============================================================================
Write-Step "Configurando permissões Azure OpenAI..."

# Extrair o nome do recurso do endpoint
$openaiResourceName = ($AzureOpenAIEndpoint -split '//')[1] -split '\.' | Select-Object -First 1

# Buscar o resource group do OpenAI
$openaiRG = az cognitiveservices account show `
    --name $openaiResourceName `
    --query resourceGroup -o tsv 2>$null

if ($LASTEXITCODE -eq 0) {
    $openaiId = az cognitiveservices account show `
        --name $openaiResourceName `
        --resource-group $openaiRG `
        --query id -o tsv
    
    az role assignment create `
        --assignee $containerAppIdentity `
        --role "Cognitive Services OpenAI User" `
        --scope $openaiId `
        --output none
    
    Write-Success "Permissão Azure OpenAI atribuída"
} else {
    Write-Host "⚠ Não foi possível configurar permissão OpenAI automaticamente" -ForegroundColor Yellow
    Write-Host "  Execute manualmente no Azure Portal ou com az cli" -ForegroundColor Yellow
}

# ============================================================================
# 11. DEPLOY AZURE FUNCTIONS (Bicep)
# ============================================================================
Write-Step "Fazendo deploy do Azure Functions com Bicep..."

az deployment group create `
    --resource-group $ResourceGroup `
    --template-file "./infrastructure/azure-functions.bicep" `
    --parameters `
        functionAppName=$FunctionAppName `
    --output none

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha no deploy do Azure Functions"
    exit 1
}
Write-Success "Azure Functions deployado com sucesso"

# ============================================================================
# 12. OBTER URLS DOS APPS
# ============================================================================
Write-Step "Informações dos recursos deployados:"

# Container App URL
$containerAppUrl = az containerapp show `
    --name $ContainerAppName `
    --resource-group $ResourceGroup `
    --query properties.configuration.ingress.fqdn -o tsv

if (-not [string]::IsNullOrEmpty($containerAppUrl)) {
    Write-Host ""
    Write-Host "🌐 Container App URL:" -ForegroundColor Cyan
    Write-Host "   https://$containerAppUrl" -ForegroundColor Green
}

# Function App URL
$functionAppUrl = az functionapp show `
    --name $FunctionAppName `
    --resource-group $ResourceGroup `
    --query defaultHostName -o tsv 2>$null

if (-not [string]::IsNullOrEmpty($functionAppUrl)) {
    Write-Host ""
    Write-Host "⚡ Function App URL:" -ForegroundColor Cyan
    Write-Host "   https://$functionAppUrl" -ForegroundColor Green
}

# ACR Repositories
Write-Host ""
Write-Host "📦 Container Registry:" -ForegroundColor Cyan
Write-Host "   $acrLoginServer" -ForegroundColor Green
Write-Host "   - ai-container-app:latest" -ForegroundColor Gray
Write-Host "   - ai-functions:latest" -ForegroundColor Gray

# ============================================================================
# FINALIZADO
# ============================================================================
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "✓ DEPLOY COMPLETO!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Cyan
Write-Host "1. Acesse a URL do Container App para testar" -ForegroundColor White
Write-Host "2. Verifique os logs no Azure Portal" -ForegroundColor White
Write-Host "3. Configure alertas e monitoramento conforme necessário" -ForegroundColor White
