# Quick Deployment Guide

## 🚀 Choose Your Deployment

### Option 1: Azure Container Apps (Recommended for Web Apps)

```bash
cd container-app

# Build image
az acr build --registry <your-acr> --image ai-container-app:latest .

# Deploy using Terraform
cd ../infrastructure
terraform init
terraform apply -var-file="container-app.tfvars"
```

**Cost**: ~$0.048/hour when active, $0 when idle  
**Best for**: Web applications, APIs, long-running processes

---

### Option 2: Azure Functions (Recommended for Serverless)

```bash
cd azure-functions

# Build image
az acr build --registry <your-acr> --image ai-functions-app:latest .

# Deploy using Terraform
cd ../infrastructure
terraform init
terraform apply -var-file="azure-functions.tfvars"
```

**Cost**: $0.0001/request (Consumption) or $146/month (Premium EP1)  
**Best for**: Event-driven, APIs, background processing

---

## 🔧 Prerequisites

1. **Azure CLI**: `az --version` should show 2.50+
2. **Terraform** (optional): `terraform --version` should show 1.5+
3. **Azure OpenAI Resource**: Already provisioned with deployment
4. **Container Registry**: Create or use existing ACR

---

## 📋 Step-by-Step (Container Apps Example)

```bash
# 1. Clone repository
git clone https://github.com/macieljrBiz/ai-container-demo.git
cd ai-container-demo

# 2. Configure variables
cd infrastructure
cp container-app.tfvars.example container-app.tfvars
# Edit container-app.tfvars with your values

# 3. Build image
cd ../container-app
az acr build --registry acraicondemo3700 --image ai-container-app:latest .

# 4. Deploy
cd ../infrastructure
terraform init
terraform apply -var-file="container-app.tfvars"

# 5. Get URL
terraform output container_app_url
```

---

## 🧪 Test Deployment

```bash
# Get URL from Terraform output
URL=$(terraform output -raw container_app_url)

# Test API
curl -X POST $URL/responses \
  -H "Content-Type: application/json" \
  -d '{"ask":"Hello from Azure!"}'
```

---

## 📚 Full Documentation

- Container Apps: `container-app/README.md`
- Azure Functions: `azure-functions/README.md`
- Infrastructure: `infrastructure/DEPLOY-*.md`
