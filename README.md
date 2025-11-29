# 🤖 AI Container Demo - Azure OpenAI com Container Apps

**Autores:**  
Andressa Siqueira - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)  
Vicente Maciel Jr - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)

---

## ⚠️ IMPORTANTE: Fez Fork ou Clone?

> **Os GitHub Actions não funcionarão automaticamente!**  
> GitHub Secrets (credenciais do Azure) **não são copiados** em forks/clones por segurança.

### 🚀 Solução Rápida: Use o Script Automático

```powershell
cd scripts
.\setup-forked-repo.ps1 `
  -ResourceGroup "rg-ai-demo-SEUNOME" `
  -Location "eastus" `
  -ACRName "acrdemo$(Get-Random -Maximum 9999)" `
  -ContainerAppName "ai-chat-app" `
  -AzureOpenAIName "openai-demo"
```

**O que ele faz:**
- ✅ Detecta automaticamente SEU repositório GitHub
- ✅ Detecta a branch atual  
- ✅ Cria Service Principal e OIDC corretos para VOCÊ
- ✅ Configura todos os 7 GitHub Secrets no SEU repo
- ✅ Valida permissões antes de começar

📖 **Veja instruções completas na seção [Deploy no Azure](#opção-2-deploy-completo-no-azure-produção)**

---

## 📝 Sobre o Projeto

Demonstração prática de como integrar **Azure OpenAI** com **Azure Container Apps** usando **autenticação por Managed Identity** e **CI/CD profissional via GitHub Actions**.

Este projeto ilustra:

- 🔐 **Autenticação segura** sem chaves de API hardcoded (Managed Identity)
- 🤖 **Integração com Azure OpenAI** usando SDK oficial
- 🚀 **Deploy automatizado** com GitHub Actions e OIDC
- 📦 **Containerização** com Docker e Azure Container Registry
- 🏗️ **Infrastructure as Code** com Bicep
- ⚡ **Aplicação web moderna** com FastAPI e interface HTML

---

## 🎯 Propósito da Demo

Esta demo serve como referência para implementar aplicações modernas de IA no Azure seguindo as melhores práticas de:

- ✅ Segurança (Managed Identity, OIDC, sem secrets hardcoded)
- ✅ DevOps (CI/CD automatizado, IaC)
- ✅ Arquitetura Cloud-Native (containers, serverless)
- ✅ Escalabilidade (scale-to-zero, auto-scaling)

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                      GitHub Actions                         │
│  ┌──────────────────┐      ┌──────────────────────────┐    │
│  │  1️⃣ Deploy Infra │ ───▶ │  2️⃣ Build & Deploy App  │    │
│  └──────────────────┘      └──────────────────────────┘    │
└────────────┬────────────────────────────┬───────────────────┘
             │ (OIDC Auth)                │ (Push Image)
             ▼                            ▼
┌────────────────────────┐   ┌──────────────────────────┐
│   Azure Resource       │   │   Azure Container        │
│   Group                │   │   Registry (ACR)         │
│                        │   └──────────────────────────┘
│  ┌──────────────────┐ │                │
│  │ Azure OpenAI     │ │                │ (Pull Image)
│  │ + GPT-4o-mini    │ │                ▼
│  └────────┬─────────┘ │   ┌──────────────────────────┐
│           │           │   │   Container App          │
│           │ (RBAC)    │   │                          │
│           │           │   │  ┌────────────────────┐  │
│           └───────────┼──▶│  │ FastAPI + OpenAI   │  │
│                       │   │  │ (Managed Identity) │  │
│  ┌──────────────────┐ │   │  └────────────────────┘  │
│  │ AI Hub/Project   │ │   └──────────────────────────┘
│  │ (AI Foundry)     │ │                │
│  └──────────────────┘ │                │
│                       │                ▼
│  ┌──────────────────┐ │      ┌──────────────────┐
│  │ Key Vault        │ │      │  Public HTTPS    │
│  │ Storage          │ │      │  Endpoint        │
│  │ App Insights     │ │      └──────────────────┘
│  └──────────────────┘ │
└────────────────────────┘
```

---

## ⚠️ IMPORTANTE: Fez Fork ou Clone?

> **Os GitHub Actions não funcionarão automaticamente!**  
> GitHub Secrets (credenciais do Azure) **não são copiados** em forks/clones por segurança.

