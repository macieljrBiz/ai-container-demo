// ============================================================================
// CONTAINER APP com build automático via ACR Task (Azure only - sem GitHub Actions)
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARÂMETROS
// ============================================================================
@description('Nome do Container App')
param containerAppName string

@description('Nome do Azure Container Registry (ACR)')
param acrName string

@description('Endpoint do modelo Azure OpenAI (ex: https://xxx.openai.azure.com/)')
param azureOpenAIEndpoint string

@description('Nome do deployment do Azure OpenAI (ex: gpt-4o)')
param azureOpenAIDeployment string = 'gpt-4o'

@description('Repositório Git contendo o Dockerfile')
param gitRepoUrl string = 'https://github.com/macieljrBiz/ai-container-demo.git'

@description('Branch do repositório Git')
param gitBranch string = 'main'

// ============================================================================
// 1. ACR – Registro de container
// ============================================================================
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: resourceGroup().location
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false
  }
}

// ============================================================================
// 2. MANAGED IDENTITY para Deployment Script
// ============================================================================
resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-acr-build-script'
  location: resourceGroup().location
}

// Permissão para executar ACR Tasks
resource acrContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, scriptIdentity.id, 'AcrContributor')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Contributor
    principalId: scriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 3. ACR TASK – build da imagem automaticamente (Azure only - sem GitHub)
// ============================================================================
resource acrTask 'Microsoft.ContainerRegistry/registries/tasks@2023-01-01-preview' = {
  parent: acr
  name: 'buildImage'
  location: resourceGroup().location
  properties: {
    status: 'Enabled'
    agentConfiguration: { cpu: 2 }
    platform: {
      os: 'Linux'
      architecture: 'amd64'
    }
    source: {
      git: {
        repositoryUrl: gitRepoUrl
        branch: gitBranch
      }
    }
    step: {
      type: 'Docker'
      contextPath: 'container-app'          // PASTA dentro do repositório
      dockerFilePath: 'container-app/Dockerfile'
      isPushEnabled: true
      imageNames: [
        'ai-container-app:latest'
      ]
    }
  }
}

// ============================================================================
// 4. RUN ACR TASK – via Deployment Script (executa o build AGORA!)
// ============================================================================
resource runBuild 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'runBuildImage'
  location: resourceGroup().location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.62.0'
    retentionInterval: 'PT1H'
    timeout: 'PT30M'
    environmentVariables: [
      {
        name: 'ACR_NAME'
        value: acrName
      }
    ]
    scriptContent: 'echo "### Iniciando build da imagem no Azure..." && az acr task run --registry $ACR_NAME --name buildImage'
  }
  dependsOn: [
    acrTask
    acrContributorRole
  ]
}

// ============================================================================
// 5. LOG ANALYTICS + ENVIRONMENT
// ============================================================================
var logAnalyticsName = 'log-${containerAppName}'
var containerAppEnvName = 'env-${containerAppName}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: resourceGroup().location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: containerAppEnvName
  location: resourceGroup().location
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
// 6. CONTAINER APP – usa imagem construída pelo ACR Task
// ============================================================================
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: resourceGroup().location
  identity: { type: 'SystemAssigned' }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
        transport: 'auto'
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
          name: 'app'
          image: '${acr.properties.loginServer}/ai-container-app:latest'
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
  dependsOn: [ runBuild ]  // Só cria app depois da imagem construída!
}

// ============================================================================
// OUTPUTS
// ============================================================================
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output acrLoginServer string = acr.properties.loginServer
output imageName string = '${acr.properties.loginServer}/ai-container-app:latest'
output nextSteps string = '''
🚀 Deploy concluído!

Você pode verificar a imagem no ACR com:
az acr repository list --name ${acrName}

Ou listar os logs:
az containerapp logs show --name ${containerAppName} --resource-group ${resourceGroup().name} --follow
'''
