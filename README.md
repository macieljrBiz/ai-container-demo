# AI Container Demo

**Authors:**  
Andressa Siqueira - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)  
Vicente Maciel Jr - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)

---

## 📝 Sobre o Projeto

Demonstração de integração com **Azure OpenAI** usando **autenticação por Managed Identity** e **deploy profissional via CI/CD**, seguindo as melhores práticas do **Microsoft Well-Architected Framework**.

Este projeto ilustra como:
- 🤖 Integrar Azure OpenAI de forma segura (sem chaves de API hardcoded)
- 🔐 Usar Managed Identity para autenticação
- 🚀 Implementar CI/CD profissional com GitHub Actions e OIDC
- 📦 Deployar containerizados em Azure Container Apps
- ⚡ Lidar com propagação de permissões do Azure RBAC

**Deployment:**
- **Azure Container Apps** - Serverless container platform with scale-to-zero
- **GitHub Actions** - Automated CI/CD with OIDC authentication

---

## 📁 Repository Structure

```
ai-container-demo/
├── .github/
│   ├── workflows/
│   │   ├── setup-oidc.yml               # 0️⃣ Setup OIDC (automated)
│   │   ├── cleanup-service-principal.yml # 3️⃣ Cleanup Service Principal
│   │   ├── deploy-infrastructure.yml    # 1️⃣ Deploy Bicep template
│   │   └── activate-container-app.yml   # 2️⃣ Activate after role propagation
│   └── README.md                        # Complete setup guide
│
├── container-app/           # FastAPI application for Azure Container Apps
│   ├── main.py             # FastAPI application code
│   ├── Dockerfile          # Container image definition
│   ├── requirements.txt    # Python dependencies
│   └── static/             # Web UI files
│
├── azure-functions/        # Azure Functions application
│   ├── function_app.py     # Functions v4 Python code
│   ├── host.json           # Functions runtime configuration
│   ├── Dockerfile          # Container image definition
│   ├── requirements.txt    # Python dependencies
│   └── static/             # Web UI files
│
└── infrastructure/         # Infrastructure as Code (Bicep)
    ├── container-app-complete.bicep  # Container App with roles
    ├── functions-complete.bicep      # Azure Functions with roles
    ├── openai-role.bicep            # Cross-RG role assignment module
    ├── deploy.sh / deploy.ps1       # CLI deployment scripts (alternative)
    └── *.json                       # Compiled ARM templates for Deploy Buttons
```

---

## 🎯 Features

- **Azure OpenAI Integration** with token-based authentication
- **Managed Identity** (System-Assigned) for secure authentication
- **Interactive Web UI** for chat interface
- **REST API** endpoints for AI responses
- **Infrastructure as Code** (Terraform + Bicep)
- **Containerized** deployment options

---

## 🔄 Container Apps vs Azure Functions

| Feature | **Azure Container Apps** | **Azure Functions** |
|---------|-------------------------|---------------------|
| **Best For** | Long-running processes, web apps, APIs | Event-driven, short-lived executions |
| **Scaling** | Scale 0-10+ replicas, HTTP-based | Auto-scale based on triggers |
| **Pricing Model** | Pay per vCPU/memory per second | Consumption: pay per execution<br>Premium: always-on |
| **Cold Start** | Minimal (when scaled to 0) | Yes (Consumption plan) |
| **Framework** | Any (FastAPI, Django, Flask, etc.) | Azure Functions runtime |
| **Ingress** | HTTP/HTTPS on port 8000 | HTTP triggers on `/api/*` routes |

---

## 🚀 Quick Start

### Pré-requisitos

**Para desenvolvimento local:**
- Python 3.11 ou superior
- Docker (opcional)

