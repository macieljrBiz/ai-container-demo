# 🤖 AI Container Demo - Azure OpenAI com Container Apps

**Autores:**  
Andressa Siqueira - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)  
Vicente Maciel Jr - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)

---

## 📝 Sobre o Projeto

Demonstração de como integrar **Azure OpenAI** com **Azure Container Apps** usando **Managed Identity** e **CI/CD com GitHub Actions**.

**O que você vai aprender:**
- 🔐 Autenticação segura sem chaves de API (Managed Identity)
- 🤖 Integração com Azure OpenAI usando SDK oficial
- 🚀 Deploy automatizado com GitHub Actions e OIDC
- 📦 Containerização com Docker
- 🏗️ Infrastructure as Code com Bicep

---

## 🏗️ Arquitetura

```
GitHub Actions (OIDC)
    ↓
Azure Resource Group
├── Container Registry (ACR)
├── Azure OpenAI (GPT-4o-mini)
├── Container App
│   └── FastAPI App (Managed Identity)
├── AI Hub/Project
├── Key Vault
└── Storage + App Insights
```

---

## 📁 Estrutura do Projeto

```
ai-container-demo/
├── container-app/           # Aplicação Python
│   ├── main.py             # FastAPI + Azure OpenAI
│   ├── requirements.txt
│   ├── Dockerfile
│   └── static/index.html   # Interface web
│
├── infrastructure/
│   └── main.bicep          # Template de infraestrutura
│
├── .github/workflows/
│   ├── deploy-infrastructure.yml
│   └── build-and-deploy-app.yml
│
└── scripts/
    ├── setup-forked-repo.ps1      # Setup automático
    └── build-and-deploy.ps1
```

---

## 🚀 Como Usar

### Opção 1: Desenvolvimento Local

**1. Clone o repositório**
```bash
git clone https://github.com/macieljrBiz/ai-container-demo.git
cd ai-container-demo/container-app
```

**2. Instale as dependências**
```bash
pip install -r requirements.txt
```

**3. Configure as variáveis (opcional)**
```powershell
# Se quiser testar com Azure OpenAI real
$env:AZURE_OPENAI_ENDPOINT="https://seu-endpoint.openai.azure.com/openai/v1/"
$env:AZURE_OPENAI_DEPLOYMENT="gpt-4o-mini"
# Use: az login (a app usa suas credenciais do Azure CLI)
```

**4. Execute**
```bash
uvicorn main:app --reload --port 8000
```

**5. Acesse:** http://localhost:8000

---

### Opção 2: Deploy no Azure (Produção)

#### Pré-requisito: Fork ou Clone

> ⚠️ **IMPORTANTE:** GitHub Secrets não são copiados em forks!

**Escolha uma opção:**

- **Fork:** Clique em "Fork" no GitHub → cria cópia na sua conta
- **Clone:** Apenas baixa o código (você precisará criar um repo novo)

```bash
# Se fez fork:
git clone https://github.com/SEU-USUARIO/ai-container-demo.git
cd ai-container-demo

# Se clonou direto, crie um repo novo no GitHub e:
git remote set-url origin https://github.com/SEU-USUARIO/seu-repo.git
```

---

#### Passo 1: Configurar Secrets do GitHub

**Pré-requisitos:**
- Azure CLI: `az login`
- GitHub CLI: `gh auth login`
- PowerShell 7+

**Execute o script automático:**

```powershell
cd scripts

.\setup-forked-repo.ps1 `
  -ResourceGroup "rg-ai-demo" `
  -Location "eastus" `
  -ACRName "acrdemo$(Get-Random -Maximum 9999)" `
  -ContainerAppName "ai-chat-app" `
  -AzureOpenAIName "openai-demo"
```

**O script faz:**
1. Detecta seu repositório automaticamente
2. Cria Service Principal com OIDC
3. Cria Managed Identity
4. Configura 7 secrets no GitHub:
   - AZURE_TENANT_ID
   - AZURE_CLIENT_ID
   - AZURE_SUBSCRIPTION_ID
   - RESOURCE_GROUP
   - CONTAINER_APP_NAME
   - ACR_NAME
   - OPENAI_NAME

⏱️ Tempo: ~2 minutos

---

#### Passo 2: Deploy da Infraestrutura

1. Acesse: `https://github.com/SEU-USUARIO/ai-container-demo/actions`
2. Clique em **"1️⃣ Deploy Infrastructure"**
3. Clique em **"Run workflow"** → **"Run workflow"**

**O que é criado:**
- Azure Container Registry
- Azure OpenAI (GPT-4o-mini)
- Container App Environment
- Container App (placeholder)
- Managed Identity com permissões
- Key Vault, Storage, App Insights

⏱️ Tempo: ~10 minutos

---

#### Passo 3: Deploy da Aplicação

⏱️ Aguarde 2 minutos após o Passo 2

1. No GitHub Actions, clique em **"2️⃣ Build and Deploy Container App"**
2. Clique em **"Run workflow"** → **"Run workflow"**

**O que acontece:**
- Build da imagem Docker
- Push para ACR
- Deploy no Container App
- Configuração das variáveis de ambiente

⏱️ Tempo: ~4 minutos

---

#### Passo 4: Acesse sua App

No log do workflow, você verá:

```
🚀 Container App URL: https://ai-chat-app.REGION.azurecontainerapps.io
```

Acesse a URL e use o chat! 🎉

---

## 📊 Endpoints da API

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/` | GET | Interface web |
| `/responses` | POST | API do chat |
| `/docs` | GET | Swagger |

**Exemplo:**
```bash
curl -X POST https://sua-app.azurecontainerapps.io/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"O que é Azure Container Apps?"}'
```

---

## 🐛 Problemas Comuns

**❌ GitHub Actions falha: "OIDC token is not valid"**
- Execute o script `setup-forked-repo.ps1` novamente

**❌ Container App não inicia**
- Aguarde 5 minutos (propagação de permissões)
- Verifique logs: `az containerapp logs show --name ai-chat-app -g rg-ai-demo --follow`

**❌ Erro 403 ao chamar OpenAI**
- Verifique se Managed Identity tem role "Cognitive Services OpenAI User"

---

## 💰 Custos Estimados

| Recurso | Custo/mês |
|---------|-----------|
| Container Apps (consumption) | ~$5-20 |
| Azure OpenAI (GPT-4o-mini) | ~$10-50 |
| Container Registry | ~$5 |
| Storage + Key Vault | ~$2 |
| **Total** | **~$22-77** |

---

## 🔐 Segurança

- ✅ Managed Identity (sem chaves no código)
- ✅ OIDC (autenticação GitHub → Azure)
- ✅ RBAC (menor privilégio)
- ✅ HTTPS only
- ✅ Key Vault para secrets

---

## 📚 Recursos

- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)
- [Azure OpenAI](https://learn.microsoft.com/azure/ai-services/openai/)
- [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [GitHub OIDC](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

---

**Desenvolvido com ❤️ por Andressa Siqueira e Vicente Maciel**