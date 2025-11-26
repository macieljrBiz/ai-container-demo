# 🚀 All-in-One Deployment com Bicep

## ✨ Solução Única - Build + Deploy em 1 Comando

Este template Bicep faz **TUDO** em uma única execução:
1. ✅ Cria Azure Container Registry
2. ✅ **Faz build das imagens no ACR** (usando Deployment Scripts)
3. ✅ Cria Container Apps + Functions
4. ✅ Configura Managed Identity
5. ✅ Atribui permissões ACR

---

## 🎯 Uso Simples

### Opção 1: Azure Portal

1. Acesse: https://portal.azure.com
2. Crie um Resource Group
3. Dentro do RG, clique em **Create** → **Template deployment**
4. Escolha **Build your own template**
5. Cole o conteúdo de `all-in-one-deploy.bicep`
6. Preencha os parâmetros:
   - `azureOpenAIEndpoint`: URL do seu Azure OpenAI
   - Deixe os outros com valores padrão
7. Clique em **Review + Create**

⏱️ **Tempo**: ~15-20 minutos (build leva mais tempo que deploy normal)

---

### Opção 2: Azure CLI

```bash
# Criar Resource Group
az group create --name rg-ai-container-demo --location eastus

# Deploy All-in-One
az deployment group create \
  --resource-group rg-ai-container-demo \
  --template-file infrastructure/all-in-one-deploy.bicep \
  --parameters azureOpenAIEndpoint="https://seu-openai.openai.azure.com/"
```

---

### Opção 3: PowerShell

```powershell
# Criar Resource Group
az group create --name rg-ai-container-demo --location eastus

# Deploy All-in-One
az deployment group create `
  --resource-group rg-ai-container-demo `
  --template-file infrastructure/all-in-one-deploy.bicep `
  --parameters azureOpenAIEndpoint="https://seu-openai.openai.azure.com/"
```

---

## 📋 Parâmetros Disponíveis

| Parâmetro | Descrição | Padrão |
|-----------|-----------|--------|
| `acrName` | Nome do ACR | `acraicondemo` |
| `containerAppName` | Nome do Container App | `ai-container-app` |
| `functionAppName` | Nome do Functions | `funcappaidessa` |
| `azureOpenAIEndpoint` | **OBRIGATÓRIO** | - |
| `azureOpenAIDeployment` | Deployment do modelo | `gpt-4` |
| `gitRepoUrl` | Repositório Git | `https://github.com/macieljrBiz/ai-container-demo.git` |
| `gitBranch` | Branch do repo | `main` |
| `location` | Região Azure | Resource Group location |

---

## 🔧 Como Funciona

### 1. Deployment Scripts (Recurso Nativo do Bicep)

```bicep
resource buildScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'build-container-images'
  kind: 'AzurePowerShell'
  properties: {
    scriptContent: '''
      # Clone do repositório
      git clone -b $env:GIT_BRANCH $env:GIT_REPO_URL repo
      
      # Build das imagens no ACR
      az acr build --registry $env:ACR_NAME --image "ai-container-app:latest" ...
      az acr build --registry $env:ACR_NAME --image "ai-functions:latest" ...
    '''
  }
}
```

**O que acontece:**
- Azure cria um **Container Instance temporário**
- Executa o script PowerShell **dentro dele**
- Script faz `git clone` do repositório
- Executa `az acr build` para criar as imagens
- Retorna outputs para usar nos próximos recursos
- Container é **deletado automaticamente** após sucesso

### 2. Dependências Automáticas

```bicep
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  properties: {
    template: {
      containers: [
        {
          image: buildScript.properties.outputs.containerAppImage  // ← Usa output do script
        }
      ]
    }
  }
  dependsOn: [
    buildScript  // ← Aguarda build terminar
  ]
}
```

---

## ⚖️ Comparação das Abordagens

### All-in-One Bicep vs Script PowerShell

| Aspecto | All-in-One Bicep | Script PowerShell |
|---------|------------------|-------------------|
| **Comandos necessários** | 1 (`az deployment`) | 1 (`./build-and-deploy.ps1`) |
| **Onde roda** | Container Instance (Azure) | Local ou Cloud Shell |
| **Precisa código local** | ❌ Não (faz git clone) | ✅ Sim |
| **Custo** | ~$0.01 (Container Instance temporário) | Grátis |
| **Tempo** | ~15-20 min | ~5-10 min |
| **Idempotente** | ✅ Sim (Bicep nativo) | ⚠️ Depende de checks |
| **Rollback** | ✅ Automático | ❌ Manual |
| **Deploy incremental** | ✅ Sim | ❌ Não |
| **Portal Azure** | ✅ Suportado | ❌ Não |
| **Melhor para** | **Produção, CI/CD** | **Dev, Cliente final** |

