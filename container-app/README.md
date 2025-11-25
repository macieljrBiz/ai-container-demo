# Azure Container Apps - AI Chat Application

FastAPI application demonstrating Azure OpenAI integration with managed identity authentication, optimized for Azure Container Apps.

---

## 🎯 Overview

This is a **serverless container application** that provides:
- Interactive web chat interface
- RESTful API for Azure OpenAI integration
- Managed Identity authentication
- Scale-to-zero capability (0 → 10 replicas)
- Cost-effective pricing: ~$0.048/hour when active, $0 when idle

---

## 🏗️ Architecture

```
┌─────────────────┐
│   User Browser  │
└────────┬────────┘
         │ HTTPS
         ▼
┌─────────────────────────────────┐
│  Azure Container App            │
│  ┌──────────────────────────┐   │
│  │  FastAPI (Port 8000)     │   │
│  │  • GET /  → Web UI       │   │
│  │  • POST /responses → API │   │
│  └──────────┬───────────────┘   │
│             │                   │
│  ┌──────────▼───────────────┐   │
│  │  Managed Identity        │   │
│  │  (System-Assigned)       │   │
│  └──────────┬───────────────┘   │
└─────────────┼───────────────────┘
              │ Token
              ▼
    ┌──────────────────────┐
    │  Azure OpenAI        │
    │  • Deployment: gpt-4 │
    └──────────────────────┘
```

---

## 📁 Files

```
container-app/
├── main.py              # FastAPI application
├── Dockerfile           # Container image definition
├── requirements.txt     # Python dependencies
└── static/
    └── index.html       # Web UI
```

---

## 🚀 Local Development

### 1. Create Virtual Environment

```bash
python -m venv .venv
.venv\Scripts\Activate.ps1  # Windows
# or
source .venv/bin/activate    # Linux/Mac
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Environment Variables

```bash
# Windows PowerShell
$env:AZURE_OPENAI_ENDPOINT="https://your-resource.cognitiveservices.azure.com/openai/v1/"
$env:AZURE_OPENAI_DEPLOYMENT="gpt-4"

# Linux/Mac
export AZURE_OPENAI_ENDPOINT="https://your-resource.cognitiveservices.azure.com/openai/v1/"
export AZURE_OPENAI_DEPLOYMENT="gpt-4"
```

### 4. Run Locally

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Access:
- **Web UI**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## 🐳 Build Container Image

### Option 1: Local Docker Build

```bash
docker build -t ai-container-app:latest .
docker run -p 8000:8000 \
  -e AZURE_OPENAI_ENDPOINT="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
  -e AZURE_OPENAI_DEPLOYMENT="gpt-4" \
  ai-container-app:latest
```

### Option 2: Azure Container Registry Build (Recommended)

```bash
# Build and push to ACR
az acr build --registry <your-acr> \
  --image ai-container-app:latest .

# Tag specific version
az acr build --registry <your-acr> \
  --image ai-container-app:v1.0.0 .
```

---

## ☁️ Deploy to Azure

### Method 1: Using Terraform

```bash
cd ../infrastructure
terraform init
terraform apply -var-file="container-app.tfvars"
```

Create `container-app.tfvars`:
```hcl
resource_group_name         = "rg-ai-container-demo"
location                    = "eastus"
acr_name                    = "acraicondemo"
container_app_name          = "ai-container-app"
azure_openai_endpoint       = "https://your-resource.cognitiveservices.azure.com/openai/v1/"
azure_openai_deployment     = "gpt-4"
azure_openai_resource_group = "rg-openai"
```

### Method 2: Using Bicep

```bash
cd ../infrastructure
az deployment group create \
  --resource-group rg-ai-container-demo \
  --template-file container-app.bicep \
  --parameters azureOpenAIEndpoint="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
               azureOpenAIResourceGroup="rg-openai" \
               azureOpenAIDeployment="gpt-4"
```

### Method 3: Azure CLI (Step-by-Step)

#### 1. Create Resource Group

```bash
az group create --name rg-ai-container-demo --location eastus
```

#### 2. Create Azure Container Registry

```bash
az acr create --resource-group rg-ai-container-demo \
  --name acraicondemo --sku Basic --admin-enabled true
```

#### 3. Build and Push Image

```bash
az acr build --registry acraicondemo \
  --image ai-container-app:latest .
```

#### 4. Create Log Analytics Workspace

```bash
az monitor log-analytics workspace create \
  --resource-group rg-ai-container-demo \
  --workspace-name law-ai-container-app
```

#### 5. Create Container Apps Environment

```bash
WORKSPACE_ID=$(az monitor log-analytics workspace show \
  --resource-group rg-ai-container-demo \
  --workspace-name law-ai-container-app \
  --query customerId -o tsv)

WORKSPACE_SECRET=$(az monitor log-analytics workspace get-shared-keys \
  --resource-group rg-ai-container-demo \
  --workspace-name law-ai-container-app \
  --query primarySharedKey -o tsv)

