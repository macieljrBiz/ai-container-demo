// ============================================================================
// CONTAINER APP DEPLOYMENT - SEM BUILD AUTOMÁTICO
// ============================================================================
// Este template cria a infraestrutura mas NÃO faz build da imagem
// Você precisa fazer o build manualmente usando:
// az acr build --registry <ACR_NAME> --image ai-container-app:latest --file ./container-app/Dockerfile ./container-app
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

@description('Tag da imagem Docker (ex: latest, v1.0.0)')
param imageTag string = 'latest'

// ============================================================================
// VARIÁVEIS
// ============================================================================

var logAnalyticsName = 'log-${containerAppName}'
var containerAppEnvName = 'env-${containerAppName}'
var managedIdentityName = 'id-${containerAppName}'

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
    adminUserEnabled: false
  }
}

// ============================================================================
// 2. LOG ANALYTICS
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
// 3. CONTAINER APPS ENVIRONMENT
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
// 4. MANAGED IDENTITY
// ============================================================================

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: managedIdentityName
  location: location
}

// Permissão para pull de imagens do ACR
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, managedIdentity.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 5. CONTAINER APP
// ============================================================================

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
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
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ai-container-app'
          image: '${acr.properties.loginServer}/ai-container-app:${imageTag}'
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
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    acrPullRole
  ]
}

// ============================================================================
// OUTPUTS
// ============================================================================

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output acrLoginServer string = acr.properties.loginServer
output containerAppName string = containerApp.name
output resourceGroupName string = resourceGroup().name
output acrName string = acr.name

output nextSteps string = '''
PRÓXIMOS PASSOS:

1. Fazer build da imagem no ACR:
   az acr build --registry ${acrName} --image ai-container-app:${imageTag} --file ./container-app/Dockerfile ./container-app

2. Atualizar Container App (se necessário):
   az containerapp update --name ${containerAppName} --resource-group ${resourceGroupName} --image ${acr.properties.loginServer}/ai-container-app:${imageTag}

3. Acessar aplicação:
   https://${containerApp.properties.configuration.ingress.fqdn}
'''
