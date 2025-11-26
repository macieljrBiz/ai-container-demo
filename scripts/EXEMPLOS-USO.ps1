# ============================================================================
# EXEMPLO DE USO - Cliente Final
# ============================================================================
# Este arquivo mostra exatamente o que o cliente precisa fazer
# ============================================================================

# ============================================================================
# CENÁRIO 1: Azure Cloud Shell (MAIS FÁCIL - RECOMENDADO)
# ============================================================================

<#
1. Acesse https://portal.azure.com
2. Clique no ícone Cloud Shell (>_) no topo
3. Escolha "PowerShell"
4. Faça upload dos arquivos (botão Upload/Download)
5. Execute os comandos abaixo:
#>

# Navegar até a pasta
cd ai-container-demo-restructured

# Executar deploy completo
./scripts/build-and-deploy.ps1

# Pronto! Aguarde ~5-10 minutos
# No final, você verá as URLs dos apps deployados


# ============================================================================
# CENÁRIO 2: PowerShell Local (Windows)
# ============================================================================

<#
Pré-requisito: Azure CLI instalado
Download: https://aka.ms/azure-cli
#>

# 1. Fazer login no Azure
az login

# 2. (Opcional) Selecionar subscription
az account list --output table
az account set --subscription "Nome da Subscription"

# 3. Navegar até a pasta do projeto
cd "C:\Users\SeuNome\Downloads\ai-container-demo-restructured"

# 4. Executar deploy
.\scripts\build-and-deploy.ps1

# Pronto! Aguarde ~5-10 minutos


# ============================================================================
# CENÁRIO 3: Customizar Parâmetros
# ============================================================================

# Deploy com nomes customizados
./scripts/build-and-deploy.ps1 `
    -ResourceGroup "prod-ai-apps" `
    -Location "eastus2" `
    -ACRName "meuregistro123" `
    -ContainerAppName "meu-container-app" `
    -FunctionAppName "minhas-funcoes"

# Deploy especificando Azure OpenAI
./scripts/build-and-deploy.ps1 `
    -AzureOpenAIEndpoint "https://meu-openai-resource.openai.azure.com/" `
    -AzureOpenAIDeployment "gpt-4-turbo"


# ============================================================================
# CENÁRIO 4: Atualizar Código Depois do Deploy Inicial
# ============================================================================

# Depois de fazer mudanças no código:

# 1. Rebuild da imagem Container App
az acr build `
    --registry acraicondemo `
    --image "ai-container-app:latest" `
    --file ./container-app/Dockerfile `
    ./container-app

# 2. Atualizar Container App
az containerapp update `
    --name ai-container-app `
    --resource-group rg-ai-container-demo `
    --image acraicondemo.azurecr.io/ai-container-app:latest


# ============================================================================
# COMANDOS ÚTEIS PÓS-DEPLOY
# ============================================================================

# Ver URL do Container App
az containerapp show `
    --name ai-container-app `
    --resource-group rg-ai-container-demo `
    --query properties.configuration.ingress.fqdn -o tsv

# Ver logs em tempo real
az containerapp logs show `
    --name ai-container-app `
    --resource-group rg-ai-container-demo `
    --follow

# Listar imagens no ACR
az acr repository list --name acraicondemo --output table

# Ver tags de uma imagem
az acr repository show-tags `
    --name acraicondemo `
    --repository ai-container-app `
    --output table

# Verificar status do Container App
az containerapp show `
    --name ai-container-app `
    --resource-group rg-ai-container-demo `
    --query properties.runningStatus -o tsv

# Escalar Container App
az containerapp update `
    --name ai-container-app `
    --resource-group rg-ai-container-demo `
    --min-replicas 1 `
    --max-replicas 5


# ============================================================================
# TROUBLESHOOTING
# ============================================================================

# Erro: "script cannot be loaded because running scripts is disabled"
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Erro: "The subscription is not registered to use namespace..."
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.OperationalInsights

# Verificar status de providers
az provider list --query "[?namespace=='Microsoft.App']" -o table

# Relogar no ACR (se der erro de autenticação)
az acr login --name acraicondemo

# Ver permissões da sua conta
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Forçar restart do Container App
az containerapp restart `
    --name ai-container-app `
    --resource-group rg-ai-container-demo


# ============================================================================
# DELETAR TUDO (para limpar recursos)
# ============================================================================

# CUIDADO! Isso deleta todo o resource group e todos os recursos dentro dele
az group delete --name rg-ai-container-demo --yes --no-wait
