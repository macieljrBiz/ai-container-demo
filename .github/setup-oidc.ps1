<#
.SYNOPSIS
    Configura OIDC automaticamente para GitHub Actions deployment no Azure
    
.DESCRIPTION
    Este script configura automaticamente:
    1. User-Assigned Managed Identity
    2. Role Assignments (Contributor + User Access Administrator)
    3. Federated Identity Credential para GitHub
    4. Gera os valores dos secrets para configurar no GitHub
    
.NOTES
    Requisitos: Azure CLI instalado e autenticado (az login)
#>

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   SETUP AUTOMÁTICO - OIDC GITHUB   " -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# VALIDAR AZURE CLI
# ============================================================================
Write-Host "🔍 Verificando Azure CLI..." -ForegroundColor Yellow

try {
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    if (-not $azVersion) {
        throw "Azure CLI não encontrado"
    }
    Write-Host "✅ Azure CLI instalado" -ForegroundColor Green
} catch {
    Write-Host "❌ ERRO: Azure CLI não está instalado ou não está no PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Instale em: https://aka.ms/azure-cli" -ForegroundColor Yellow
    exit 1
}

# Verificar login
Write-Host "🔍 Verificando autenticação..." -ForegroundColor Yellow
try {
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if (-not $account) {
        throw "Não autenticado"
    }
    Write-Host "✅ Autenticado como: $($account.user.name)" -ForegroundColor Green
    Write-Host "   Subscription: $($account.name)" -ForegroundColor Gray
} catch {
    Write-Host "❌ ERRO: Não autenticado no Azure" -ForegroundColor Red
    Write-Host ""
    Write-Host "Execute: az login" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# ============================================================================
# COLETAR INFORMAÇÕES
# ============================================================================
Write-Host "📝 Informe os dados necessários:" -ForegroundColor Cyan
Write-Host ""

# GitHub Organization/Owner
$defaultGithubOrg = "AndressaSiqueira"
$githubOrg = Read-Host "GitHub Organization/Owner [$defaultGithubOrg]"
if ([string]::IsNullOrWhiteSpace($githubOrg)) {
    $githubOrg = $defaultGithubOrg
}

# GitHub Repository
$defaultGithubRepo = "Webapp"
$githubRepo = Read-Host "GitHub Repository [$defaultGithubRepo]"
if ([string]::IsNullOrWhiteSpace($githubRepo)) {
    $githubRepo = $defaultGithubRepo
}

# Branch
$defaultBranch = "master"
$branch = Read-Host "Branch do GitHub [$defaultBranch]"
if ([string]::IsNullOrWhiteSpace($branch)) {
    $branch = $defaultBranch
}

# Resource Group
$defaultRG = "rg-github-actions-oidc"
$resourceGroup = Read-Host "Resource Group para Managed Identity [$defaultRG]"
if ([string]::IsNullOrWhiteSpace($resourceGroup)) {
    $resourceGroup = $defaultRG
}

# Location
$defaultLocation = "brazilsouth"
$location = Read-Host "Location [$defaultLocation]"
if ([string]::IsNullOrWhiteSpace($location)) {
    $location = $defaultLocation
}

# Identity Name
$defaultIdentityName = "id-github-actions-deploy"
$identityName = Read-Host "Nome da Managed Identity [$defaultIdentityName]"
if ([string]::IsNullOrWhiteSpace($identityName)) {
    $identityName = $defaultIdentityName
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "   CONFIGURAÇÕES                    " -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "GitHub: $githubOrg/$githubRepo" -ForegroundColor White
Write-Host "Branch: $branch" -ForegroundColor White
Write-Host "Resource Group: $resourceGroup" -ForegroundColor White
Write-Host "Location: $location" -ForegroundColor White
Write-Host "Identity Name: $identityName" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Confirma? (Y/n)"
if ($confirm -eq 'n' -or $confirm -eq 'N') {
    Write-Host "❌ Cancelado pelo usuário" -ForegroundColor Red
    exit 0
}

Write-Host ""

# ============================================================================
# OBTER SUBSCRIPTION ID E TENANT ID
# ============================================================================
Write-Host "🔍 Obtendo informações da subscription..." -ForegroundColor Yellow

$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv

Write-Host "✅ Subscription ID: $subscriptionId" -ForegroundColor Green
Write-Host "✅ Tenant ID: $tenantId" -ForegroundColor Green
Write-Host ""

# ============================================================================
# CRIAR RESOURCE GROUP
# ============================================================================
Write-Host "📦 Criando Resource Group..." -ForegroundColor Yellow

$rgExists = az group exists --name $resourceGroup
if ($rgExists -eq "true") {
    Write-Host "⚠️  Resource Group já existe, usando existente" -ForegroundColor Yellow
} else {
    az group create --name $resourceGroup --location $location --output none
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Resource Group criado" -ForegroundColor Green
    } else {
        Write-Host "❌ ERRO ao criar Resource Group" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# ============================================================================
# CRIAR MANAGED IDENTITY
# ============================================================================
Write-Host "🆔 Criando Managed Identity..." -ForegroundColor Yellow

# Verificar se já existe
$identityExists = az identity show --name $identityName --resource-group $resourceGroup 2>$null
if ($identityExists) {
    Write-Host "⚠️  Managed Identity já existe, usando existente" -ForegroundColor Yellow
    $identity = $identityExists | ConvertFrom-Json
} else {
    $identityJson = az identity create `
        --name $identityName `
        --resource-group $resourceGroup `
        --location $location `
        --output json
    
    if ($LASTEXITCODE -eq 0) {
        $identity = $identityJson | ConvertFrom-Json
        Write-Host "✅ Managed Identity criada" -ForegroundColor Green
    } else {
        Write-Host "❌ ERRO ao criar Managed Identity" -ForegroundColor Red
        exit 1
    }
}

$clientId = $identity.clientId
$principalId = $identity.principalId

Write-Host "   Client ID: $clientId" -ForegroundColor Gray
Write-Host "   Principal ID: $principalId" -ForegroundColor Gray
Write-Host ""

# ============================================================================
# ATRIBUIR ROLE ASSIGNMENTS
# ============================================================================
Write-Host "🔐 Atribuindo permissões..." -ForegroundColor Yellow

# Contributor
Write-Host "   → Contributor (subscription-level)..." -ForegroundColor Gray
$contributorExists = az role assignment list `
    --assignee $principalId `
    --role "Contributor" `
    --scope "/subscriptions/$subscriptionId" `
    --query "[0].id" -o tsv 2>$null

if ($contributorExists) {
    Write-Host "   ⚠️  Role Contributor já atribuída" -ForegroundColor Yellow
} else {
    az role assignment create `
        --assignee $clientId `
        --role "Contributor" `
        --scope "/subscriptions/$subscriptionId" `
        --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Role Contributor atribuída" -ForegroundColor Green
    } else {
        Write-Host "   ❌ ERRO ao atribuir Contributor" -ForegroundColor Red
    }
}

# User Access Administrator
Write-Host "   → User Access Administrator (subscription-level)..." -ForegroundColor Gray
$uaaExists = az role assignment list `
    --assignee $principalId `
    --role "User Access Administrator" `
    --scope "/subscriptions/$subscriptionId" `
    --query "[0].id" -o tsv 2>$null

if ($uaaExists) {
    Write-Host "   ⚠️  Role User Access Administrator já atribuída" -ForegroundColor Yellow
} else {
    az role assignment create `
        --assignee $clientId `
        --role "User Access Administrator" `
        --scope "/subscriptions/$subscriptionId" `
        --output none
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Role User Access Administrator atribuída" -ForegroundColor Green
    } else {
        Write-Host "   ❌ ERRO ao atribuir User Access Administrator" -ForegroundColor Red
    }
}

Write-Host ""

# ============================================================================
# CRIAR FEDERATED CREDENTIAL
# ============================================================================
Write-Host "🔗 Criando Federated Identity Credential..." -ForegroundColor Yellow

$federatedCredName = "github-actions-federated"
$subject = "repo:$githubOrg/${githubRepo}:ref:refs/heads/$branch"

# Verificar se já existe
$credExists = az identity federated-credential show `
    --name $federatedCredName `
    --identity-name $identityName `
    --resource-group $resourceGroup 2>$null

if ($credExists) {
    Write-Host "⚠️  Federated Credential já existe" -ForegroundColor Yellow
    Write-Host "   Deletando credencial existente..." -ForegroundColor Gray
    
    az identity federated-credential delete `
        --name $federatedCredName `
        --identity-name $identityName `
        --resource-group $resourceGroup `
        --yes `
        --output none
    
    Start-Sleep -Seconds 2
}

