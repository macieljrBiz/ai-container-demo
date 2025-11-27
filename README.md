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
| **Cost (Scale-to-Zero)** | $0 when idle<br>~$0.048/hour when active (0.25 vCPU, 0.5 GiB) | $0 when idle<br>~$0.0001/request |
| **Use Case** | **This demo: Web UI + API** | **This demo: Serverless API** |

### 💡 When to Use Each

**Choose Container Apps when:**
- You have existing containerized applications
- You need full control over the runtime environment
- You want predictable costs with scale-to-zero
- You're building microservices or web applications

**Choose Azure Functions when:**
- You have event-driven workloads (timers, queues, etc.)
- You want serverless architecture with minimal management
- You need fine-grained per-execution billing
- You're building APIs or background processing

---

## 🚀 Quick Start

### Prerequisites

- Python 3.11 or higher
- Azure OpenAI resource with managed identity access configured
- Azure CLI installed and authenticated
- Docker (optional - can use `az acr build` for remote builds)
- Terraform or Bicep (for IaC deployment)

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/macieljrBiz/ai-container-demo.git
   cd ai-container-demo
   ```

2. **Choose your deployment option:**

   **Option A: Container Apps** (recommended for web apps)
   ```bash
   cd container-app
   # Follow container-app/README.md
   ```

   **Option B: Azure Functions** (recommended for APIs)
   ```bash
   cd azure-functions
   # Follow azure-functions/README.md
   ```

---

## 📦 Deployment Options

### 🚀 Opção 1: Deploy Simplificado (RECOMENDADO)

**Deploy em 2 passos - sem Deployment Scripts, sem Storage Account!**

#### Container Apps

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

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Fcontainer-app-complete.json)

**OU via CLI:**
```bash
az deployment group create \
  --resource-group rg-ai-demo \
  --template-file infrastructure/container-app-complete.bicep \
  --parameters \
    containerAppName=ai-app \
    acrName=myacr123 \
    azureOpenAIEndpoint=https://YOUR_ENDPOINT.openai.azure.com/ \
    azureOpenAIDeployment=gpt-4o
```

**OU via Script Automatizado:**
```bash
# Linux/Mac
cd infrastructure
./deploy.sh

# Windows
cd infrastructure
.\deploy.ps1
```

- ✅ Sem Deployment Scripts
- ✅ Sem Storage Account
- ✅ Sem Azure Policy conflicts
- ✅ Managed Identity configurada
- ⏱️ ~5-10 minutos

---

#### Azure Functions (Build + Deploy)
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Ffunctions-complete.json)

**OU via CLI:**
```bash
az deployment group create \
  --resource-group rg-ai-demo \
  --template-file infrastructure/functions-complete.bicep \
  --parameters \
    acrName=seuacr123 \
    azureOpenAIEndpoint="https://seu-openai.openai.azure.com/"

# Azure Functions
az deployment group create \
  --resource-group rg-ai-demo \
  --template-file infrastructure/functions-complete.bicep \
  --parameters \
    acrName=seuacr123 \
    functionAppName=suafuncao123
```

---

### ⚡ Opção 2: Script PowerShell (Deploy rápido com código local)

**Ideal para desenvolvimento - não precisa GitHub!**

```powershell
# No Azure Cloud Shell ou PowerShell local
./scripts/build-and-deploy.ps1
```

**O que faz:**
- ✅ Build das imagens no ACR (na nuvem, sem Docker local)
- ✅ Deploy completo da infraestrutura
- ✅ Configuração de Managed Identity e permissões
- ✅ Mais rápido: ~5-10 minutos

📖 **[Guia Completo para Clientes](./scripts/README-CLIENT.md)**

---

### 3️⃣ Deploy Separado (Apenas infraestrutura - sem build)

#### Container Apps (apenas infraestrutura)
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Fcontainer-app.json)

#### Using Terraform
```bash
cd infrastructure
terraform init
terraform plan -var-file="container-app.tfvars"
terraform apply -var-file="container-app.tfvars"
```

#### Using Bicep
```bash
cd infrastructure
az deployment group create \
  --resource-group rg-ai-container-demo \
  --template-file container-app.bicep \
  --parameters azureOpenAIEndpoint="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
               azureOpenAIResourceGroup="rg-openai"
```

#### Using Azure CLI (Manual)
```bash
cd container-app

# Build and push image
az acr build --registry <your-acr> --image ai-container-app:latest .

# Create Container App
az containerapp create \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --environment <your-environment> \
  --image <your-acr>.azurecr.io/ai-container-app:latest \
  --target-port 8000 \
  --ingress external \
  --cpu 0.25 --memory 0.5Gi \
  --min-replicas 0 --max-replicas 10 \
  --env-vars AZURE_OPENAI_ENDPOINT=<endpoint> AZURE_OPENAI_DEPLOYMENT=gpt-4 \
  --registry-server <your-acr>.azurecr.io \
  --system-assigned
```

### 2️⃣ Azure Functions Deployment

#### Using ARM Template (One-Click Deploy)
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Frefs%2Fheads%2Fmain%2Finfrastructure%2Fazure-functions.json)

#### Using Terraform
```bash
cd infrastructure
terraform init
terraform plan -var-file="azure-functions.tfvars"
terraform apply -var-file="azure-functions.tfvars"
```
#### Using Bicep (One-Click Deploy)
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FmacieljrBiz%2Fai-container-demo%2Fmain%2Finfrastructure%2Fcontainer-app.bicep)

#### Using Bicep
```bash
cd infrastructure
az deployment group create \
  --resource-group rg-ai-functions-demo \
  --template-file azure-functions.bicep \
  --parameters azureOpenAIEndpoint="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
               azureOpenAIResourceGroup="rg-openai"
```

#### Using Azure CLI (Manual)
```bash
cd azure-functions

# Build and push image
az acr build --registry <your-acr> --image ai-functions-app:latest .

# Create Function App
az functionapp create \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --plan <your-plan> \
  --deployment-container-image-name <your-acr>.azurecr.io/ai-functions-app:latest \
  --docker-registry-server-url https://<your-acr>.azurecr.io \
  --storage-account <your-storage> \
  --system-assigned-identity
```

---

## 🔐 Managed Identity Configuration

Both applications use **System-Assigned Managed Identity** to authenticate with Azure OpenAI.

### Assign Role (Automatic with IaC)
Terraform/Bicep automatically assigns the **"Cognitive Services OpenAI User"** role.

### Manual Role Assignment
```bash
# Get the principal ID
PRINCIPAL_ID=$(az containerapp show --name ai-container-app --resource-group rg-ai-container-demo --query identity.principalId -o tsv)

# Or for Functions
PRINCIPAL_ID=$(az functionapp show --name ai-functions-app --resource-group rg-ai-functions-demo --query identity.principalId -o tsv)

# Assign role
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/<subscription-id>/resourceGroups/<openai-rg>/providers/Microsoft.CognitiveServices/accounts/<openai-name>
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


