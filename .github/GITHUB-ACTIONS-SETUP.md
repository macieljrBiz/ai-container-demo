# GitHub Actions Setup

## 🚀 Automated Build and Deploy

Este repositório usa GitHub Actions para automaticamente:
1. Build das imagens de container quando código é modificado
2. Push das imagens para Azure Container Registry (ACR)
3. Atualização automática dos apps em produção (se existirem)

---

## 📋 Configuração Inicial

### 1. Criar Service Principal no Azure

```bash
az ad sp create-for-rbac \
  --name "github-actions-ai-container-demo" \
  --role contributor \
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>/resourceGroups/rg-ai-container-demo \
  --sdk-auth
```

**Copie todo o JSON retornado!**

### 2. Adicionar Secret no GitHub

1. Vá para **Settings** → **Secrets and variables** → **Actions**
2. Clique em **New repository secret**
3. Nome: `AZURE_CREDENTIALS`
4. Value: Cole o JSON completo do passo anterior
5. Clique em **Add secret**

### 3. Criar o ACR (se ainda não existe)

```bash
az group create --name rg-ai-container-demo --location eastus

az acr create \
  --resource-group rg-ai-container-demo \
  --name acraicondemo \
  --sku Basic
```

### 4. Dar permissão ao Service Principal no ACR

```bash
# Pegar o ID do ACR
ACR_ID=$(az acr show --name acraicondemo --query id --output tsv)

# Pegar o ID do Service Principal
SP_ID=$(az ad sp list --display-name "github-actions-ai-container-demo" --query "[0].id" --output tsv)

# Atribuir role AcrPush
az role assignment create \
  --assignee $SP_ID \
  --role AcrPush \
  --scope $ACR_ID
```

---

## ✅ Workflow Funcionando

Agora, toda vez que você fizer push para `main` com mudanças em:
- `container-app/` → Build automático da imagem Container Apps
- `azure-functions/` → Build automático da imagem Functions

**Você também pode executar manualmente:**
- Vá para **Actions** → **Build and Push Container Images** → **Run workflow**

---

## 🎯 Fluxo de Trabalho

### Desenvolvimento Local
```bash
# Fazer mudanças no código
cd container-app
# Editar main.py, etc.

# Commit e push
git add .
git commit -m "feat: nova funcionalidade"
git push origin main
```

### GitHub Actions (Automático)
1. ✅ Detecta mudanças em `container-app/`
2. ✅ Faz build da imagem Docker
3. ✅ Push para `acraicondemo.azurecr.io/ai-container-app:latest`
4. ✅ Atualiza Container App (se já estiver deployado)

### Deployment com Bicep (Primeira vez)
```bash
# Depois que o GitHub Actions fez o build
az deployment group create \
  --resource-group rg-ai-container-demo \
  --template-file infrastructure/container-app.bicep \
  --parameters \
    acrName=acraicondemo \
    containerImage=acraicondemo.azurecr.io/ai-container-app:latest \
    azureOpenAIEndpoint="https://your-openai.cognitiveservices.azure.com/openai/v1/" \
    azureOpenAIDeployment="gpt-4"
```

---

## 🔍 Monitorar Builds

1. Vá para **Actions** no GitHub
2. Veja os workflows em execução
3. Clique em qualquer run para ver logs detalhados

---

## 🛠️ Customização

### Mudar nome do ACR

Edite `.github/workflows/build-images.yml`:
```yaml
env:
  REGISTRY_NAME: seu-acr-name  # Mude aqui
```

### Mudar resource group

Edite os comandos `az containerapp update` e `az functionapp config` no workflow.

---

## 📊 Status do Build

Adicione um badge no README:

```markdown
![Build Status](https://github.com/macieljrBiz/ai-container-demo/actions/workflows/build-images.yml/badge.svg)
```

---

## 🎉 Benefícios

✅ **Build automático** - Sem necessidade de executar `az acr build` manualmente  
✅ **Versionamento** - Cada build tem tag com commit SHA  
✅ **Tag latest** - Sempre aponta para versão mais recente  
✅ **Deploy automático** - Apps são atualizados automaticamente (se configurado)  
✅ **CI/CD completo** - Push → Build → Deploy em minutos  

---

## 🔐 Segurança

- ✅ Credenciais Azure armazenadas como GitHub Secrets (criptografadas)
- ✅ Service Principal com permissões mínimas necessárias
- ✅ Sem credenciais no código
- ✅ Logs de auditoria no GitHub Actions