# Criar credencial
az identity federated-credential create `
    --name $federatedCredName `
    --identity-name $identityName `
    --resource-group $resourceGroup `
    --issuer "https://token.actions.githubusercontent.com" `
    --subject $subject `
    --audiences "api://AzureADTokenExchange" `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Federated Credential criado" -ForegroundColor Green
    Write-Host "   Subject: $subject" -ForegroundColor Gray
} else {
    Write-Host "❌ ERRO ao criar Federated Credential" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================================
# RESUMO FINAL
# ============================================================================
Write-Host "=====================================" -ForegroundColor Green
Write-Host "   ✅ CONFIGURAÇÃO CONCLUÍDA!       " -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host ""
Write-Host "📋 SECRETS PARA CONFIGURAR NO GITHUB:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Vá para: https://github.com/$githubOrg/$githubRepo/settings/secrets/actions" -ForegroundColor White
Write-Host ""
Write-Host "Adicione os seguintes secrets:" -ForegroundColor Yellow
Write-Host ""
Write-Host "AZURE_CLIENT_ID" -ForegroundColor White
Write-Host "$clientId" -ForegroundColor Green
Write-Host ""
Write-Host "AZURE_TENANT_ID" -ForegroundColor White
Write-Host "$tenantId" -ForegroundColor Green
Write-Host ""
Write-Host "AZURE_SUBSCRIPTION_ID" -ForegroundColor White
Write-Host "$subscriptionId" -ForegroundColor Green
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Próximo passo:" -ForegroundColor Yellow
Write-Host "   1. Configure os 3 secrets acima no GitHub" -ForegroundColor White
Write-Host "   2. Execute o workflow: 1️⃣ Deploy Infrastructure" -ForegroundColor White
Write-Host "   3. Aguarde 2-3 minutos" -ForegroundColor White
Write-Host "   4. Execute o workflow: 2️⃣ Activate Container App" -ForegroundColor White
Write-Host ""
Write-Host "🎉 Deploy profissional pronto!" -ForegroundColor Green
Write-Host ""
