# 🔘 Guia dos Botões Deploy to Azure

## 📋 Visão Geral

Este repositório oferece **4 opções** de deploy via botões "Deploy to Azure":

---

## 🎯 Botões Disponíveis

### 1️⃣ Container App (Build + Deploy Completo)
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Fcontainer-app-complete.json)

**Template:** `container-app-complete.bicep`

**O que cria:**
- ✅ Azure Container Registry (ACR)
- ✅ Build automático da imagem (via Deployment Scripts)
- ✅ Log Analytics Workspace
- ✅ Container Apps Environment
- ✅ Container App rodando
- ✅ Managed Identity configurada
- ✅ Permissões ACR Pull

**Parâmetros obrigatórios:**
- `acrName` - Nome do ACR (único globalmente)
- `azureOpenAIEndpoint` - URL do Azure OpenAI

**Tempo:** ~15-20 minutos  
**Custo adicional:** ~$0.01 (Container Instance temporário para build)

---

### 2️⃣ Azure Functions (Build + Deploy Completo)
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Ffunctions-complete.json)

**Template:** `functions-complete.bicep`

**O que cria:**
- ✅ Azure Container Registry (ACR)
- ✅ Build automático da imagem (via Deployment Scripts)
- ✅ Storage Account
- ✅ Log Analytics + Application Insights
- ✅ App Service Plan (Consumption Linux)
- ✅ Function App rodando
- ✅ Managed Identity configurada
- ✅ Permissões ACR Pull

**Parâmetros obrigatórios:**
- `acrName` - Nome do ACR (único globalmente)
- `functionAppName` - Nome do Functions (único globalmente)

**Tempo:** ~15-20 minutos  
**Custo adicional:** ~$0.01 (Container Instance temporário para build)

---

### 3️⃣ Container App (Apenas Infraestrutura)
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Fcontainer-app.json)

**Template:** `container-app.bicep`

**O que cria:**
- ✅ Azure Container Registry (ACR)
- ✅ Log Analytics Workspace
- ✅ Container Apps Environment
- ✅ Container App (com imagem placeholder)

**Parâmetros obrigatórios:**
- `acrName` - Nome do ACR (único globalmente)
- `azureOpenAIEndpoint` - URL do Azure OpenAI

**⚠️ ATENÇÃO:** Este botão **NÃO faz build** da imagem!  
Você precisará fazer build manualmente depois:
```bash
az acr build --registry SEUACR --image ai-container-app:latest --file ./container-app/Dockerfile ./container-app
```

**Tempo:** ~5-10 minutos  
**Custo adicional:** Nenhum

---

### 4️⃣ Azure Functions (Apenas Infraestrutura)
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Fazure-functions.json)

**Template:** `azure-functions.bicep`

**O que cria:**
- ✅ Azure Container Registry (ACR)
- ✅ Storage Account
- ✅ Log Analytics + Application Insights
- ✅ App Service Plan (Consumption Linux)
- ✅ Function App (runtime Python)

**Parâmetros obrigatórios:**
- `acrName` - Nome do ACR (único globalmente)
- `functionAppName` - Nome do Functions (único globalmente)
- `storageAccountName` - Nome do Storage (único globalmente)

**⚠️ ATENÇÃO:** Este botão **NÃO faz build** da imagem!  
Você precisará fazer build e publish manualmente depois:
```bash
az acr build --registry SEUACR --image ai-functions:latest --file ./azure-functions/Dockerfile ./azure-functions
func azure functionapp publish SEUFUNCTIONAPP
```

**Tempo:** ~5-10 minutos  
**Custo adicional:** Nenhum

---

## 🎯 Qual Botão Usar?

### ✅ Use Botões 1 ou 2 (Build Completo) quando:
- Você quer **tudo pronto** (one-click deploy)
- Não tem Azure CLI instalado
- Quer automatizar 100% do processo
- Código está no **GitHub público**
- Produção ou demo para cliente

### ✅ Use Botões 3 ou 4 (Apenas Infraestrutura) quando:
- Já tem **imagens prontas** no ACR
- Quer **controle manual** do build
- Código está **privado** ou **local**
- Quer deploy **mais rápido** (sem build)
- Desenvolvimento e testes

