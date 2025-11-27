#!/bin/bash

#
# SETUP AUTOMÁTICO - OIDC GITHUB
# 
# Este script configura automaticamente:
# 1. User-Assigned Managed Identity
# 2. Role Assignments (Contributor + User Access Administrator)
# 3. Federated Identity Credential para GitHub
# 4. Gera os valores dos secrets para configurar no GitHub
#
# Requisitos: Azure CLI instalado e autenticado (az login)
#

set -e

echo "====================================="
echo "   SETUP AUTOMÁTICO - OIDC GITHUB   "
echo "====================================="
echo ""

# ============================================================================
# VALIDAR AZURE CLI
# ============================================================================
echo "🔍 Verificando Azure CLI..."

if ! command -v az &> /dev/null; then
    echo "❌ ERRO: Azure CLI não está instalado"
    echo ""
    echo "Instale em: https://aka.ms/azure-cli"
    exit 1
fi

echo "✅ Azure CLI instalado"

# Verificar login
echo "🔍 Verificando autenticação..."
if ! az account show &> /dev/null; then
    echo "❌ ERRO: Não autenticado no Azure"
    echo ""
    echo "Execute: az login"
    exit 1
fi

ACCOUNT_NAME=$(az account show --query user.name -o tsv)
SUBSCRIPTION_NAME=$(az account show --query name -o tsv)
echo "✅ Autenticado como: $ACCOUNT_NAME"
echo "   Subscription: $SUBSCRIPTION_NAME"
echo ""

# ============================================================================
# COLETAR INFORMAÇÕES
# ============================================================================
echo "📝 Informe os dados necessários:"
echo ""

# GitHub Organization/Owner
read -p "GitHub Organization/Owner [AndressaSiqueira]: " GITHUB_ORG
GITHUB_ORG=${GITHUB_ORG:-AndressaSiqueira}

# GitHub Repository
read -p "GitHub Repository [Webapp]: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-Webapp}

# Branch
read -p "Branch do GitHub [master]: " BRANCH
BRANCH=${BRANCH:-master}

# Resource Group
read -p "Resource Group para Managed Identity [rg-github-actions-oidc]: " RESOURCE_GROUP
RESOURCE_GROUP=${RESOURCE_GROUP:-rg-github-actions-oidc}

# Location
read -p "Location [brazilsouth]: " LOCATION
LOCATION=${LOCATION:-brazilsouth}

# Identity Name
read -p "Nome da Managed Identity [id-github-actions-deploy]: " IDENTITY_NAME
IDENTITY_NAME=${IDENTITY_NAME:-id-github-actions-deploy}

echo ""
echo "====================================="
echo "   CONFIGURAÇÕES                    "
echo "====================================="
echo "GitHub: $GITHUB_ORG/$GITHUB_REPO"
echo "Branch: $BRANCH"
echo "Resource Group: $RESOURCE_GROUP"
echo "Location: $LOCATION"
echo "Identity Name: $IDENTITY_NAME"
echo ""

read -p "Confirma? (Y/n): " CONFIRM
if [[ "$CONFIRM" == "n" || "$CONFIRM" == "N" ]]; then
    echo "❌ Cancelado pelo usuário"
    exit 0
fi

echo ""

# ============================================================================
# OBTER SUBSCRIPTION ID E TENANT ID
# ============================================================================
echo "🔍 Obtendo informações da subscription..."

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)

echo "✅ Subscription ID: $SUBSCRIPTION_ID"
echo "✅ Tenant ID: $TENANT_ID"
echo ""

# ============================================================================
# CRIAR RESOURCE GROUP
# ============================================================================
echo "📦 Criando Resource Group..."

if az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
    echo "⚠️  Resource Group já existe, usando existente"
else
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none
    echo "✅ Resource Group criado"
fi

echo ""

# ============================================================================
# CRIAR MANAGED IDENTITY
# ============================================================================
echo "🆔 Criando Managed Identity..."

