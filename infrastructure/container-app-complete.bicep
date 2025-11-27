// ============================================================================
// CONTAINER APP - Template simplificado (PRÉ-BUILD necessário)
// ============================================================================
// IMPORTANTE: Execute ANTES de fazer o deploy:
//   az acr build --registry <ACR_NAME> \
//                --image ai-container-app:latest \
//                --file ./container-app/Dockerfile \
//                ./container-app
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

@description('Nome da imagem do container (ex: ai-container-app:latest)')
param containerImageName string = 'ai-container-app:latest'

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
// 2. LOG ANALYTICS + ENVIRONMENT
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
// 3. CONTAINER APP – Assume que imagem já existe no ACR
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
          image: '${acr.properties.loginServer}/${containerImageName}'
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
}

// ============================================================================
// ROLE ASSIGNMENT - Permitir Container App puxar imagens do ACR
// ============================================================================
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
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
output imageName string = '${acr.properties.loginServer}/ai-container-app:latest'
output buildCommand string = 'az acr build --registry ${acrName} --image ai-container-app:latest --file ./container-app/Dockerfile ./container-app'
