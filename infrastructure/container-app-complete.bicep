// ============================================================================
// PUBLIC CONTAINER APP DEPLOYMENT (Build via GitHub Actions)
// ============================================================================
targetScope = 'resourceGroup'

// === PARÂMETROS =============================================================
param containerAppName string = 'ai-container-app'
param acrName string = 'acr${uniqueString(resourceGroup().id)}'
param containerImageName string = 'ai-container-app'

// ============================================================================
// 1. ACR (sem chave, sem admin user)
// ============================================================================
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  location: resourceGroup().location
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false
    anonymousPullEnabled: false
  }
}

// ============================================================================
// 2. LOG ANALYTICS
// ============================================================================
var logAnalyticsName = 'log-${containerAppName}'

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: resourceGroup().location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ============================================================================
// 3. CONTAINER APP ENVIRONMENT
// ============================================================================
var containerAppEnvName = 'env-${containerAppName}'

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
// 4. CONTAINER APP (imagem será feita via GitHub Actions)
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
          name: 'ai-container-app'
          image: '${acr.properties.loginServer}/${containerImageName}:latest'  // CI/CD atualiza isso
          resources: { cpu: json('0.5'); memory: '1Gi' }
        }
      ]
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================
output url string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output rg string = resourceGroup().name
output acrLoginServer string = acr.properties.loginServer
