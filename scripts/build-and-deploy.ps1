# ============================================================================
# Setup Azure Infrastructure - AI Container Demo
# ============================================================================
# Este script configura Service Principal, OIDC, Managed Identity e GitHub Secrets
# Executar UMA VEZ para configurar a infraestrutura inicial
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
    [string]$AzureOpenAIName,
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubRepo = "AndressaSiqueira/ai-container-demo",
    
    [Parameter(Mandatory=$false)]
    [string]$GitHubBranch = "main"
)

# Funcoes de output
function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERRO] $Message" -ForegroundColor Red
}

# ============================================================================
# 1. VERIFICAR AZURE CLI E LOGIN
# ============================================================================
Write-Step "Verificando Azure CLI..."
$subscription = az account show --query "{name:name, id:id, tenantId:tenantId}" -o json 2>$null | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Nao conectado ao Azure. Execute: az login"
    exit 1
}

$subscriptionId = $subscription.id
$tenantId = $subscription.tenantId
Write-Success "Subscription: $($subscription.name) ($subscriptionId)"
Write-Success "Tenant ID: $tenantId"

# ============================================================================
# 2. CRIAR RESOURCE GROUP
# ============================================================================
Write-Step "Criando Resource Group..."
$rgExists = az group exists --name $ResourceGroup

if ($rgExists -eq "false") {
    az group create --name $ResourceGroup --location $Location --output none
    Write-Success "Resource Group criado: $ResourceGroup"
} else {
    Write-Success "Resource Group ja existe: $ResourceGroup"
}

# ============================================================================
# 3. CRIAR SERVICE PRINCIPAL PARA GITHUB ACTIONS (OIDC)
# ============================================================================
Write-Step "Criando Service Principal para GitHub Actions..."

$appName = "sp-github-$ResourceGroup"
$existingApp = az ad app list --display-name $appName --query "[0].appId" -o tsv 2>$null

if ([string]::IsNullOrEmpty($existingApp)) {
    Write-Host "Criando novo App Registration..."
    $appId = az ad app create --display-name $appName --query appId -o tsv
    Write-Success "App criado: $appId"
} else {
    $appId = $existingApp
    Write-Success "App ja existe: $appId"
}

# Criar Service Principal se nao existir
$spExists = az ad sp show --id $appId --query appId -o tsv 2>$null
if ([string]::IsNullOrEmpty($spExists)) {
    az ad sp create --id $appId --output none
    Write-Success "Service Principal criado"
}

# Obter Object ID do Service Principal
$spObjectId = az ad sp show --id $appId --query id -o tsv

# ============================================================================
# 4. ATRIBUIR ROLES AO SERVICE PRINCIPAL
# ============================================================================
Write-Step "Atribuindo roles ao Service Principal..."

# Contributor role
az role assignment create `
    --assignee $appId `
    --role Contributor `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup" `
    --output none

# User Access Administrator role (necessario para criar role assignments)
az role assignment create `
    --assignee $appId `
    --role "User Access Administrator" `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup" `
    --output none

Write-Success "Roles atribuidas: Contributor + User Access Administrator"

# ============================================================================
# 5. CONFIGURAR OIDC (FEDERATED CREDENTIAL)
# ============================================================================
Write-Step "Configurando OIDC para GitHub Actions..."

$subject = "repo:$GitHubRepo:ref:refs/heads/$GitHubBranch"
$credentialName = "github-oidc-$GitHubBranch"

# Verificar se ja existe
$existingCred = az ad app federated-credential list --id $appId --query "[?name=='$credentialName'].name" -o tsv 2>$null

if ([string]::IsNullOrEmpty($existingCred)) {
    Write-Host "Criando federated credential..."
    
    # Criar JSON temporario para evitar problemas de parsing
    $oidcParams = @{
        name = $credentialName
        issuer = "https://token.actions.githubusercontent.com"
        subject = $subject
        audiences = @("api://AzureADTokenExchange")
    }
    
    $tempFile = [System.IO.Path]::GetTempFileName()
    $oidcParams | ConvertTo-Json | Set-Content -Path $tempFile -Encoding UTF8
    
    az ad app federated-credential create --id $appId --parameters "@$tempFile" --output none
    Remove-Item $tempFile
    
    Write-Success "OIDC configurado para: $subject"
} else {
    Write-Success "OIDC ja configurado"
}

