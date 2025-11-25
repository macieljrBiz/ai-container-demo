# Azure Functions - AI Chat Application

Azure Functions v4 Python application demonstrating Azure OpenAI integration with managed identity authentication, deployed as a containerized function.

---

## 🎯 Overview

This is a **serverless function application** that provides:
- HTTP-triggered Azure Functions
- Interactive web chat interface at `/api/index`
- RESTful API at `/api/responses`
- Managed Identity authentication
- Containerized deployment
- Cost-effective: Pay per execution (Consumption) or always-on (Premium)

---

## 🏗️ Architecture

```
┌─────────────────┐
│   User Browser  │
└────────┬────────┘
         │ HTTPS
         ▼
┌──────────────────────────────────┐
│  Azure Function App              │
│  ┌───────────────────────────┐   │
│  │  Functions Runtime v4     │   │
│  │  • GET /api/index → UI    │   │
│  │  • POST /api/responses    │   │
│  └──────────┬────────────────┘   │
│             │                    │
│  ┌──────────▼────────────────┐   │
│  │  Managed Identity         │   │
│  │  (System-Assigned)        │   │
│  └──────────┬────────────────┘   │
└─────────────┼────────────────────┘
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
azure-functions/
├── function_app.py      # Functions v4 Python code
├── host.json            # Functions runtime configuration
├── Dockerfile           # Container image definition
├── requirements.txt     # Python dependencies
└── static/
    └── index.html       # Web UI
```

---

## 🚀 Local Development

### 1. Install Azure Functions Core Tools

```bash
# Windows (with Chocolatey)
choco install azure-functions-core-tools

# macOS
brew tap azure/functions
brew install azure-functions-core-tools@4

# Ubuntu/Debian
wget -q https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update
sudo apt-get install azure-functions-core-tools-4
```

### 2. Create Virtual Environment

```bash
python -m venv .venv
.venv\Scripts\Activate.ps1  # Windows
# or
source .venv/bin/activate    # Linux/Mac
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Create local.settings.json

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "AZURE_OPENAI_ENDPOINT": "https://your-resource.cognitiveservices.azure.com/openai/v1/",
    "AZURE_OPENAI_DEPLOYMENT": "gpt-4"
  }
}
```

### 5. Run Locally

```bash
func start
```

Access:
- **Web UI**: http://localhost:7071/api/index
- **Chat API**: http://localhost:7071/api/responses

---

## 🐳 Build Container Image

### Option 1: Local Docker Build

```bash
docker build -t ai-functions-app:latest .
docker run -p 8080:80 \
  -e AZURE_OPENAI_ENDPOINT="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
  -e AZURE_OPENAI_DEPLOYMENT="gpt-4" \
  ai-functions-app:latest
```

### Option 2: Azure Container Registry Build (Recommended)

```bash
# Build and push to ACR
az acr build --registry <your-acr> \
  --image ai-functions-app:latest .

# Tag specific version
az acr build --registry <your-acr> \
  --image ai-functions-app:v1.0.0 .
```

---

## ☁️ Deploy to Azure

### Method 1: Using Terraform

```bash
cd ../infrastructure
terraform init
terraform apply -var-file="azure-functions.tfvars"
```

Create `azure-functions.tfvars`:
```hcl
resource_group_name         = "rg-ai-functions-demo"
location                    = "brazilsouth"
acr_name                    = "acraifunctions"
function_app_name           = "ai-functions-app"
storage_account_name        = "staifunctions"
azure_openai_endpoint       = "https://your-resource.cognitiveservices.azure.com/openai/v1/"
azure_openai_deployment     = "gpt-4"
azure_openai_resource_group = "rg-openai"
```

### Method 2: Using Bicep

```bash
cd ../infrastructure
az deployment group create \
  --resource-group rg-ai-functions-demo \
  --template-file azure-functions.bicep \
  --parameters azureOpenAIEndpoint="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
               azureOpenAIResourceGroup="rg-openai" \
               azureOpenAIDeployment="gpt-4"
```

### Method 3: Azure CLI (Step-by-Step)

#### 1. Create Resource Group

```bash
az group create --name rg-ai-functions-demo --location brazilsouth
```

#### 2. Create Azure Container Registry

```bash
az acr create --resource-group rg-ai-functions-demo \
  --name acraifunctions --sku Basic --admin-enabled true
```

#### 3. Build and Push Image

```bash
az acr build --registry acraifunctions \
  --image ai-functions-app:latest .
```

#### 4. Create Storage Account

```bash
az storage account create \
  --name staifunctions \
  --resource-group rg-ai-functions-demo \
  --location brazilsouth \
  --sku Standard_LRS
```

#### 5. Create Application Insights

```bash
az monitor app-insights component create \
  --app ai-functions-insights \
  --resource-group rg-ai-functions-demo \
  --location brazilsouth
```

#### 6. Create Function App Plan

**Option A: Consumption Plan (Pay per execution)**
```bash
az functionapp plan create \
  --name asp-ai-functions \
  --resource-group rg-ai-functions-demo \
  --location brazilsouth \
  --sku Y1 \
  --is-linux
```

**Option B: Premium Plan (Always-on, better performance)**
```bash
az functionapp plan create \
  --name asp-ai-functions-premium \
  --resource-group rg-ai-functions-demo \
  --location brazilsouth \
  --sku EP1 \
  --is-linux
```

#### 7. Get ACR Credentials

```bash
ACR_LOGIN_SERVER=$(az acr show --name acraifunctions --query loginServer -o tsv)
ACR_USERNAME=$(az acr credential show --name acraifunctions --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name acraifunctions --query passwords[0].value -o tsv)
```

