# GitHub Actions - Setup Guide

## 📋 Visão Geral

Este guia configura deploy automático via GitHub Actions com autenticação OIDC (sem senhas).

**Fluxo completo:**
1. Criar Service Principal (manual, uma vez)
2. GitHub Actions cria Managed Identity + Roles
3. GitHub Actions deleta Service Principal
4. Deploy automático via workflows

---

## 🚀 Setup Rápido (15 minutos)

### **Passo 1: Criar Service Principal**

Execute no Azure CLI (uma vez apenas):

```bash
# Obter Subscription ID
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

# Criar Service Principal com role Owner
az ad sp create-for-rbac \
  --name "sp-github-oidc-setup" \
  --role "Owner" \
  --scopes "/subscriptions/$SUBSCRIPTION_ID" \
  --sdk-auth
```

**Copie o output JSON** (você usará no próximo passo).

---

### **Passo 2: Configurar Secret no GitHub**

1. Vá para: `https://github.com/AndressaSiqueira/Webapp/settings/secrets/actions`

2. Clique em **New repository secret**

3. Configure:
   - **Name:** `AZURE_SETUP_CREDENTIALS`
   - **Value:** Cole o JSON completo do Passo 1

4. Clique em **Add secret**

---

### **Passo 3: Executar Setup OIDC**

1. Vá para: `https://github.com/AndressaSiqueira/Webapp/actions`

2. Selecione workflow: **0️⃣ Setup OIDC**

3. Clique em **Run workflow**

4. Preencha os campos (ou use padrões):
   - GitHub Organization: `AndressaSiqueira`
   - GitHub Repository: `Webapp`
   - Branch: `master`
   - Resource Group: `rg-github-actions-oidc`
   - Location: `brazilsouth`
   - Identity Name: `id-github-actions-deploy`

5. Clique em **Run workflow**

6. **Aguarde 1-2 minutos** até completar

7. **Copie os 3 valores** exibidos no log (última etapa)

---

### **Passo 4: Configurar Secrets OIDC**

Vá para: `https://github.com/AndressaSiqueira/Webapp/settings/secrets/actions`

Configure os 3 secrets:

| Secret Name | Value |
|-------------|-------|
| `AZURE_CLIENT_ID` | Valor do log do Passo 3 |
| `AZURE_TENANT_ID` | Valor do log do Passo 3 |
| `AZURE_SUBSCRIPTION_ID` | Valor do log do Passo 3 |

---

### **Passo 5: Cleanup Service Principal**

1. Vá para: `https://github.com/AndressaSiqueira/Webapp/actions`

2. Selecione workflow: **3️⃣ Cleanup Service Principal**

3. Clique em **Run workflow**

4. Preencha:
   - **Service Principal Name:** `sp-github-oidc-setup`
   - **Confirm Deletion:** `DELETE` (exatamente assim)

5. Clique em **Run workflow**

6. **Delete o secret** `AZURE_SETUP_CREDENTIALS`:
   - Vá para: `https://github.com/AndressaSiqueira/Webapp/settings/secrets/actions`
   - Encontre `AZURE_SETUP_CREDENTIALS`
   - Clique em **Remove**

---

### **Passo 6: Deploy!**

Agora você pode fazer deploy:

#### **Deploy Infrastructure**

1. GitHub Actions → **1️⃣ Deploy Infrastructure** → Run workflow

2. Preencha os parâmetros:
   - **Resource Group:** `rg-ai-demo`
   - **Container App Name:** `app-ai-demo`
   - **ACR Name:** `myacr123` (único globalmente)
   - **Azure OpenAI Endpoint:** `https://seu-modelo.openai.azure.com/`
   - **Azure OpenAI Deployment:** `gpt-4o`
   - **OpenAI Resource ID:** `/subscriptions/.../providers/Microsoft.CognitiveServices/accounts/...`

3. Aguarde 2-3 minutos

#### **Activate Container App**

1. GitHub Actions → **2️⃣ Activate Container App** → Run workflow

