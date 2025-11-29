# ============================================================================
# Setup Azure + GitHub - AI Container Demo
# ============================================================================
# Este script automatiza toda a configuração necessária:
# - Detecta seu repositório GitHub automaticamente
# - Cria Service Principal e OIDC no Azure
# - Cria Managed Identity
# - Configura GitHub Secrets
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
    [string]$AzureOpenAIName
)

# Funções de output
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

function Write-Warning {
    param([string]$Message)
    Write-Host "[AVISO] $Message" -ForegroundColor Yellow
}

# ============================================================================
# 1. DETECTAR REPOSITÓRIO GITHUB ATUAL
# ============================================================================
Write-Step "Detectando repositório GitHub..."

# Ir para a raiz do repositório (caso esteja em subpasta)
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = git -C $scriptPath rev-parse --show-toplevel 2>$null

if ($LASTEXITCODE -eq 0 -and $repoRoot) {
    Push-Location $repoRoot
    Write-Host "Mudando para raiz do repositório: $repoRoot" -ForegroundColor Gray
}

# Verificar se está em um repositório Git
$gitCheck = git rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Este diretório não é um repositório Git!"
    Write-Host "Por favor, execute este script de dentro do repositório clonado." -ForegroundColor Yellow
    exit 1
}

# Obter URL remota
$remoteUrl = git config --get remote.origin.url
if ([string]::IsNullOrEmpty($remoteUrl)) {
    Write-Error "Não foi possível detectar a URL remota do repositório!"
    exit 1
}

# Extrair owner/repo da URL (suporta HTTPS e SSH)
if ($remoteUrl -match 'github\.com[:/](.+)/(.+?)(\.git)?$') {
    $repoOwner = $matches[1]
    $repoName = $matches[2]
    $gitHubRepo = "$repoOwner/$repoName"
    
    Write-Success "Repositório detectado: $gitHubRepo"
} else {
    Write-Error "URL remota não é do GitHub: $remoteUrl"
    exit 1
}

# Detectar branch atual
$currentBranch = git branch --show-current
if ([string]::IsNullOrEmpty($currentBranch)) {
    $currentBranch = "main"
    Write-Warning "Não foi possível detectar branch. Usando padrão: main"
} else {
    Write-Success "Branch atual: $currentBranch"
}

# ============================================================================
# 2. VERIFICAR AZURE CLI E LOGIN
# ============================================================================
Write-Step "Verificando Azure CLI..."
$subscription = az account show --query "{name:name, id:id, tenantId:tenantId}" -o json 2>$null | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Não conectado ao Azure. Execute: az login"
    exit 1
}

$subscriptionId = $subscription.id
$tenantId = $subscription.tenantId
Write-Success "Subscription: $($subscription.name) ($subscriptionId)"
Write-Success "Tenant ID: $tenantId"

# ============================================================================
# 3. VERIFICAR GITHUB CLI
# ============================================================================
Write-Step "Verificando GitHub CLI..."

$ghInstalled = Get-Command gh -ErrorAction SilentlyContinue
if (-not $ghInstalled) {
    Write-Error "GitHub CLI (gh) não está instalado!"
    Write-Host ""
    Write-Host "Instale o GitHub CLI para continuar:" -ForegroundColor Yellow
    Write-Host "  https://cli.github.com/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Alternativamente, você pode configurar os secrets manualmente:" -ForegroundColor Yellow
    Write-Host "  1. Vá para: https://github.com/$gitHubRepo/settings/secrets/actions" -ForegroundColor Cyan
    Write-Host "  2. Adicione os seguintes secrets:" -ForegroundColor Cyan
    Write-Host ""
    exit 1
}

# Verificar autenticação do GitHub CLI
Write-Step "Verificando autenticação no GitHub..."
$authStatus = gh auth status 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Warning "GitHub CLI não está autenticado!"
    Write-Host ""
    Write-Host "Iniciando processo de autenticação..." -ForegroundColor Cyan
    gh auth login
    
    # Verificar novamente
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha na autenticação do GitHub CLI"
        exit 1
    }
}

Write-Success "Autenticado no GitHub"

# Verificar permissões no repositório
Write-Step "Verificando permissões no repositório..."
$repoInfo = gh repo view $gitHubRepo --json viewerPermission,viewerCanAdminister 2>$null | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Não foi possível acessar o repositório: $gitHubRepo"
    Write-Host "Certifique-se de que você tem permissão de acesso ao repositório." -ForegroundColor Yellow
    exit 1
}

if (-not $repoInfo.viewerCanAdminister) {
    Write-Error "Você não tem permissão de administrador neste repositório!"
    Write-Host "Você precisa de permissão de 'admin' para configurar secrets." -ForegroundColor Yellow
    exit 1
}

Write-Success "Você tem permissões de administrador no repositório"

# ============================================================================
# 4. CRIAR RESOURCE GROUP
# ============================================================================
Write-Step "Criando Resource Group..."
$rgExists = az group exists --name $ResourceGroup

if ($rgExists -eq "false") {
    az group create --name $ResourceGroup --location $Location --output none
    Write-Success "Resource Group criado: $ResourceGroup"
} else {
    Write-Success "Resource Group já existe: $ResourceGroup"
}

# ============================================================================
# 5. CRIAR SERVICE PRINCIPAL PARA GITHUB ACTIONS (OIDC)
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
    Write-Success "App já existe: $appId"
}

# Criar Service Principal se não existir
$spExists = az ad sp show --id $appId --query appId -o tsv 2>$null
if ([string]::IsNullOrEmpty($spExists)) {
    az ad sp create --id $appId --output none
    Write-Success "Service Principal criado"
}