az containerapp env create \
  --name cae-ai-container-app \
  --resource-group rg-ai-container-demo \
  --location eastus \
  --logs-workspace-id $WORKSPACE_ID \
  --logs-workspace-key $WORKSPACE_SECRET
```

#### 6. Get ACR Credentials

```bash
ACR_LOGIN_SERVER=$(az acr show --name acraicondemo --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name acraicondemo --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name acraicondemo --query passwords[0].value -o tsv)
```

#### 7. Create Container App

```bash
az containerapp create \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --environment cae-ai-container-app \
  --image ${ACR_LOGIN_SERVER}/ai-container-app:latest \
  --target-port 8000 \
  --ingress external \
  --cpu 0.25 --memory 0.5Gi \
  --min-replicas 0 --max-replicas 10 \
  --registry-server $ACR_LOGIN_SERVER \
  --registry-username $ACR_USERNAME \
  --registry-password $ACR_PASSWORD \
  --env-vars \
    AZURE_OPENAI_ENDPOINT="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
    AZURE_OPENAI_DEPLOYMENT="gpt-4" \
  --system-assigned
```

#### 8. Configure Managed Identity

```bash
# Get principal ID
PRINCIPAL_ID=$(az containerapp show \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --query identity.principalId -o tsv)

# Assign role
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/<subscription-id>/resourceGroups/<openai-rg>/providers/Microsoft.CognitiveServices/accounts/<openai-name>
```

#### 9. Get Application URL

```bash
az containerapp show \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --query properties.configuration.ingress.fqdn -o tsv
```

---

## 🔄 Update Container App

### Update Image

```bash
# Build new image
az acr build --registry acraicondemo \
  --image ai-container-app:v2.0.0 .

# Update container app
az containerapp update \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --image acraicondemo.azurecr.io/ai-container-app:v2.0.0
```

### Update Environment Variables

```bash
az containerapp update \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --set-env-vars \
    AZURE_OPENAI_ENDPOINT="https://new-resource.cognitiveservices.azure.com/openai/v1/" \
    AZURE_OPENAI_DEPLOYMENT="gpt-4-turbo"
```

### Scale Configuration

```bash
az containerapp update \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --min-replicas 1 --max-replicas 20 \
  --cpu 0.5 --memory 1.0Gi
```

---

## 📊 Monitoring

### View Logs

```bash
az containerapp logs show \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --follow
```

### Metrics

```bash
# View metrics in Azure Portal
az containerapp browse \
  --name ai-container-app \
  --resource-group rg-ai-container-demo
```

### Cost Monitoring

```bash
# View current resource usage
az containerapp show \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --query "properties.template.{cpu:containers[0].resources.cpu,memory:containers[0].resources.memory,minReplicas:scale.minReplicas,maxReplicas:scale.maxReplicas}"
```

**Cost Formula:**
```
Cost/hour = (vCPU × $0.0000024/second + Memory_GiB × $0.0000027/second) × 3600 × replicas
```

**Example (0.25 vCPU, 0.5 GiB, 1 replica):**
```
Cost/hour = (0.25 × 0.0000024 + 0.5 × 0.0000027) × 3600
          = (0.0000006 + 0.00000135) × 3600
          = 0.00000195 × 3600
          = $0.00702/hour
```

---

## 🧪 Testing

### Test API

```bash
# Get URL
URL=$(az containerapp show \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --query properties.configuration.ingress.fqdn -o tsv)

# Test endpoint
curl -X POST https://$URL/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"What is Azure Container Apps?"}'
```

### Load Testing

```bash
# Install Azure Load Testing
az extension add --name load

# Run load test (requires test configuration)
az load test create \
  --test-id ai-container-app-test \
  --load-test-resource <resource-name> \
  --resource-group rg-ai-container-demo
```

---

## 🛠️ Troubleshooting

### Check Container App Status

```bash
az containerapp show \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --query "properties.{provisioningState:provisioningState,runningStatus:runningStatus}"
```

### View Recent Revisions

```bash
az containerapp revision list \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --output table
```

### Restart Container App

```bash
az containerapp revision restart \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --revision <revision-name>
```

---

## 💰 Cost Optimization

1. **Enable scale-to-zero** (default): `--min-replicas 0`
2. **Right-size resources**: Start with 0.25 vCPU, 0.5 GiB
3. **Use consumption plan**: Pay only for active time
4. **Monitor usage**: Set up cost alerts in Azure Portal

**Recommended Configuration for Production:**
```bash
az containerapp update \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --cpu 0.25 --memory 0.5Gi \
  --min-replicas 0 --max-replicas 10
```

---

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/cognitive-services/openai/)
- [Managed Identity Overview](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)

---

## 🤝 Support

For issues or questions, contact:
- Andressa Siqueira - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)
- Vicente Maciel Jr - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)
