// ============================================================================
// CONTAINER APP - Template simplificado
// ============================================================================
// PRÉ-REQUISITOS:
// 1. ACR já existe com a imagem construída
// 2. Variáveis de ambiente (AZURE_OPENAI_*) já configuradas na imagem
// 3. Resource Group já criado
//
// Este template apenas cria o Container App apontando para recursos existentes
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARÂMETROS
// ============================================================================
@description('Nome do Container App a ser criado')
param containerAppName string

@description('Nome do ACR existente (onde a imagem já está)')
param acrName string

@description('Nome completo da imagem (ex: ai-container-app:latest)')
param containerImageName string = 'ai-container-app:latest'

@description('Endpoint do Azure OpenAI (ex: https://seu-modelo.openai.azure.com/)')
param azureOpenAIEndpoint string

@description('Nome do deployment do Azure OpenAI (ex: gpt-4o)')
param azureOpenAIDeployment string = 'gpt-4o'

@description('Resource ID completo do Azure OpenAI para configuração de permissões')
param openAiResourceId string

// ============================================================================
// 1. REFERÊNCIA AO ACR EXISTENTE
// ============================================================================
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' existing = {
  name: acrName
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
// 4. CONTAINER APP – Assume que imagem já existe no ACR
// ============================================================================
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: resourceGroup().location
  identity: { type: 'SystemAssigned' }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
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
        minReplicas: 0
        maxReplicas: 3
      }
    }
  }
}

// ============================================================================
// 5. ROLE ASSIGNMENTS
// ============================================================================

// 5.1. AcrPull - Permitir Container App puxar imagens do ACR
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, containerApp.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: containerApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// 5.2. Cognitive Services OpenAI User - Configura acesso ao Azure OpenAI
module openAiRoleAssignment './openai-role.bicep' = {
  name: '${containerAppName}-openai-role'
  scope: resourceGroup(split(openAiResourceId, '/')[2], split(openAiResourceId, '/')[4])
  params: {
    principalId: containerApp.identity.principalId
    openAiAccountName: last(split(openAiResourceId, '/'))
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================
output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output containerAppFqdn string = containerApp.properties.configuration.ingress.fqdn