if az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo "⚠️  Managed Identity já existe, usando existente"
    IDENTITY_JSON=$(az identity show --name "$IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" -o json)
else
    IDENTITY_JSON=$(az identity create \
        --name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --output json)
    echo "✅ Managed Identity criada"
fi

CLIENT_ID=$(echo "$IDENTITY_JSON" | jq -r '.clientId')
PRINCIPAL_ID=$(echo "$IDENTITY_JSON" | jq -r '.principalId')

echo "   Client ID: $CLIENT_ID"
echo "   Principal ID: $PRINCIPAL_ID"
echo ""

# ============================================================================
# ATRIBUIR ROLE ASSIGNMENTS
# ============================================================================
echo "🔐 Atribuindo permissões..."

# Contributor
echo "   → Contributor (subscription-level)..."
if az role assignment list \
    --assignee "$PRINCIPAL_ID" \
    --role "Contributor" \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    --query "[0].id" -o tsv 2>/dev/null | grep -q "."; then
    echo "   ⚠️  Role Contributor já atribuída"
else
    az role assignment create \
        --assignee "$CLIENT_ID" \
        --role "Contributor" \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --output none
    echo "   ✅ Role Contributor atribuída"
fi

# User Access Administrator
echo "   → User Access Administrator (subscription-level)..."
if az role assignment list \
    --assignee "$PRINCIPAL_ID" \
    --role "User Access Administrator" \
    --scope "/subscriptions/$SUBSCRIPTION_ID" \
    --query "[0].id" -o tsv 2>/dev/null | grep -q "."; then
    echo "   ⚠️  Role User Access Administrator já atribuída"
else
    az role assignment create \
        --assignee "$CLIENT_ID" \
        --role "User Access Administrator" \
        --scope "/subscriptions/$SUBSCRIPTION_ID" \
        --output none
    echo "   ✅ Role User Access Administrator atribuída"
fi

echo ""

# ============================================================================
# CRIAR FEDERATED CREDENTIAL
# ============================================================================
echo "🔗 Criando Federated Identity Credential..."

FEDERATED_CRED_NAME="github-actions-federated"
SUBJECT="repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/$BRANCH"

# Verificar se já existe
if az identity federated-credential show \
    --name "$FEDERATED_CRED_NAME" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    echo "⚠️  Federated Credential já existe"
    echo "   Deletando credencial existente..."
    
    az identity federated-credential delete \
        --name "$FEDERATED_CRED_NAME" \
        --identity-name "$IDENTITY_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --yes \
        --output none
    
    sleep 2
fi

# Criar credencial
az identity federated-credential create \
    --name "$FEDERATED_CRED_NAME" \
    --identity-name "$IDENTITY_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --issuer "https://token.actions.githubusercontent.com" \
    --subject "$SUBJECT" \
    --audiences "api://AzureADTokenExchange" \
    --output none

echo "✅ Federated Credential criado"
echo "   Subject: $SUBJECT"
echo ""

# ============================================================================
# RESUMO FINAL
# ============================================================================
echo "====================================="
echo "   ✅ CONFIGURAÇÃO CONCLUÍDA!       "
echo "====================================="
echo ""
echo "📋 SECRETS PARA CONFIGURAR NO GITHUB:"
echo ""
echo "Vá para: https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
echo ""
echo "Adicione os seguintes secrets:"
echo ""
echo "AZURE_CLIENT_ID"
echo "$CLIENT_ID"
echo ""
echo "AZURE_TENANT_ID"
echo "$TENANT_ID"
echo ""
echo "AZURE_SUBSCRIPTION_ID"
echo "$SUBSCRIPTION_ID"
echo ""
echo "====================================="
echo ""
echo "✅ Próximo passo:"
echo "   1. Configure os 3 secrets acima no GitHub"
echo "   2. Execute o workflow: 1️⃣ Deploy Infrastructure"
echo "   3. Aguarde 2-3 minutos"
echo "   4. Execute o workflow: 2️⃣ Activate Container App"
echo ""
echo "🎉 Deploy profissional pronto!"
echo ""