# ============================================================================
# 6. CRIAR MANAGED IDENTITY PARA CONTAINER APP
# ============================================================================
Write-Step "Criando Managed Identity..."

$identityName = "id-$ContainerAppName"
$identityExists = az identity show --name $identityName --resource-group $ResourceGroup --query id -o tsv 2>$null

if ([string]::IsNullOrEmpty($identityExists)) {
    az identity create `
        --name $identityName `
        --resource-group $ResourceGroup `
        --location $Location `
        --output none
    Write-Success "Managed Identity criada: $identityName"
} else {
    Write-Success "Managed Identity ja existe: $identityName"
}

$identityId = az identity show --name $identityName --resource-group $ResourceGroup --query id -o tsv
$identityClientId = az identity show --name $identityName --resource-group $ResourceGroup --query clientId -o tsv

# ============================================================================
# 7. CONFIGURAR GITHUB SECRETS
# ============================================================================
Write-Step "Configurando GitHub Secrets..."

# Verificar se gh CLI esta instalado e autenticado
$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghInstalled) {
    Write-Host "GitHub CLI (gh) nao encontrado." -ForegroundColor Yellow
    Write-Host "Instale em: https://cli.github.com/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Secrets para configurar manualmente:" -ForegroundColor Cyan
    Write-Host "AZURE_TENANT_ID=$tenantId"
    Write-Host "AZURE_CLIENT_ID=$appId"
    Write-Host "AZURE_SUBSCRIPTION_ID=$subscriptionId"
    Write-Host "RESOURCE_GROUP=$ResourceGroup"
    Write-Host "CONTAINER_APP_NAME=$ContainerAppName"
    Write-Host "ACR_NAME=$ACRName"
    Write-Host "OPENAI_NAME=$AzureOpenAIName"
} else {
    # Verificar autenticacao do gh
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "GitHub CLI nao autenticado. Execute: gh auth login" -ForegroundColor Yellow
        gh auth login
        
        # Verificar novamente
        $authStatus = gh auth status 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Falha na autenticacao do GitHub CLI"
            exit 1
        }
    }
    
    Write-Host "Criando/atualizando secrets no GitHub..."
    
    gh secret set AZURE_TENANT_ID --body $tenantId --repo $GitHubRepo
    gh secret set AZURE_CLIENT_ID --body $appId --repo $GitHubRepo
    gh secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $GitHubRepo
    gh secret set RESOURCE_GROUP --body $ResourceGroup --repo $GitHubRepo
    gh secret set CONTAINER_APP_NAME --body $ContainerAppName --repo $GitHubRepo
    gh secret set ACR_NAME --body $ACRName --repo $GitHubRepo
    gh secret set OPENAI_NAME --body $AzureOpenAIName --repo $GitHubRepo
    
    Write-Success "Secrets configurados no GitHub"
}

# ============================================================================
# RESUMO FINAL
# ============================================================================
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "CONFIGURACAO CONCLUIDA COM SUCESSO!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Informacoes importantes:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Service Principal:" -ForegroundColor White
Write-Host "  Client ID: $appId" -ForegroundColor Gray
Write-Host "  Object ID: $spObjectId" -ForegroundColor Gray
Write-Host ""
Write-Host "Managed Identity:" -ForegroundColor White
Write-Host "  Name: $identityName" -ForegroundColor Gray
Write-Host "  Client ID: $identityClientId" -ForegroundColor Gray
Write-Host "  Resource ID: $identityId" -ForegroundColor Gray
Write-Host ""
Write-Host "Azure Resources:" -ForegroundColor White
Write-Host "  Subscription: $subscriptionId" -ForegroundColor Gray
Write-Host "  Tenant: $tenantId" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray
Write-Host ""
Write-Host "GitHub:" -ForegroundColor White
Write-Host "  Repository: $GitHubRepo" -ForegroundColor Gray
Write-Host "  Branch: $GitHubBranch" -ForegroundColor Gray
Write-Host "  OIDC Subject: $subject" -ForegroundColor Gray
Write-Host ""
Write-Host "Proximos passos:" -ForegroundColor Cyan
Write-Host "1. Execute o workflow 'Deploy Infrastructure' no GitHub Actions" -ForegroundColor White
Write-Host "2. Aguarde o deploy do Bicep (ACR, OpenAI, AI Hub/Project, Container App)" -ForegroundColor White
Write-Host "3. O workflow 'Build and Deploy App' sera acionado automaticamente" -ForegroundColor White
Write-Host ""