#### 8. Create Function App with Container

```bash
az functionapp create \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --plan asp-ai-functions \
  --storage-account staifunctions \
  --deployment-container-image-name ${ACR_LOGIN_SERVER}/ai-functions-app:latest \
  --docker-registry-server-url https://${ACR_LOGIN_SERVER} \
  --docker-registry-server-user $ACR_USERNAME \
  --docker-registry-server-password $ACR_PASSWORD \
  --functions-version 4 \
  --os-type Linux \
  --runtime python \
  --runtime-version 3.11 \
  --assign-identity [system]
```

#### 9. Configure App Settings

```bash
az functionapp config appsettings set \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --settings \
    AZURE_OPENAI_ENDPOINT="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
    AZURE_OPENAI_DEPLOYMENT="gpt-4" \
    WEBSITES_ENABLE_APP_SERVICE_STORAGE=false
```

#### 10. Configure Managed Identity

```bash
# Get principal ID
PRINCIPAL_ID=$(az functionapp show \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --query identity.principalId -o tsv)

# Assign role
az role assignment create \
  --role "Cognitive Services OpenAI User" \
  --assignee $PRINCIPAL_ID \
  --scope /subscriptions/<subscription-id>/resourceGroups/<openai-rg>/providers/Microsoft.CognitiveServices/accounts/<openai-name>
```

#### 11. Get Application URL

```bash
az functionapp show \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --query defaultHostName -o tsv
```

---

## 🔄 Update Function App

### Update Container Image

```bash
# Build new image
az acr build --registry acraifunctions \
  --image ai-functions-app:v2.0.0 .

# Update function app
az functionapp config container set \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --docker-custom-image-name acraifunctions.azurecr.io/ai-functions-app:v2.0.0

# Restart to apply changes
az functionapp restart \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo
```

### Update Environment Variables

```bash
az functionapp config appsettings set \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --settings \
    AZURE_OPENAI_ENDPOINT="https://new-resource.cognitiveservices.azure.com/openai/v1/" \
    AZURE_OPENAI_DEPLOYMENT="gpt-4-turbo"
```

---

## 📊 Monitoring

### View Logs (Streaming)

```bash
az webapp log tail \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo
```

### View Logs (Application Insights)

```bash
# Query logs
az monitor app-insights query \
  --app ai-functions-insights \
  --resource-group rg-ai-functions-demo \
  --analytics-query "traces | where timestamp > ago(1h) | order by timestamp desc"
```

### Function Execution History

Access the Azure Portal:
1. Navigate to Function App → Functions → responses
2. View "Monitor" tab for execution history
3. Click on individual executions for detailed logs

---

## 🧪 Testing

### Test API

```bash
# Get URL
URL=$(az functionapp show \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --query defaultHostName -o tsv)

# Test endpoint
curl -X POST https://$URL/api/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"What is Azure Functions?"}'
```

### PowerShell Testing

```powershell
$URL = az functionapp show `
  --name ai-functions-app `
  --resource-group rg-ai-functions-demo `
  --query defaultHostName -o tsv

Invoke-RestMethod -Uri "https://$URL/api/responses" `
  -Method POST -ContentType "application/json" `
  -Body '{"ask":"What is Azure Functions?"}'
```

---

## 💰 Cost Comparison

### Consumption Plan (Y1)
- **Idle**: $0/month (free grant: 1M executions + 400,000 GB-s)
- **Per Execution**: $0.0000002/execution
- **Per GB-s**: $0.000016/GB-s
- **Example (1000 req/day, 1s each, 512MB)**:
  - Executions: 30,000 × $0.0000002 = $0.006
  - Compute: 30,000 × 1s × 0.5GB × $0.000016 = $0.24
  - **Total**: ~$0.25/month

### Premium Plan (EP1)
- **Always-on**: ~$146/month
- **Includes**: 1 vCPU, 3.5 GB RAM
- **Best for**: Production workloads requiring <1s cold start

### Container Apps Alternative
- **Scale-to-zero**: $0 when idle
- **Active (0.25 vCPU, 0.5 GiB)**: ~$0.048/hour
- **Best for**: Web applications with predictable traffic

---

## 🛠️ Troubleshooting

### Check Function App Status

```bash
az functionapp show \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --query "state"
```

### View Configuration

```bash
az functionapp config appsettings list \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo \
  --output table
```

### Restart Function App

```bash
az functionapp restart \
  --name ai-functions-app \
  --resource-group rg-ai-functions-demo
```

### Common Issues

**Issue: 404 Not Found**
- Solution: Ensure routes include `/api/` prefix (e.g., `/api/responses`)

**Issue: 500 Internal Server Error**
- Solution: Check Application Insights logs for detailed error traces
- Verify Managed Identity has "Cognitive Services OpenAI User" role

**Issue: Cold Start Delays**
- Solution: Consider Premium Plan (EP1) for <1s cold start
- Or use Container Apps with min replicas > 0

---

## 📚 Additional Resources

- [Azure Functions Documentation](https://learn.microsoft.com/azure/azure-functions/)
- [Functions Python Developer Guide](https://learn.microsoft.com/azure/azure-functions/functions-reference-python)
- [Azure OpenAI Service](https://learn.microsoft.com/azure/cognitive-services/openai/)
- [Managed Identity in Functions](https://learn.microsoft.com/azure/app-service/overview-managed-identity)

---

## 🤝 Support

For issues or questions, contact:
- Andressa Siqueira - [ansiqueira@microsoft.com](mailto:ansiqueira@microsoft.com)
- Vicente Maciel Jr - [vicentem@microsoft.com](mailto:vicentem@microsoft.com)
