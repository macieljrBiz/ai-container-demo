# Estrutura do Repositório ai-container-demo

```
ai-container-demo/
│
├── README.md                    # Documentação principal com comparativo
├── QUICKSTART.md                # Guia rápido de deployment
├── .gitignore                   # Exclusões do Git
│
├── container-app/               # 🐳 Azure Container Apps
│   ├── README.md                # Guia específico de Container Apps
│   ├── main.py                  # FastAPI application
│   ├── Dockerfile               # Container image
│   ├── requirements.txt         # Python dependencies
│   └── static/
│       └── index.html           # Web UI
│
├── azure-functions/             # ⚡ Azure Functions
│   ├── README.md                # Guia específico de Azure Functions
│   ├── function_app.py          # Functions v4 Python
│   ├── host.json                # Functions runtime config
│   ├── Dockerfile               # Container image
│   ├── requirements.txt         # Python dependencies
│   └── static/
│       └── index.html           # Web UI
│
└── infrastructure/              # 🏗️ Infrastructure as Code
    ├── DEPLOY-CONTAINER-APPS.md # Guia de deploy Container Apps
    ├── DEPLOY-AZURE-FUNCTIONS.md# Guia de deploy Functions
    │
    ├── container-app.tf         # Terraform - Container Apps
    ├── container-app.bicep      # Bicep - Container Apps
    ├── container-app.tfvars.example # Variáveis exemplo
    │
    ├── azure-functions.tf       # Terraform - Functions
    ├── azure-functions.bicep    # Bicep - Functions
    └── azure-functions.tfvars.example # Variáveis exemplo
```

## 📦 Arquivos Criados

### Root (6 arquivos)
- ✅ README.md - Documentação completa com comparativo Container Apps vs Functions
- ✅ QUICKSTART.md - Guia rápido de início
- ✅ .gitignore - Configuração Git

### container-app/ (5 arquivos + static/)
- ✅ README.md - Documentação detalhada Container Apps
- ✅ main.py - FastAPI com Managed Identity
- ✅ Dockerfile - Python 3.11 slim
- ✅ requirements.txt - FastAPI, uvicorn, openai, azure-identity
- ✅ static/index.html - Interface web de chat

### azure-functions/ (6 arquivos + static/)
- ✅ README.md - Documentação detalhada Azure Functions
- ✅ function_app.py - Functions v4 Python com Managed Identity
- ✅ host.json - Configuração runtime Functions
- ✅ Dockerfile - Azure Functions base image
- ✅ requirements.txt - azure-functions, openai, azure-identity
- ✅ static/index.html - Interface web de chat

### infrastructure/ (8 arquivos)
- ✅ container-app.tf - Terraform completo para Container Apps
- ✅ container-app.bicep - Bicep completo para Container Apps
- ✅ container-app.tfvars.example - Exemplo de variáveis
- ✅ azure-functions.tf - Terraform completo para Functions
- ✅ azure-functions.bicep - Bicep completo para Functions
- ✅ azure-functions.tfvars.example - Exemplo de variáveis
- ✅ DEPLOY-CONTAINER-APPS.md - Guia deployment
- ✅ DEPLOY-AZURE-FUNCTIONS.md - Guia deployment

## 🎯 Total: 27 arquivos criados

## 🔑 Principais Recursos IaC

### Container Apps (Terraform + Bicep)
- Azure Container Registry
- Log Analytics Workspace
- Container Apps Environment
- Container App com Managed Identity
- Role Assignment (Cognitive Services OpenAI User)
- Outputs: URL, Principal ID, ACR

### Azure Functions (Terraform + Bicep)
- Azure Container Registry
- Storage Account
- App Service Plan (Consumption Y1)
- Function App com Managed Identity
- Application Insights
- Role Assignment (Cognitive Services OpenAI User)
- Outputs: URL, Principal ID, ACR

## 📝 Destaques da Documentação

### README.md Principal
- Tabela comparativa Container Apps vs Functions
- Guias de deployment para ambas opções
- Análise de custos detalhada
- Exemplos de uso com curl, PowerShell, REST Client
- Configuração de Managed Identity
- Links para documentação adicional

### READMEs Específicos
- Desenvolvimento local passo a passo
- Build de containers (local e ACR)
- Deployment com Terraform, Bicep e Azure CLI
- Atualização de aplicações
- Monitoramento e logs
- Troubleshooting
- Otimização de custos
