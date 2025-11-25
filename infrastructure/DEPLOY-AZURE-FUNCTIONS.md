# Deploy Azure Functions

## Using Terraform

```bash
cd infrastructure

# Copy example file and edit with your values
cp azure-functions.tfvars.example azure-functions.tfvars
# Edit azure-functions.tfvars with your specific values

# Initialize Terraform
terraform init

# Plan deployment
terraform plan -var-file="azure-functions.tfvars"

# Apply deployment
terraform apply -var-file="azure-functions.tfvars"

# Get outputs
terraform output
```

## Using Bicep

```bash
cd infrastructure

# Deploy
az deployment group create \
  --resource-group rg-ai-functions-demo \
  --template-file azure-functions.bicep \
  --parameters \
    azureOpenAIEndpoint="https://your-resource.cognitiveservices.azure.com/openai/v1/" \
    azureOpenAIResourceGroup="rg-openai" \
    azureOpenAIDeployment="gpt-4" \
    acrName="acraifunctions3700" \
    functionAppName="ai-functions-app" \
    storageAccountName="staifunctions3700"

# Get outputs
az deployment group show \
  --resource-group rg-ai-functions-demo \
  --name azure-functions \
  --query properties.outputs
```

## Using Azure CLI

See detailed step-by-step in `azure-functions/README.md`