# Obter Object ID do Service Principal
$spObjectId = az ad sp show --id $appId --query id -o tsv

# ============================================================================
# 6. ATRIBUIR ROLES AO SERVICE PRINCIPAL
# ============================================================================
Write-Step "Atribuindo roles ao Service Principal..."

# Contributor role
$contributorAssignment = az role assignment list `
    --assignee $appId `
    --role Contributor `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup" `
    --query "[0].id" -o tsv 2>$null

if ([string]::IsNullOrEmpty($contributorAssignment)) {
    az role assignment create `
        --assignee $appId `
        --role Contributor `
        --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup" `
        --output none
    Write-Success "Role 'Contributor' atribuída"
} else {
    Write-Success "Role 'Contributor' já existe"
}

# User Access Administrator role
$uaaAssignment = az role assignment list `
    --assignee $appId `
    --role "User Access Administrator" `
    --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup" `
    --query "[0].id" -o tsv 2>$null

if ([string]::IsNullOrEmpty($uaaAssignment)) {
    az role assignment create `
        --assignee $appId `
        --role "User Access Administrator" `
        --scope "/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup" `
        --output none
    Write-Success "Role 'User Access Administrator' atribuída"
} else {
    Write-Success "Role 'User Access Administrator' já existe"
}

# ============================================================================
# 7. CONFIGURAR OIDC (FEDERATED CREDENTIAL)
# ============================================================================
Write-Step "Configurando OIDC para GitHub Actions..."

$subject = "repo:$gitHubRepo:ref:refs/heads/$currentBranch"
$credentialName = "github-oidc-$currentBranch"

# Verificar se já existe e se o subject está correto
$existingCreds = az ad app federated-credential list --id $appId 2>$null | ConvertFrom-Json
$matchingCred = $existingCreds | Where-Object { $_.name -eq $credentialName }

if ($matchingCred) {
    # Verificar se o subject está correto
    if ($matchingCred.subject -ne $subject) {
        Write-Host "OIDC existe mas com subject diferente. Deletando e recriando..."
        az ad app federated-credential delete --id $appId --federated-credential-id $credentialName --output none 2>$null
        $matchingCred = $null
    } else {
        Write-Success "OIDC já configurado corretamente para: $subject"
    }
}

if (-not $matchingCred) {
    Write-Host "Criando federated credential..."
    
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
}

# ============================================================================
# 8. CRIAR MANAGED IDENTITY PARA CONTAINER APP
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
    Write-Success "Managed Identity já existe: $identityName"
}

$identityId = az identity show --name $identityName --resource-group $ResourceGroup --query id -o tsv
$identityClientId = az identity show --name $identityName --resource-group $ResourceGroup --query clientId -o tsv

# ============================================================================
# 9. CONFIGURAR GITHUB SECRETS
# ============================================================================
Write-Step "Configurando GitHub Secrets no repositório: $gitHubRepo"

Write-Host "Criando/atualizando secrets..."

gh secret set AZURE_TENANT_ID --body $tenantId --repo $gitHubRepo
gh secret set AZURE_CLIENT_ID --body $appId --repo $gitHubRepo
gh secret set AZURE_SUBSCRIPTION_ID --body $subscriptionId --repo $gitHubRepo
gh secret set RESOURCE_GROUP --body $ResourceGroup --repo $gitHubRepo
gh secret set CONTAINER_APP_NAME --body $ContainerAppName --repo $gitHubRepo
gh secret set ACR_NAME --body $ACRName --repo $gitHubRepo
gh secret set OPENAI_NAME --body $AzureOpenAIName --repo $gitHubRepo

Write-Success "Secrets configurados no GitHub!"

# ============================================================================
# RESUMO FINAL
# ============================================================================
Write-Host ""
Write-Host "============================================================================" -ForegroundColor Green
Write-Host "CONFIGURAÇÃO CONCLUÍDA COM SUCESSO!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Informações importantes:" -ForegroundColor Cyan
Write-Host ""
Write-Host "GitHub Repository:" -ForegroundColor White
Write-Host "  Repository: $gitHubRepo" -ForegroundColor Gray
Write-Host "  Branch: $currentBranch" -ForegroundColor Gray
Write-Host "  OIDC Subject: $subject" -ForegroundColor Gray
Write-Host ""
Write-Host "Service Principal:" -ForegroundColor White
Write-Host "  Client ID: $appId" -ForegroundColor Gray
Write-Host "  Object ID: $spObjectId" -ForegroundColor Gray
Write-Host ""
Write-Host "Managed Identity:" -ForegroundColor White
Write-Host "  Name: $identityName" -ForegroundColor Gray
Write-Host "  Client ID: $identityClientId" -ForegroundColor Gray
Write-Host ""
Write-Host "Azure Resources:" -ForegroundColor White
Write-Host "  Subscription: $subscriptionId" -ForegroundColor Gray
Write-Host "  Tenant: $tenantId" -ForegroundColor Gray
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor Gray
Write-Host "  Location: $Location" -ForegroundColor Gray
Write-Host ""
Write-Host "Próximos passos:" -ForegroundColor Cyan
Write-Host "1. Acesse: https://github.com/$gitHubRepo/actions" -ForegroundColor White
Write-Host "2. Execute o workflow '1️⃣ Deploy Infrastructure'" -ForegroundColor White
Write-Host "3. Aguarde e depois execute '2️⃣ Build and Deploy App'" -ForegroundColor White
Write-Host ""
Write-Host "✅ Seu repositório está pronto para usar GitHub Actions!" -ForegroundColor Green
Write-Host ""