**Você tem 2 opções:**

### 🚀 Opção 1: Script Automático (Recomendado)
```powershell
cd scripts
.\setup-forked-repo.ps1 `
  -ResourceGroup "rg-ai-demo-SEUNOME" `
  -Location "eastus" `
  -ACRName "acrdemo$(Get-Random -Maximum 9999)" `
  -ContainerAppName "ai-chat-app" `
  -AzureOpenAIName "openai-demo"
```
✅ Detecta automaticamente SEU repositório  
✅ Cria Service Principal e OIDC corretos  
✅ Configura todos os secrets automaticamente

### 📝 Opção 2: Configuração Manual
Veja instruções detalhadas na seção [Deploy no Azure](#opção-2-deploy-completo-no-azure-produção) abaixo.

---

## 📋 Pré-requisitos

### Para Desenvolvimento Local:

- **Python 3.11+** instalado
- **Docker Desktop** (opcional, para teste com containers)
- **Git** para clonar o repositório

### Para Deploy no Azure:

- **Azure CLI** instalado e autenticado (`az login`)
  - [Download Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- **PowerShell 7+** (recomendado para scripts)
  - [Download PowerShell](https://github.com/PowerShell/PowerShell/releases)
- **GitHub CLI** instalado e autenticado (`gh auth login`)
  - [Download GitHub CLI](https://cli.github.com/)
- **Subscription do Azure** com permissões para criar recursos
- **Conta no GitHub** com acesso ao repositório

---

## 🚀 Como Usar

### Opção 1: Teste Local (Desenvolvimento)

#### 1. Clone o repositório
```bash
git clone https://github.com/AndressaSiqueira/ai-container-demo.git
cd ai-container-demo
```

#### 2. Instale as dependências

```bash
cd container-app
pip install -r requirements.txt
```

#### 3. Configure variáveis de ambiente (opcional)

Para testes locais com Azure OpenAI, defina as variáveis:

```bash
# Windows PowerShell
$env:AZURE_OPENAI_ENDPOINT="https://seu-endpoint.openai.azure.com/openai/v1/"
$env:AZURE_OPENAI_DEPLOYMENT="gpt-4o-mini"

# Linux/macOS
export AZURE_OPENAI_ENDPOINT="https://seu-endpoint.openai.azure.com/openai/v1/"
export AZURE_OPENAI_DEPLOYMENT="gpt-4o-mini"
```

⚠️ **Nota:** Para testes locais, use `az login` para autenticação. A aplicação usará suas credenciais do Azure CLI.

#### 4. Execute a aplicação

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

#### 5. Acesse no navegador

Abra: http://localhost:8000

Você verá a interface de chat para interagir com o Azure OpenAI.

---

### Opção 2: Deploy Completo no Azure (Produção)

Este é o caminho recomendado para produção, usando CI/CD automatizado.

#### **1. Fork ou Clone o Repositório**

**Escolha UMA opção:**

<details>
<summary><b>🍴 Opção A - Fork (Recomendado para contribuir)</b></summary>

1. Clique em **"Fork"** no GitHub: https://github.com/AndressaSiqueira/ai-container-demo
2. Clone SEU fork:
```powershell
git clone https://github.com/SEU-USUARIO/ai-container-demo.git
cd ai-container-demo
```

✅ Vantagens: Pode contribuir de volta com Pull Requests  
⚠️ Requer: Configurar secrets no SEU repositório

</details>

<details>
<summary><b>📥 Opção B - Clone Direto (Apenas usar)</b></summary>

```powershell
git clone https://github.com/AndressaSiqueira/ai-container-demo.git
cd ai-container-demo
```

✅ Vantagens: Simples e rápido  
⚠️ Requer: Criar seu próprio repositório no GitHub e configurar secrets

</details>

---

#### **2: Configure a Infraestrutura Azure e GitHub Secrets**

> **🎯 Use o script correto baseado na sua situação:**

<details>
<summary><b>✅ SE VOCÊ FEZ FORK/CLONE → Use este (Detecta automaticamente)</b></summary>

```powershell
cd scripts

# ✨ Script INTELIGENTE - detecta automaticamente seu repositório!
.\setup-forked-repo.ps1 `
  -ResourceGroup "rg-ai-demo" `
  -Location "eastus" `
  -ACRName "acrdemo$(Get-Random -Maximum 9999)" `
  -ContainerAppName "ai-chat-app" `
  -AzureOpenAIName "openai-demo"
```

