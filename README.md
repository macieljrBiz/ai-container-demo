# AI Container Demo

**Authors:**  
Andressa Siqueira - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)  
Vicente Maciel Jr - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)

A demonstration of Azure OpenAI integration using **managed identity authentication** in two deployment options:
- **Azure Container Apps** - Serverless container platform with scale-to-zero
- **Azure Functions** - Event-driven serverless compute with containerized Python runtime

---

## 📁 Repository Structure

```
ai-container-demo/
├── container-app/           # FastAPI application for Azure Container Apps
│   ├── main.py             # FastAPI application code
│   ├── Dockerfile          # Container image definition
│   ├── requirements.txt    # Python dependencies
│   ├── static/             # Web UI files
│   └── README.md           # Container Apps specific guide
│
├── azure-functions/        # Azure Functions application
│   ├── function_app.py     # Functions v4 Python code
│   ├── host.json           # Functions runtime configuration
│   ├── Dockerfile          # Container image definition
│   ├── requirements.txt    # Python dependencies
│   ├── static/             # Web UI files
│   └── README.md           # Azure Functions specific guide
│
└── infrastructure/         # Infrastructure as Code (IaC)
    ├── container-app.tf    # Terraform for Container Apps
    ├── container-app.bicep # Bicep for Container Apps
    ├── azure-functions.tf  # Terraform for Azure Functions
    └── azure-functions.bicep # Bicep for Azure Functions
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

## 📦 Deployment Options on Azure

### 🚀 Opção 1: Deploy Simplificado (RECOMENDADO)

**Deploy em 2 passos**

#### Container Apps

**Pré-requisito: Configure o endpoint no código**

Antes de fazer o build, edite `container-app/main.py` linha 10 com o endpoint do seu modelo:
```python
endpoint = os.getenv("AZURE_OPENAI_ENDPOINT", "https://SEU-MODELO.openai.azure.com/")
```

**Passo 1: Build da imagem**
```bash
cd infrastructure

# Criar ACR (apenas uma vez)
az acr create \
  --resource-group rg-ai-demo \
  --name myacr123 \
  --sku Basic

# Build da imagem
az acr build \
  --registry myacr123 \
  --image ai-container-app:latest \
  --file ../container-app/Dockerfile \
  ../container-app
```

**Passo 2: Deploy da infraestrutura**

Clique no botão abaixo e preencha:
- **Container App Name**: Nome desejado do seu container 
- **ACR Name**: Nome do ACR que você criou no Passo 1
- **Container Image Name**: `ai-container-app:latest` (ou o nome da imagem que você usou)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Fcontainer-app-complete.json)

> **⚠️ NOTA**: O Container App inicia com `minReplicas: 0` para evitar falhas enquanto as permissões propagam. Após o deploy, siga o Passo 3 para ativá-lo.

**Passo 3: Ative o Container App (IMPORTANTE)**

Após o deploy concluir, aguarde 1-2 minutos e execute:

```bash
# Ative o Container App (escala de 0 para 1)
az containerapp update \
  --name <CONTAINER_APP_NAME> \
  --resource-group <RESOURCE_GROUP> \
  --min-replicas 1
```

Isso garante que as permissões de ACR estejam propagadas antes de fazer pull da imagem.

**Passo 4: Configure acesso ao AI Foundry**

Configure o acesso do Container App ao AI Foundry:

```bash
# Obtenha o Principal ID do Container App
PRINCIPAL_ID=$(az containerapp show \
  --name ai-container-app \
  --resource-group rg-ai-demo \
  --query identity.principalId -o tsv)

# Atribua role "Cognitive Services OpenAI User" ao modelo
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.CognitiveServices/accounts/<OPENAI_NAME>
```

Ou configure via portal:
1. Acesse seu recurso **Azure AI Foundry**
2. Vá em **Access Control (IAM)** > **Add role assignment**
3. Role: **Cognitive Services OpenAI User**
4. Assign access to: **Managed Identity**
5. Selecione o Container App criado

---

### 🔧 Troubleshooting

**Problema: "ContainerAppOperationError: Failed to provision revision" ou "Operation expired"**

Isso geralmente ocorre quando o Container App não consegue fazer pull da imagem do ACR devido a permissões. 

**Solução:**
```bash
# 1. Verifique se o role AcrPull foi atribuído
PRINCIPAL_ID=$(az containerapp show --name <SEU-APP> --resource-group <SEU-RG> --query "identity.principalId" -o tsv)
az role assignment list --assignee $PRINCIPAL_ID --all --query "[?contains(roleDefinitionName, 'Acr')]" -o table

# 2. Se não aparecer "AcrPull", atribua manualmente:
ACR_ID=$(az acr show --name <SEU-ACR> --resource-group <SEU-RG> --query "id" -o tsv)
az role assignment create --assignee $PRINCIPAL_ID --role "AcrPull" --scope $ACR_ID

# 3. Force uma nova revisão:
az containerapp update --name <SEU-APP> --resource-group <SEU-RG> --image <SEU-ACR>.azurecr.io/<IMAGEM>:latest
```

**Problema: Imagem não encontrada no ACR**

Verifique se a imagem existe e o nome está correto:
```bash
# Liste imagens no ACR
az acr repository list --name <SEU-ACR> -o table

# Liste tags da imagem
az acr repository show-tags --name <SEU-ACR> --repository <NOME-IMAGEM> -o table
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

## 📖 Additional Resources

- [Container Apps Documentation](./container-app/README.md)
- [Azure Functions Documentation](./azure-functions/README.md)
- [Azure Container Apps Pricing](https://azure.microsoft.com/pricing/details/container-apps/)
- [Azure Functions Pricing](https://azure.microsoft.com/pricing/details/functions/)
- [Azure OpenAI Service](https://azure.microsoft.com/products/cognitive-services/openai-service/)

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