---

## 🎯 Quando Usar Cada Abordagem

### ✅ Use **All-in-One Bicep** quando:
- Deploy via **Azure Portal** (cliente sem CLI)
- Ambiente de **produção**
- **CI/CD pipelines** (GitHub Actions, Azure DevOps)
- Precisa **rastreabilidade completa**
- Quer **rollback automático**
- Deploy a partir de **repositório Git público**

### ✅ Use **Script PowerShell** quando:
- Deploy **local/rápido**
- **Desenvolvimento** e testes
- Cliente já tem **código local**
- Precisa de **flexibilidade** nos passos
- Quer **velocidade** (sem Container Instance)
- **Troubleshooting** de problemas

---

## 🔍 Verificar Progresso

### Durante o Deploy

```bash
# Ver status do deployment
az deployment group show \
  --resource-group rg-ai-container-demo \
  --name all-in-one-deploy \
  --query properties.provisioningState

# Ver logs do Deployment Script
az deployment-scripts show-log \
  --resource-group rg-ai-container-demo \
  --name build-container-images
```

### Após o Deploy

```bash
# Ver outputs
az deployment group show \
  --resource-group rg-ai-container-demo \
  --name all-in-one-deploy \
  --query properties.outputs

# Ver URL do Container App
az containerapp show \
  --name ai-container-app \
  --resource-group rg-ai-container-demo \
  --query properties.configuration.ingress.fqdn -o tsv
```

---

## 💡 Vantagens do All-in-One

### 1. **Verdadeiramente Infrastructure as Code**
```bicep
// TUDO em um arquivo
resource acr {...}           // Infraestrutura
resource buildScript {...}    // Build
resource containerApp {...}   // Aplicação
```

### 2. **Deploy via Portal**
- Cliente clica "Deploy to Azure"
- Preenche formulário
- Aguarda ~15 minutos
- **Pronto!** App rodando

### 3. **Idempotente**
```bash
# Executar múltiplas vezes = mesmo resultado
az deployment group create ...  # 1ª vez: cria tudo
az deployment group create ...  # 2ª vez: sem mudanças
az deployment group create ...  # 3ª vez: sem mudanças
```

### 4. **Rollback Automático**
Se algo falhar durante deploy:
- Azure **reverte** mudanças automaticamente
- Estado anterior **preservado**
- Sem recursos órfãos

---

## 🚨 Limitações

### 1. **Deployment Scripts têm custo mínimo**
- ~$0.01 por execução (Container Instance)
- Desprezível em produção

### 2. **Repositório precisa ser público**
- Ou configurar credenciais Git no script
- Alternativa: usar Azure DevOps Repos

### 3. **Timeout de 30 minutos**
- Build muito grande pode exceder
- Ajustar `timeout: 'PT30M'` se necessário

---

## 🎉 Recomendação Final

### Para Cliente Final:
**Use as DUAS opções!**

1. **`all-in-one-deploy.bicep`**
   - Para deploy via Portal (sem CLI)
   - Para produção (rastreável)

2. **`build-and-deploy.ps1`**
   - Para desenvolvimento rápido
   - Para troubleshooting
   - Para atualizações incrementais

### Estrutura de Entrega:
```
📦 Pacote para Cliente
├── 🚀 OPÇÃO 1: all-in-one-deploy.bicep
│   └─ "Deploy via Portal ou CLI - código vem do GitHub"
│
└── ⚡ OPÇÃO 2: build-and-deploy.ps1
    └─ "Deploy rápido com código local"
```

---

## 📖 Exemplo Completo

```bash
# 1. Criar Resource Group
az group create --name rg-ai-container-demo --location eastus

# 2. Deploy All-in-One
az deployment group create \
  --resource-group rg-ai-container-demo \
  --template-file infrastructure/all-in-one-deploy.bicep \
  --parameters \
    azureOpenAIEndpoint="https://ansiqueira-3288-resource.openai.azure.com/" \
    azureOpenAIDeployment="gpt-4"

# 3. Aguardar ~15-20 minutos ☕

# 4. Ver URLs
az deployment group show \
  --resource-group rg-ai-container-demo \
  --name all-in-one-deploy \
  --query properties.outputs.containerAppUrl.value -o tsv

# 5. Acessar app 🎉
```

---

**✨ Agora você tem a melhor das duas abordagens!**