**O que ele faz automaticamente:**
- 🔍 Detecta seu repositório via `git remote`
- 🔍 Detecta a branch atual
- ✅ Valida suas permissões no GitHub e Azure
- 🔐 Cria Service Principal com OIDC para SEU repo
- 🔑 Configura todos os 7 GitHub Secrets necessários
- 💾 Cria Managed Identity para o Container App

**Pré-requisitos:**
- Azure CLI autenticado: `az login`
- GitHub CLI autenticado: `gh auth login`
- Permissão de Admin no repositório fork

</details>

<details>
<summary><b>📝 SE VOCÊ É O DONO ORIGINAL → Use este (Manual)</b></summary>

```powershell
cd scripts

.\build-and-deploy.ps1 `
  -ResourceGroup "rg-ai-demo" `
  -Location "eastus" `
  -ACRName "acrdemo$(Get-Random -Maximum 9999)" `
  -ContainerAppName "ai-chat-app" `
  -AzureOpenAIName "openai-demo" `
  -GitHubRepo "SEU-USUARIO/ai-container-demo"  # ⚠️ Especificar manualmente
```

</details>

<details>
<summary><b>🔧 Opção Avançada: Configuração Manual (Sem script)</b></summary>

Se preferir configurar manualmente sem scripts:

**1. Criar Service Principal:**
```powershell
az login
$appId = az ad app create --display-name "sp-github-ai-demo" --query appId -o tsv
az ad sp create --id $appId

# Obter IDs
$subscriptionId = az account show --query id -o tsv
$tenantId = az account show --query tenantId -o tsv

# Atribuir permissões
az role assignment create \
  --assignee $appId \
  --role Contributor \
  --scope "/subscriptions/$subscriptionId/resourceGroups/rg-ai-demo"
```

**2. Configurar OIDC:**
```powershell
az ad app federated-credential create \
  --id $appId \
  --parameters '{
    "name": "github-oidc-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:SEU-USUARIO/ai-container-demo:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

**3. Criar Secrets no GitHub:**

Vá para: `https://github.com/SEU-USUARIO/ai-container-demo/settings/secrets/actions`

Adicione:
- `AZURE_TENANT_ID` → Seu Tenant ID
- `AZURE_CLIENT_ID` → App ID do Service Principal
- `AZURE_SUBSCRIPTION_ID` → ID da Subscription
- `RESOURCE_GROUP` → `rg-ai-demo`
- `CONTAINER_APP_NAME` → `ai-chat-app`
- `ACR_NAME` → `acrdemoXXXX` (único)
- `OPENAI_NAME` → `openai-demo`

</details>

**O que este script faz:**

✅ Cria o Resource Group no Azure  
✅ Cria Service Principal com OIDC (autenticação GitHub → Azure)  
✅ Cria Managed Identity para o Container App  
✅ Atribui roles necessárias (Contributor, User Access Administrator)  
✅ Configura automaticamente os **GitHub Secrets** no seu repositório:
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `RESOURCE_GROUP`
   - `CONTAINER_APP_NAME`
   - `ACR_NAME`
   - `OPENAI_NAME`

**Tempo estimado:** 2-3 minutos

---

#### **3: Execute o Workflow de Deploy da Infraestrutura**

1. **Acesse GitHub Actions no SEU repositório:**
   ```
   https://github.com/SEU-USUARIO/ai-container-demo/actions
   ```

2. **Clique no workflow "1️⃣ Deploy Infrastructure"**

3. **Clique em "Run workflow"**
   - Branch: `main` (ou sua branch atual)
   - Clique em **"Run workflow"**

<details>
<summary>🔍 O que acontece neste workflow?</summary>

O workflow executa o template Bicep (`infrastructure/main.bicep`) que cria:

- ✅ **Azure Container Registry (ACR)** - Repositório de imagens Docker
- ✅ **Azure OpenAI** - Com modelo GPT-4o-mini deployado
- ✅ **AI Hub + AI Project** - Azure AI Foundry (ML workspace)
- ✅ **Container App Environment** - Ambiente serverless
- ✅ **Container App** - Sua aplicação (inicialmente com imagem placeholder)
- ✅ **Managed Identity** - Autenticação segura sem chaves
- ✅ **RBAC Roles** - Permissões para Container App → OpenAI
- ✅ **Key Vault** - Gerenciamento de secrets
- ✅ **Storage Account** - Armazenamento para AI Hub
- ✅ **Application Insights** - Monitoramento e logs