2. Preencha:
   - **Resource Group:** `rg-ai-demo` (mesmo do passo anterior)
   - **Container App Name:** `app-ai-demo` (mesmo do passo anterior)
   - **Wait Time:** `120` (segundos)

3. Aguarde 1-2 minutos

**🎉 Pronto! Container App online!**

---

## 📊 Fluxo Visual

```
┌────────────────────────────────────────────────────────────┐
│ SETUP ÚNICO (uma vez)                                      │
├────────────────────────────────────────────────────────────┤
│ 1. az ad sp create-for-rbac (Azure CLI)                   │
│ 2. Configurar AZURE_SETUP_CREDENTIALS (GitHub)            │
│ 3. Executar: 0️⃣ Setup OIDC (GitHub Actions)              │
│ 4. Configurar 3 secrets OIDC (GitHub)                     │
│ 5. Executar: 3️⃣ Cleanup Service Principal (GitHub)       │
│ 6. Deletar AZURE_SETUP_CREDENTIALS (GitHub)               │
└────────────────────────────────────────────────────────────┘
                          ↓
┌────────────────────────────────────────────────────────────┐
│ DEPLOY (toda vez que quiser)                              │
├────────────────────────────────────────────────────────────┤
│ 1. Executar: 1️⃣ Deploy Infrastructure (2 min)            │
│ 2. Aguardar 2-3 minutos (role propagation)                │
│ 3. Executar: 2️⃣ Activate Container App (1 min)           │
└────────────────────────────────────────────────────────────┘
                          ↓
                   🎉 APP ONLINE!
```

---

## 🔍 O que cada workflow faz?

### **0️⃣ Setup OIDC** (uma vez)
- Cria User-Assigned Managed Identity
- Atribui roles: Contributor + User Access Administrator
- Cria Federated Credential (trust GitHub → Azure)
- Exibe CLIENT_ID, TENANT_ID, SUBSCRIPTION_ID

### **3️⃣ Cleanup Service Principal** (uma vez)
- Deleta Service Principal temporário
- Remove credenciais desnecessárias
- Garante segurança enterprise

### **1️⃣ Deploy Infrastructure** (sempre)
- Cria Resource Group
- Deploy Bicep template:
  - Azure Container Registry (ACR)
  - Log Analytics + Container Apps Environment
  - Container App (minReplicas: 0 - inativo)
  - Managed Identity (para o app)
  - Role Assignments (AcrPull + OpenAI User)

### **2️⃣ Activate Container App** (sempre)
- Aguarda role propagation
- Ativa Container App (minReplicas: 1)
- Exibe URL do app

---

## ❓ Troubleshooting

### Erro: "insufficient privileges"
**Causa:** Service Principal não tem role Owner  
**Solução:** Recrie com `--role "Owner"`

### Erro: "The client does not have authorization"
**Causa:** Secret `AZURE_SETUP_CREDENTIALS` não configurado  
**Solução:** Configure o secret conforme Passo 2

### Container App não inicia
**Causa:** Ativou antes de 2-3 minutos  
**Solução:** Aguarde mais e re-execute workflow 2️⃣

### Erro ao chamar OpenAI API
**Causa:** OpenAI Resource ID incorreto  
**Solução:** Obtenha o Resource ID correto:
```bash
az cognitiveservices account show \
  --name <OPENAI-NAME> \
  --resource-group <OPENAI-RG> \
  --query id -o tsv
```

---

## 🛡️ Segurança

- ✅ **OIDC:** Sem senhas permanentes
- ✅ **Managed Identity:** Azure gerencia rotação de credenciais
- ✅ **Cleanup automático:** Service Principal é deletado após uso
- ✅ **Least privilege:** Roles específicas para cada recurso
- ✅ **Auditoria:** Todos os logs no GitHub Actions

---

## 📚 Recursos

- [Azure OIDC com GitHub Actions](https://learn.microsoft.com/azure/developer/github/connect-from-azure)
- [Managed Identities](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)
- [Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/)
