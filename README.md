# 🤖 AI Container Demo - Azure OpenAI com Container Apps

**Autores:**  
Andressa Siqueira - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)  
Vicente Maciel Jr - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)

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

#### 2. Configure variáveis de ambiente

Crie um arquivo `.env` na pasta `container-app`:

```bash
# Local testing (sem Managed Identity)
AZURE_OPENAI_ENDPOINT=https://seu-endpoint.openai.azure.com/openai/v1/
AZURE_OPENAI_DEPLOYMENT=gpt-4o-mini
AZURE_OPENAI_API_KEY=sua-chave-temporaria-para-testes
```

⚠️ **Nota:** Para testes locais, você precisará usar uma API Key temporária. Em produção, use apenas Managed Identity.

#### 3. Instale as dependências

```bash
cd container-app
pip install -r requirements.txt
```

#### 4. Execute a aplicação

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

#### 5. Acesse no navegador

Abra: http://localhost:8000

Você verá a interface de chat para interagir com o Azure OpenAI.

#### 6. Teste a API (opcional)

```bash
# Usando curl
curl -X POST http://localhost:8000/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"O que é Inteligência Artificial?"}'

# Usando PowerShell
Invoke-RestMethod -Uri "http://localhost:8000/responses" `
  -Method POST `
  -ContentType "application/json" `
  -Body '{"ask":"O que é Inteligência Artificial?"}'
```

---

### Opção 2: Deploy Completo no Azure (Produção)

Este é o caminho recomendado para produção, usando CI/CD automatizado.

#### **Passo 1: Configure a Infraestrutura Azure e GitHub Secrets**

Execute o script de setup **uma única vez**:

```powershell
# Abra PowerShell 7+ como Administrador
cd ai-container-demo/scripts

# Execute o script de configuração
.\build-and-deploy.ps1 `
  -ResourceGroup "rg-ai-demo" `
  -Location "eastus" `
  -ACRName "acrdemo$(Get-Random -Maximum 9999)" `
  -ContainerAppName "ai-chat-app" `
  -AzureOpenAIName "openai-demo"
```

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

#### **Passo 2: Execute o Workflow de Deploy da Infraestrutura**

1. Acesse seu repositório no GitHub:
   ```
   https://github.com/SEU-USUARIO/ai-container-demo/actions
   ```

2. Clique no workflow **"1️⃣ Deploy Infrastructure"**

3. Clique em **"Run workflow"**
   - Branch: `main`
   - Clique em **"Run workflow"**

**O que este workflow faz:**

✅ Cria Azure Container Registry (ACR)  
✅ Cria Azure OpenAI com modelo GPT-4o-mini deployado  
✅ Cria AI Hub e AI Project (Azure AI Foundry)  
✅ Cria Container App Environment  
✅ Cria Container App (inicialmente com imagem placeholder)  
✅ Configura todas as permissões RBAC (Managed Identity)  
✅ Cria Key Vault, Storage Account, Application Insights  

**Tempo estimado:** 8-12 minutos

---

#### **Passo 3: Execute o Workflow de Build e Deploy da Aplicação**

⏱️ **Aguarde 2-3 minutos** após o Passo 2 para propagação das permissões Azure RBAC.

1. No GitHub Actions, clique no workflow **"2️⃣ Build and Deploy Container App"**

2. Clique em **"Run workflow"**
   - Branch: `main`
   - Clique em **"Run workflow"**

**O que este workflow faz:**

✅ Aguarda 1 minuto adicional para propagação de roles  
✅ Faz build da imagem Docker da aplicação  
✅ Push da imagem para o ACR  
✅ Atualiza o Container App com a nova imagem  
✅ Configura variáveis de ambiente (endpoints, deployment name)  
✅ Ativa o Container App (scale min replicas para 1)  

**Tempo estimado:** 3-5 minutos

---

#### **Passo 4: Acesse sua Aplicação**

Após a conclusão do workflow, você verá no log:

```
🚀 Container App URL: https://ai-chat-app.REGION.azurecontainerapps.io
📊 Test endpoint: https://ai-chat-app.REGION.azurecontainerapps.io/responses
```

**Acesse a URL** no navegador para usar o chat com Azure OpenAI! 🎉

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
curl -X POST https://sua-app.azurecontainerapps.io/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"Explique o que é Azure Container Apps"}'
```

**Resposta:**
```json
{
  "response": "Azure Container Apps é uma plataforma serverless..."
}
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
| Azure Container Apps | Consumption | ~$5-20 (scale-to-zero) |
| Azure Container Registry | Basic | ~$5 |
| Azure OpenAI (GPT-4o-mini) | Standard | ~$10-50 (pay-per-use) |
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