**Tempo estimado:** 8-12 minutos ⏱️

</details>

---

#### **4: Execute o Workflow de Build e Deploy da Aplicação**

⏱️ **Aguarde 2-3 minutos** após o Passo 3 para propagação das permissões RBAC no Azure.

1. **No GitHub Actions, clique no workflow "2️⃣ Build and Deploy Container App"**

2. **Clique em "Run workflow"**
   - Branch: `main` (ou sua branch atual)
   - Clique em **"Run workflow"**

<details>
<summary>🔍 O que acontece neste workflow?</summary>

O workflow constrói e deploya sua aplicação:

- ⏳ Aguarda 60s para propagação de roles Azure
- 🐳 Build da imagem Docker (`container-app/`)
- 📤 Push da imagem para o ACR
- 🔄 Atualiza Container App com a nova imagem
- ⚙️ Configura variáveis de ambiente:
  - `AZURE_OPENAI_ENDPOINT`
  - `AZURE_OPENAI_DEPLOYMENT`
  - `AZURE_CLIENT_ID` (Managed Identity)
- 📊 Configura recursos: 0.5 CPU, 1GB RAM
- 🚀 Ativa auto-scaling: min 0 → max 10 réplicas

**Tempo estimado:** 3-5 minutos ⏱️

</details>

---

#### **5: Acesse sua Aplicação! 🎉**

Após a conclusão do workflow, você verá no log do GitHub Actions:

```
🚀 Container App URL: https://ai-chat-app.REGION.azurecontainerapps.io
📊 Test endpoint: https://ai-chat-app.REGION.azurecontainerapps.io/responses
```

**Clique na URL** ou copie e cole no navegador para usar o chat! 🤖✨

---

## 📊 Endpoints da API

| Endpoint | Método | Descrição |
|----------|--------|-----------|
| `/` | GET | Interface web do chat |
| `/responses` | POST | Endpoint da API para enviar mensagens |
| `/docs` | GET | Documentação Swagger da API |
| `/redoc` | GET | Documentação ReDoc da API |

### Exemplo de uso da API:

```bash
# Usando curl
curl -X POST https://sua-app.azurecontainerapps.io/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"Explique o que é Azure Container Apps"}'

# Usando PowerShell
Invoke-RestMethod -Uri "http://localhost:8000/responses" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"ask":"O que é Inteligência Artificial?"}'
```

---

## 📁 Estrutura do Projeto

```
ai-container-demo/
├── .github/
│   └── workflows/
│       ├── deploy-infrastructure.yml    # 1️⃣ Deploy da infraestrutura
│       └── build-and-deploy-app.yml     # 2️⃣ Build e deploy da app
│
├── container-app/                       # 🐍 Aplicação FastAPI
│   ├── main.py                         # Código principal
│   ├── requirements.txt                # Dependências Python
│   ├── Dockerfile                      # Imagem Docker
│   └── static/
│       └── index.html                  # Interface web do chat
│
├── infrastructure/                      # 🏗️ Infraestrutura como Código
│   └── main.bicep                      # Template Bicep completo
│
├── scripts/                            # 🔧 Scripts de automação
│   ├── build-and-deploy.ps1           # Setup inicial (OIDC + Secrets)
│   ├── fix-oidc.ps1                   # Correção de OIDC
│   └── purge-deleted-resources.ps1    # Limpeza de recursos deletados
│
├── README.md                           # 📖 Este arquivo
└── TROUBLESHOOTING.md                 # 🔍 Guia de solução de problemas
```

---

## 🔐 Segurança

Esta demo implementa as melhores práticas de segurança:

- ✅ **Managed Identity** - Sem chaves de API no código
- ✅ **OIDC** - Autenticação GitHub Actions sem secrets de longa duração
- ✅ **RBAC** - Princípio do menor privilégio
- ✅ **HTTPS Only** - Todas as comunicações criptografadas
- ✅ **Key Vault** - Secrets gerenciados centralmente
- ✅ **Soft Delete** - Proteção contra exclusão acidental

---

## 💰 Custos Estimados

| Recurso | Tier | Custo Mensal Estimado* |
|---------|------|------------------------|
---

