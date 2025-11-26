// ============================================================================
// CONTAINER APP DEPLOYMENT - BUILD COM AZURE CONTAINER INSTANCE
// ============================================================================
// Usa Azure Container Instance ao invés de Deployment Script
// Evita problemas com Storage Account e Azure Policy
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
var managedIdentityName = 'id-build-${containerAppName}'
var aciName = 'aci-build-${uniqueString(resourceGroup().id)}'

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
// 2. MANAGED IDENTITY PARA BUILD
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

// ============================================================================
// 3. AZURE CONTAINER INSTANCE - EXECUTAR BUILD
// ============================================================================

resource buildContainer 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: aciName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityForBuild.id}': {}
    }
  }
  properties: {
    containers: [
      {
        name: 'build-container'
        properties: {
          image: 'mcr.microsoft.com/azure-cli:latest'
          command: [
            '/bin/bash'
            '-c'
            'set -e && echo "==> Instalando Git..." && apk add --no-cache git && echo "==> Fazendo login no ACR usando Managed Identity..." && az login --identity --username ${managedIdentityForBuild.properties.clientId} && az acr login --name ${acrName} && echo "==> Clonando repositório..." && git clone -b ${gitBranch} ${gitRepoUrl} /repo && cd /repo && echo "==> Build Container App Image..." && az acr build --registry ${acrName} --image "ai-container-app:latest" --file "./container-app/Dockerfile" ./container-app && echo "==> Build concluído com sucesso!"'
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: 'Never'
  }
  dependsOn: [
    acrPushRole
  ]
}

// ============================================================================
// 4. LOG ANALYTICS
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
// 5. CONTAINER APPS ENVIRONMENT
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
// 6. MANAGED IDENTITY PARA CONTAINER APP
// ============================================================================

resource managedIdentityForApp 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-${containerAppName}'
  location: location
}

// Permissão para pull de imagens do ACR
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, managedIdentityForApp.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: managedIdentityForApp.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 7. CONTAINER APP
// ============================================================================

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityForApp.id}': {}
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
          identity: managedIdentityForApp.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ai-container-app'
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
    buildContainer
    acrPullRole
  ]
}

// ============================================================================
// OUTPUTS
// ============================================================================

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output acrLoginServer string = acr.properties.loginServer
output containerAppImage string = '${acr.properties.loginServer}/ai-container-app:latest'
output resourceGroupName string = resourceGroup().name
output containerAppName string = containerApp.name
output buildContainerState string = buildContainer.properties.instanceView.state

output nextSteps string = '''
DEPLOY COMPLETO!

✅ ACR criado e imagem foi feita build
✅ Container App deployado

URL da aplicação:
https://${containerApp.properties.configuration.ingress.fqdn}

Para verificar logs do build:
az container logs --name ${aciName} --resource-group ${resourceGroup().name}
'''
