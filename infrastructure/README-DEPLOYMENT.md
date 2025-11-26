# ⚠️ IMPORTANTE: Build da Imagem ANTES do Deployment

## 🚨 Pré-requisito Obrigatório

**VOCÊ DEVE FAZER O BUILD DA IMAGEM NO ACR ANTES DE CLICAR NO BOTÃO "Deploy to Azure"!**

O template ARM não faz o build da imagem automaticamente. Ele espera que a imagem `ai-container-app:latest` já exista no Azure Container Registry.

---

## ✅ Passos Corretos para Deployment

### 1️⃣ Criar ACR e Fazer Build da Imagem

```bash
# 1. Criar resource group
az group create --name rg-ai-container-demo --location eastus

# 2. Criar ACR
az acr create \
  --resource-group rg-ai-container-demo \
  --name acraicondemo \
  --sku Basic \
  --admin-enabled true

# 3. Build e push da imagem (OBRIGATÓRIO!)
git clone https://github.com/macieljrBiz/ai-container-demo.git
cd ai-container-demo/container-app

az acr build \
  --registry acraicondemo \
  --image ai-container-app:latest \
  --file Dockerfile \
  .
```

### 2️⃣ Agora Sim, Clicar no Botão Deploy to Azure

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Fcontainer-app.json)

**Parâmetros para preencher:**
- `Acr Name`: `acraicondemo` (mesmo nome usado no build)
- `Container App Name`: `ai-container-app`
- `Azure Open AI Endpoint`: Seu endpoint do Azure OpenAI
- `Azure Open AI Deployment`: Nome do seu deployment (ex: `gpt-4`)

### 3️⃣ Configurar Managed Identity (Após Deployment)

```bash
# Pegar o Principal ID do Container App
PRINCIPAL_ID=$(az containerapp show \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --query identity.principalId -o tsv)

# Atribuir role de acesso ao Azure OpenAI
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/<sua-subscription>/resourceGroups/<seu-rg-openai>/providers/Microsoft.CognitiveServices/accounts/<nome-openai>
```

---

## 🎯 Alternativa: Usar o Script Automatizado

Se preferir, use o script que faz TUDO automaticamente:

```bash
cd infrastructure
chmod +x deploy-container-app.sh

# Editar variáveis no script (opcional)
./deploy-container-app.sh
```

---

## ❌ O Que Acontece se Não Fizer o Build Antes

Você verá este erro:

```
ContainerAppOperationError: Failed to provision revision for container app 'ai-container-app'. 
Error details: The following field(s) are either invalid or missing. 
Field 'template.containers.ai-container-app.image' is invalid with details: 
'Invalid value: "acraicondemo.azurecr.io/ai-container-app:latest": 
GET https:: MANIFEST_UNKNOWN: manifest tagged by "latest" is not found'
```

**Solução:** Fazer o build da imagem conforme passo 1️⃣ acima.

---

## 📋 Resumo

1. ✅ **PRIMEIRO**: Criar ACR e fazer `az acr build`
2. ✅ **DEPOIS**: Clicar no botão "Deploy to Azure"
3. ✅ **POR ÚLTIMO**: Configurar Managed Identity

Ou simplesmente use `./deploy-container-app.sh` que faz tudo! 🚀
