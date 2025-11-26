// ============================================================================
// CONTAINER APP DEPLOYMENT - Build + Deploy
// ============================================================================
// Deploy APENAS do Container App com build automático da imagem
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARÂMETROS
// ============================================================================

@description('Nome do Azure Container Registry (deve ser único globalmente)')
@minLength(5)
@maxLength(50)
param acrName string

@description('Nome do Container App')
@minLength(2)
@maxLength(32)
param containerAppName string = 'ai-container-app'

@description('Endpoint do Azure OpenAI (ex: https://seu-recurso.openai.azure.com/)')
param azureOpenAIEndpoint string

@description('Nome do deployment do modelo no Azure OpenAI')
param azureOpenAIDeployment string = 'gpt-4'

@description('Location para os recursos')
param location string = resourceGroup().location

@description('URL do repositório Git para fazer clone e build')
param gitRepoUrl string = 'https://github.com/macieljrBiz/ai-container-demo.git'

@description('Branch do repositório Git')
param gitBranch string = 'main'

// ============================================================================
// VARIÁVEIS
// ============================================================================

var logAnalyticsName = 'log-${containerAppName}'
var containerAppEnvName = 'env-${containerAppName}'
var storageName = 'st${uniqueString(resourceGroup().id)}'
var buildScriptName = 'build-${containerAppName}'
var managedIdentityName = 'id-build-${containerAppName}'

// ============================================================================
// 1. AZURE CONTAINER REGISTRY
// ============================================================================

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// ============================================================================
// 2. STORAGE ACCOUNT (necessário para Deployment Scripts)
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: false
  }
}

// ============================================================================
// 3. MANAGED IDENTITY PARA DEPLOYMENT SCRIPT
// ============================================================================

resource managedIdentityForBuild 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

// Permissão para fazer push no ACR
resource acrPushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, managedIdentityForBuild.id, 'AcrPush')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec') // AcrPush
    principalId: managedIdentityForBuild.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Permissão para acessar Storage Account
resource storageBlobRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, managedIdentityForBuild.id, 'StorageBlobDataContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: managedIdentityForBuild.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 4. DEPLOYMENT SCRIPT - BUILD DA IMAGEM NO ACR
// ============================================================================

resource buildScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: buildScriptName
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityForBuild.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    retentionInterval: 'PT1H'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    environmentVariables: [
      {
        name: 'ACR_NAME'
        value: acr.name
      }
      {
        name: 'GIT_REPO_URL'
        value: gitRepoUrl
      }
      {
        name: 'GIT_BRANCH'
        value: gitBranch
      }
    ]
    scriptContent: '''
      Write-Output "==> Clonando repositório..."
      git clone -b $env:GIT_BRANCH $env:GIT_REPO_URL repo
      cd repo
      
      Write-Output "==> Fazendo login no ACR..."
      az acr login --name $env:ACR_NAME
      
      Write-Output "==> Build Container App Image..."
      az acr build `
        --registry $env:ACR_NAME `
        --image "ai-container-app:latest" `
        --image "ai-container-app:$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
        --file "./container-app/Dockerfile" `
        ./container-app
      
      if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha no build da imagem Container App"
        exit 1
      }
      
      Write-Output "==> Listando imagens criadas..."
      az acr repository list --name $env:ACR_NAME --output table
      
      Write-Output "==> Build concluído com sucesso!"
      
      # Output para usar em outros recursos
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs['containerAppImage'] = "$env:ACR_NAME.azurecr.io/ai-container-app:latest"
      $DeploymentScriptOutputs['acrLoginServer'] = "$env:ACR_NAME.azurecr.io"
    '''
  }
  dependsOn: [
    acrPushRole
    storageBlobRole
  ]
}

// ============================================================================
// 5. LOG ANALYTICS
// ============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// ============================================================================
// 6. CONTAINER APPS ENVIRONMENT
// ============================================================================

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// ============================================================================
// 7. CONTAINER APP
// ============================================================================

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
        allowInsecure: false
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ai-container-app'
          image: buildScript.properties.outputs.containerAppImage
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: azureOpenAIEndpoint
            }
            {
              name: 'AZURE_OPENAI_DEPLOYMENT'
              value: azureOpenAIDeployment
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
  dependsOn: [
    buildScript
  ]
}

// Permissão ACR Pull para Container App
resource containerAppAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, containerApp.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: containerApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output acrLoginServer string = acr.properties.loginServer
output containerAppImage string = buildScript.properties.outputs.containerAppImage
output resourceGroupName string = resourceGroup().name

output nextSteps string = '''
✅ Container App deployado com sucesso!

Imagem criada:
- ${buildScript.properties.outputs.containerAppImage}

URL do app:
- https://${containerApp.properties.configuration.ingress.fqdn}

Próximos passos:
1. Configurar permissões Azure OpenAI (se necessário):
   az role assignment create \
     --assignee ${containerApp.identity.principalId} \
     --role "Cognitive Services OpenAI User" \
     --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<OPENAI_RG>/providers/Microsoft.CognitiveServices/accounts/<OPENAI_NAME>

2. Verificar logs:
   az containerapp logs show --name ${containerAppName} --resource-group ${resourceGroup().name} --follow

3. Testar aplicação:
   curl https://${containerApp.properties.configuration.ingress.fqdn}
'''