---

## 📊 Comparação

| Aspecto | Build Completo (1 e 2) | Apenas Infra (3 e 4) |
|---------|------------------------|----------------------|
| **Faz build?** | ✅ Sim (automático) | ❌ Não (manual) |
| **Precisa GitHub?** | ✅ Sim (público) | ❌ Não |
| **Tempo** | ~15-20 min | ~5-10 min |
| **Custo adicional** | +$0.01 | Grátis |
| **Passos manuais** | 0 | 1-2 (build + publish) |
| **Ideal para** | Produção, Cliente | Desenvolvimento |

---

## 🔧 Nomes Únicos Necessários

### Azure Container Registry (ACR)
- ❌ NÃO pode: `acraicondemo`, `ansiqueira123`
- ✅ PODE: `acr[empresa][numero]`, `registry[projeto][ano]`
- Exemplo: `acrdemo2025`, `acrminhaapp123`
- Regras: 5-50 caracteres, apenas letras e números

### Function App
- ❌ NÃO pode: `funcappaidessa`, `minhafunction`
- ✅ PODE: `func-[empresa]-[projeto]`, `[app]-functions-[env]`
- Exemplo: `func-acme-chatbot`, `myapp-functions-prod`
- Regras: 2-60 caracteres, letras, números e hífens

### Storage Account
- ❌ NÃO pode: `staifunctions`, `storage_app`
- ✅ PODE: `st[empresa][app]`, `storage[projeto][ano]`
- Exemplo: `stacmechatbot`, `stmyapp2025`
- Regras: 3-24 caracteres, **APENAS** letras minúsculas e números

---

## 💡 Dicas

### 1. Verificar se nome está disponível
```bash
# ACR
az acr check-name --name seunomeacr

# Function App
az functionapp list --query "[?name=='seunomefunc'].name" -o table

# Storage
az storage account check-name --name seunomestorage
```

### 2. Gerar nomes únicos automaticamente
```bash
# Usando sufixo aleatório
SUFIXO=$(openssl rand -hex 3)
ACR_NAME="acrdemo${SUFIXO}"
FUNC_NAME="func-demo-${SUFIXO}"
ST_NAME="stdemo${SUFIXO}"

echo "ACR: $ACR_NAME"
echo "Functions: $FUNC_NAME"
echo "Storage: $ST_NAME"
```

### 3. Boas práticas de nomenclatura
```
ACR:       acr-[empresa]-[projeto]-[env]
Functions: func-[empresa]-[projeto]-[env]
Storage:   st[empresa][projeto][env]

Exemplos:
- acr-acme-chatbot-prod
- func-acme-chatbot-prod
- stacmechatbotprod
```

---

## 🚀 Fluxo Recomendado

### Para Cliente Final (Produção)
1. Clique no **Botão 1** (Container App Build Completo)
2. Preencha parâmetros no Portal Azure
3. Aguarde ~15-20 minutos
4. **PRONTO!** App rodando

### Para Desenvolvimento
1. Clique no **Botão 3** (Container App Apenas Infra)
2. Faça build manual quando necessário
3. Itere rapidamente com `az acr build`

---

## ❓ FAQ

**P: Posso usar o mesmo ACR para Container Apps e Functions?**  
R: ✅ Sim! Recomendado. Use o mesmo `acrName` em ambos templates.

**P: O que acontece se eu clicar no botão duas vezes?**  
R: O Azure verifica recursos existentes e **atualiza** (não duplica). É idempotente.

**P: Posso mudar o nome depois?**  
R: ⚠️ Alguns recursos (ACR, Storage) não permitem rename. Precisa recriar.

**P: E se o nome que eu quero já está em uso?**  
R: Adicione sufixo único: `acrdemo2025`, `acrdemo-eastus`, `acrdemo-v2`

**P: Preciso do Azure OpenAI para testar?**  
R: ⚠️ Sim para Container Apps. Para Functions, é opcional (depende do código).

---

**✨ Escolha o botão ideal para seu cenário e faça deploy em minutos!**