**Para deploy no Azure:**
- Azure CLI instalado e autenticado (`az login`)
- **Azure AI Foundry** com modelo deployado (exemplo: gpt-4o)
  - Você precisará do **endpoint** do modelo (ex: `https://seu-modelo.openai.azure.com/`)
  - Configure **Managed Identity** com permissões no modelo

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/macieljrBiz/ai-container-demo.git
   cd ai-container-demo
   ```

2. **Configure o endpoint do Azure AI Foundry**
   
   No arquivo `container-app/main.py`, edite a linha 10:
   ```python
   endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "https://SEU-MODELO.openai.azure.com/")
   ```
   
   Substitua `https://SEU-MODELO.openai.azure.com/` pelo endpoint do seu modelo no AI Foundry.
   
   **Como obter o endpoint:**
   - Acesse [Azure AI Foundry](https://ai.azure.com)
   - Navegue até seu projeto
   - Vá em **Deployments** > Selecione seu modelo
   - Copie o **Target URI** (endpoint)

3. **Teste localmente**

   **Opção A: Usando Docker**
   ```bash
   cd container-app
   
   # Build da imagem
   docker build -t ai-container-app .
   
   # Execute o container (substitua pelo seu endpoint)
   docker run -p 8000:8000 \
     -e AZURE_OPENAI_ENDPOINT="https://SEU-MODELO.openai.azure.com/" \
     ai-container-app
   ```

   **Opção B: Usando pip (desenvolvimento)**
   ```bash
   cd container-app
   
   # Instale dependências
   pip install -r requirements.txt
   
   # Configure variáveis de ambiente
   export AZURE_OPENAI_ENDPOINT="https://SEU-MODELO.openai.azure.com/"
   
   # Execute localmente
   uvicorn main:app --reload --port 8000
   ```

   Acesse: http://localhost:8000

---

## 🚀 Deploy via GitHub Actions

**📚 Guia completo:** [.github/GITHUB-REQUISITOS.md](.github/GITHUB-REQUISITOS.md)

### Resumo Rápido:

1. **Setup OIDC** (uma vez):
   
   **PowerShell:**
   ```powershell
   # Criar Service Principal
   $SUBSCRIPTION_ID = az account show --query id -o tsv
   az ad sp create-for-rbac `
     --name "sp-github-oidc-setup" `
     --role "Owner" `
     --scopes "/subscriptions/$SUBSCRIPTION_ID" `
     --sdk-auth
   
   # Configurar AZURE_SETUP_CREDENTIALS no GitHub
   # Executar workflow: 0️⃣ Setup OIDC
   # Configurar 3 secrets OIDC
   # Executar workflow: 3️⃣ Cleanup Service Principal
   ```
   
   **Bash:**
   ```bash
   # Criar Service Principal
   SUBSCRIPTION_ID=$(az account show --query id -o tsv)
   az ad sp create-for-rbac \
     --name "sp-github-oidc-setup" \
     --role "Owner" \
     --scopes "/subscriptions/$SUBSCRIPTION_ID" \
     --sdk-auth
   
   # Configurar AZURE_SETUP_CREDENTIALS no GitHub
   # Executar workflow: 0️⃣ Setup OIDC
   # Configurar 3 secrets OIDC
   # Executar workflow: 3️⃣ Cleanup Service Principal
   ```

2. **Deploy** (sempre):
   ```
   Executar: 1️⃣ Deploy Infrastructure
   Aguardar: 2-3 minutos
   Executar: 2️⃣ Activate Container App
   ```

---

## 🔘 Deploy Alternativo via Portal Azure

<details>
<summary>Click to expand</summary>

O script irá:
- ✅ Validar Azure CLI e autenticação
- ✅ Pedir informações necessárias (com valores padrão)
- ✅ Criar Managed Identity
- ✅ Atribuir roles (Contributor + User Access Administrator)
- ✅ Criar Federated Credential
- ✅ Exibir os 3 valores para configurar no GitHub

Depois, configure os 3 secrets no GitHub com os valores exibidos.

</details>

<details>
<summary><strong>🐧 Opção C: Script Bash (Linux/macOS)</strong> - Recomendado para uso individual</summary>

Execute localmente (requer `az login`):
```bash
bash .github/setup-oidc.sh
```

O script irá:
- ✅ Validar Azure CLI e autenticação
- ✅ Pedir informações necessárias (com valores padrão)
- ✅ Criar Managed Identity
- ✅ Atribuir roles (Contributor + User Access Administrator)
- ✅ Criar Federated Credential
- ✅ Exibir os 3 valores para configurar no GitHub

Depois, configure os 3 secrets no GitHub com os valores exibidos.

</details>
</details>

---

## 🔧 Troubleshooting

### Problema: Container App não ativa após deploy

**Sintoma:** Container App fica com 0 replicas ou falha ao iniciar

**Causa:** Permissões de ACR ainda não propagaram globalmente (1-5 minutos)

**Solução:**
```bash
# Aguarde 2-3 minutos após o deploy inicial e execute:
az containerapp update \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --min-replicas 1
```

---

### Problema: "401 Unauthorized" ao chamar Azure OpenAI

**Sintoma:** API retorna erro de autenticação

**Causa:** Role "Cognitive Services OpenAI User" ainda não propagou

**Solução:**
```bash
# Verifique se o role assignment existe
PRINCIPAL_ID=$(az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query identity.principalId -o tsv)

az role assignment list --assignee $PRINCIPAL_ID --all -o table

# Se não aparecer, aguarde mais 1-2 minutos ou force novamente
```

---

### Problema: "Failed to provision revision" ou "Operation expired"

**Sintoma:** Deploy falha com erro de provisionamento

**Causa:** Container App tentou ativar antes das permissões de ACR propagarem

**Solução:** Este problema foi resolvido! O template já cria o Container App com `minReplicas: 0`. Basta seguir o passo de ativação após aguardar 2-3 minutos.

---

### Como verificar status do Container App

```bash
# Ver status geral
az containerapp show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --query "{Status:properties.provisioningState, Replicas:properties.template.scale, URL:properties.configuration.ingress.fqdn}" -o table

# Ver logs
az containerapp logs show \
  --name <container-app-name> \
  --resource-group <resource-group> \
  --follow
```

---

## 📊 API Endpoints

### Container Apps
- **Web UI**: `https://<app-name>.azurecontainerapps.io/`
- **Root**: `GET /` → Returns web interface
- **Chat API**: `POST /responses`
  ```json
  {
    "ask": "What is the capital of Brazil?"
  }
  ```

### Azure Functions
- **Web UI**: `https://<app-name>.azurewebsites.net/api/index`
- **Chat API**: `POST /api/responses`
  ```json
  {
    "ask": "What is the capital of Brazil?"
  }
  ```

---

## 🧪 Testing

### Using REST Client (VS Code Extension)
```http
### Test Container Apps
POST https://<app-name>.azurecontainerapps.io/responses
Content-Type: application/json

{
  "ask": "What is AI?"
}

### Test Azure Functions
POST https://<app-name>.azurewebsites.net/api/responses
Content-Type: application/json

{
  "ask": "What is AI?"
}
```

### Using curl
```bash
# Container Apps
curl -X POST https://<app-name>.azurecontainerapps.io/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"What is AI?"}'

# Azure Functions
curl -X POST https://<app-name>.azurewebsites.net/api/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"What is AI?"}'
```

### Using PowerShell
```powershell
# Container Apps
Invoke-RestMethod -Uri "https://<app-name>.azurecontainerapps.io/responses" `
  -Method POST -ContentType "application/json" `
  -Body '{"ask":"What is AI?"}'

# Azure Functions
Invoke-RestMethod -Uri "https://<app-name>.azurewebsites.net/api/responses" `
  -Method POST -ContentType "application/json" `
  -Body '{"ask":"What is AI?"}'
```

---

## 📚 Interactive API Documentation

### Container Apps
- **Swagger UI**: `https://<app-name>.azurecontainerapps.io/docs`
- **ReDoc**: `https://<app-name>.azurecontainerapps.io/redoc`

### Azure Functions
Azure Functions does not automatically generate OpenAPI documentation, but you can access the web UI at `/api/index`.

---

## 🛠️ Dependencies

### Container Apps (FastAPI)
- `fastapi` - Modern web framework for building APIs
- `uvicorn` - ASGI server for running FastAPI
- `openai` - Azure OpenAI client library
- `azure-identity` - Azure authentication library
- `httpx` - HTTP client (required by openai library)
- `pydantic` - Data validation using Python type hints

### Azure Functions
- `azure-functions` - Azure Functions Python worker
- `openai` - Azure OpenAI client library
- `azure-identity` - Azure authentication library

---

## 📚 Additional Resources

### Documentation
- **[GitHub Actions Setup Guide](.github/GITHUB_ACTIONS_SETUP.md)** - Complete CI/CD configuration
- [Azure Container Apps Best Practices](https://learn.microsoft.com/en-us/azure/well-architected/service-guides/azure-container-apps)
- [Deploy Bicep with GitHub Actions](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/deploy-github-actions)
- [Azure RBAC Troubleshooting](https://learn.microsoft.com/en-us/azure/role-based-access-control/troubleshooting)

### Pricing
- [Azure Container Apps Pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [Azure Functions Pricing](https://azure.microsoft.com/pricing/details/functions/)
- [Azure OpenAI Service Pricing](https://azure.microsoft.com/pricing/details/cognitive-services/openai-service/)

---

## 📄 License

This is a demo application for educational purposes.

---

## 🤝 Contributing

Feel free to submit issues or pull requests to improve this demo!

---

## 📧 Contact

For questions or feedback, reach out to:
- Andressa Siqueira - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)
- Vicente Maciel Jr - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)


