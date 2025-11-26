# 🚀 Build e Deploy - Guia do Cliente

## 📋 Pré-requisitos

- Azure CLI instalado ([Download](https://aka.ms/azure-cli))
- Conta Azure ativa
- Subscription Azure com permissões de Contributor

---

## ⚡ Opção 1: Azure Cloud Shell (RECOMENDADO para clientes)

**Vantagens:**
- ✅ Não precisa instalar nada
- ✅ Já vem com Azure CLI configurado
- ✅ PowerShell ou Bash disponível
- ✅ Funciona de qualquer lugar (browser)

### Passo a Passo:

#### 1. Abrir Azure Cloud Shell
1. Acesse [portal.azure.com](https://portal.azure.com)
2. Clique no ícone **Cloud Shell** (>_) no topo da página
3. Escolha **PowerShell** quando solicitado

#### 2. Fazer Upload do Código
```powershell
# No Cloud Shell, fazer upload da pasta do projeto
# Clique em "Upload/Download files" (ícone de pasta) → Upload
# Ou use o botão de upload no menu

# Depois de fazer upload, descompacte se necessário
cd ~
# Se enviou um ZIP:
unzip ai-container-demo.zip
cd ai-container-demo-restructured
```

#### 3. Executar o Script de Deploy
```powershell
# Deploy completo (cria tudo + faz build das imagens)
./scripts/build-and-deploy.ps1

# OU com parâmetros customizados:
./scripts/build-and-deploy.ps1 `
    -ResourceGroup "meu-rg" `
    -Location "eastus" `
    -ACRName "meuacr123" `
    -AzureOpenAIEndpoint "https://seu-openai.openai.azure.com/"
```

#### 4. Aguardar Conclusão
O script vai:
- ✅ Criar Resource Group
- ✅ Criar Azure Container Registry
- ✅ **Fazer build das imagens na nuvem** (não precisa Docker local)
- ✅ Deploy Container App com Bicep
- ✅ Deploy Azure Functions com Bicep
- ✅ Configurar Managed Identity
- ✅ Configurar permissões ACR e OpenAI
- ✅ Mostrar URLs dos apps no final

---

## 💻 Opção 2: PowerShell Local

Se preferir executar do seu computador:

### 1. Instalar Azure CLI
```powershell
# Windows (winget)
winget install Microsoft.AzureCLI

# Ou baixar do site:
# https://aka.ms/azure-cli
```

### 2. Fazer Login no Azure
```powershell
az login

# Selecionar subscription (se tiver múltiplas)
az account set --subscription "Nome ou ID da subscription"
```

### 3. Navegar até a pasta do projeto
```powershell
cd "C:\caminho\para\ai-container-demo-restructured"
```

### 4. Executar o script
```powershell
.\scripts\build-and-deploy.ps1
```

---

## 🎯 O que o Script Faz

### Builds (no ACR - não precisa Docker local)
```
1. Container App
   └─ Imagem: acraicondemo.azurecr.io/ai-container-app:latest
   └─ Build na nuvem com az acr build

2. Azure Functions  
   └─ Imagem: acraicondemo.azurecr.io/ai-functions:latest
   └─ Build na nuvem com az acr build
```

### Deploy
```
1. Resource Group (rg-ai-container-demo)
2. Azure Container Registry (acraicondemo)
3. Container Apps Environment + Log Analytics
4. Container App (ai-container-app)
   └─ Com Managed Identity
   └─ Com ACR Pull permission
   └─ Com Azure OpenAI permission
5. Azure Functions (funcappaidessa)
   └─ Com Application Insights
```

---

## 📊 Verificar Deploy

### Ver imagens no ACR
```powershell
# Listar repositórios
az acr repository list --name acraicondemo --output table

# Ver tags de uma imagem
az acr repository show-tags --name acraicondemo --repository ai-container-app --output table
```

### Ver Container App
```powershell
# Info do Container App
az containerapp show --name ai-container-app --resource-group rg-ai-container-demo

# Ver URL
az containerapp show `
    --name ai-container-app `
    --resource-group rg-ai-container-demo `
    --query properties.configuration.ingress.fqdn -o tsv
```

### Ver Logs
```powershell
# Logs do Container App
az containerapp logs show `
    --name ai-container-app `
    --resource-group rg-ai-container-demo `
    --follow

# Logs do Functions
az functionapp log tail `
    --name funcappaidessa `
    --resource-group rg-ai-container-demo
```

---

## 🔄 Atualizar Código (Rebuild)

Quando mudar o código, só precisa:

```powershell
# 1. Navegar até a pasta
cd ai-container-demo-restructured

# 2. Rebuild da imagem Container App
az acr build `
    --registry acraicondemo `
    --image "ai-container-app:latest" `
    --file ./container-app/Dockerfile `
    ./container-app

# 3. Atualizar Container App com nova imagem
az containerapp update `
    --name ai-container-app `
    --resource-group rg-ai-container-demo `
    --image acraicondemo.azurecr.io/ai-container-app:latest

# Para Functions (similar):
az acr build `
    --registry acraicondemo `
    --image "ai-functions:latest" `
    --file ./azure-functions/Dockerfile `
    ./azure-functions

az functionapp config container set `
    --name funcappaidessa `
    --resource-group rg-ai-container-demo `
    --docker-custom-image-name acraicondemo.azurecr.io/ai-functions:latest `
    --docker-registry-server-url https://acraicondemo.azurecr.io
```

---

## 🛠️ Troubleshooting

### Script não encontrado
```powershell
# Dar permissão de execução (se necessário)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Erro de autenticação ACR
```powershell
# Relogar no ACR
az acr login --name acraicondemo
```

### Erro de permissão
```powershell
# Verificar role na subscription
az role assignment list --assignee $(az account show --query user.name -o tsv)

# Precisa ter pelo menos "Contributor" no Resource Group
```

### Imagem não atualiza
```powershell
# Forçar restart do Container App
az containerapp revision restart `
    --name ai-container-app `
    --resource-group rg-ai-container-demo
```

---

## 📦 Entrega para Cliente

### Arquivos Necessários:
```
ai-container-demo-restructured/
├── scripts/
│   └── build-and-deploy.ps1         ← Script principal
├── infrastructure/
│   ├── container-app.bicep          ← Template Container App
│   └── azure-functions.bicep        ← Template Functions
├── container-app/
│   ├── Dockerfile
│   ├── main.py
│   └── requirements.txt
└── azure-functions/
    ├── Dockerfile
    ├── function_app.py
    └── requirements.txt
```

### Instruções para o Cliente:
1. **Abrir Azure Cloud Shell** (portal.azure.com → ícone >_)
2. **Fazer upload** da pasta `ai-container-demo-restructured`
3. **Executar**: `./scripts/build-and-deploy.ps1`
4. **Aguardar** ~5-10 minutos
5. **Acessar** a URL mostrada no final

---

## ✨ Benefícios desta Abordagem

✅ **Sem GitHub** - Cliente não precisa ter conta GitHub  
✅ **Sem Docker local** - Build acontece no ACR (nuvem)  
✅ **Um único comando** - `build-and-deploy.ps1` faz tudo  
✅ **Cloud Shell** - Roda de qualquer lugar, só precisa browser  
✅ **Reproduzível** - Sempre gera o mesmo resultado  
✅ **Versionado** - Imagens têm timestamp automático  
✅ **Seguro** - Managed Identity, sem senhas hardcoded  

---

## 🎉 Resultado Final

Após executar `build-and-deploy.ps1`, o cliente terá:

- ✅ Azure Container Registry com imagens buildadas
- ✅ Container App rodando a aplicação
- ✅ Azure Functions deployado
- ✅ Managed Identity configurada
- ✅ Permissões ACR e OpenAI configuradas
- ✅ URLs prontas para acesso

**Tudo em ~5-10 minutos! 🚀**
