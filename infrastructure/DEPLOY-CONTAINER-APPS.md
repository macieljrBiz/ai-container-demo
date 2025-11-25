# Deploy Azure Container Apps

## Using Terraform

```bash
cd infrastructure

# Copy example file and edit with your values
cp container-app.tfvars.example container-app.tfvars
# Edit container-app.tfvars with your specific values

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="container-app.tfvars"

# Apply deployment
terraform apply -var-file="container-app.tfvars"

# Get outputs
terraform output
```

## Using Bicep

```bash
cd infrastructure

# Deploy
az deployment group create \
  --resource-group rg-ai-container-demo \
  --template-file container-app.bicep \
  --parameters \
    azureOpenAIEndpoint="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
    azureOpenAIResourceGroup="rg-openai" \
    azureOpenAIDeployment="gpt-4" \
    acrName="acraicondemo3700" \
    containerAppName="ai-container-app"

# Get outputs
az deployment group show \
  --resource-group rg-ai-container-demo \
  --name container-app \
  --query properties.outputs
```

## Using Azure CLI

See detailed step-by-step in `container-app/README.md`