## 🐛 Problemas Comuns

<details>
<summary><b>❌ GitHub Actions falha com "OIDC token is not valid"</b></summary>

**Causa:** OIDC configurado para repositório/branch errado.

**Solução:**
```powershell
# Execute novamente o script na branch correta
git checkout main  # ou sua branch
cd scripts
.\setup-forked-repo.ps1 ...
```

O script recria o OIDC com as informações corretas.

</details>

<details>
<summary><b>❌ Erro: "You do not have permission to set secrets"</b></summary>

**Causa:** Você não tem permissão de admin no repositório.

**Soluções:**
1. Se for um fork, verifique se você é o dono do fork
2. Configure secrets manualmente em: `Settings → Secrets and variables → Actions`
3. Use a opção de configuração manual acima

</details>

<details>
<summary><b>❌ Container App não inicia / fica em "Provisioning"</b></summary>

**Possíveis causas:**
- Permissões RBAC ainda propagando (aguarde 5 minutos)
- Managed Identity sem acesso ao ACR
- Imagem Docker com erro

**Solução:**
```powershell
# Verificar logs do Container App
az containerapp logs show \
  --name ai-chat-app \
  --resource-group rg-ai-demo \
  --follow

# Verificar revisões
az containerapp revision list \
  --name ai-chat-app \
  --resource-group rg-ai-demo \
  -o table
```

</details>

<details>
<summary><b>❌ Erro 403 ao acessar Azure OpenAI</b></summary>

**Causa:** Managed Identity sem permissão "Cognitive Services OpenAI User".

**Solução:**
```powershell
# Obter IDs necessários
$identityId = az identity show \
  --name id-ai-chat-app \
  --resource-group rg-ai-demo \
  --query principalId -o tsv

$openaiId = az cognitiveservices account show \
  --name openai-demo \
  --resource-group rg-ai-demo \
  --query id -o tsv

# Atribuir role
az role assignment create \
  --assignee $identityId \
  --role "Cognitive Services OpenAI User" \
  --scope $openaiId
```

</details>

<details>
<summary><b>❌ Script pede GitHub CLI mas não quero instalar</b></summary>

**Solução:** Use a configuração manual (expandir seção acima no Passo 2) e configure os secrets diretamente no GitHub:

1. Vá para: `https://github.com/SEU-USUARIO/ai-container-demo/settings/secrets/actions`
2. Clique em "New repository secret"
3. Adicione cada secret manualmente

</details>

<details>
<summary><b>ℹ️ Como verificar se os secrets estão configurados?</b></summary>

```
https://github.com/SEU-USUARIO/ai-container-demo/settings/secrets/actions
```

Você deve ver 7 secrets:
- ✅ AZURE_TENANT_ID
- ✅ AZURE_CLIENT_ID
- ✅ AZURE_SUBSCRIPTION_ID
- ✅ RESOURCE_GROUP
- ✅ CONTAINER_APP_NAME
- ✅ ACR_NAME
- ✅ OPENAI_NAME

**Nota:** Você não consegue ver os valores (por segurança), mas pode ver os nomes.

</details>

---

## 📚 Recursos Adicionaisni) | Standard | ~$10-50 (pay-per-use) |
| Storage Account | Standard LRS | ~$1 |
| Key Vault | Standard | ~$1 |
| **Total** | | **~$22-77/mês** |

*Custos podem variar baseado no uso real e região.

---

## 📚 Recursos Adicionais

### Documentação Microsoft:

- [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/ai-services/openai/)
- [Managed Identity](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [GitHub Actions OIDC](https://docs.github.com/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Bicep Language](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

### Tecnologias Utilizadas:

- **FastAPI** - Framework web Python moderno
- **OpenAI SDK** - Cliente oficial Python
- **Docker** - Containerização
- **Bicep** - Infrastructure as Code
- **GitHub Actions** - CI/CD

---

## 🤝 Contribuindo

Sinta-se à vontade para abrir issues ou pull requests com melhorias!

---

## 📧 Contato

Para dúvidas ou feedback:

- **Andressa Siqueira** - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)
- **Vicente Maciel Jr** - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)

---

## 📄 Licença

Este projeto é uma demo educacional por Andressa Siqueira e Vicente Maciel.

---

**Desenvolvido com ❤️ por Andressa Siqueira e Vicente Maciel**




