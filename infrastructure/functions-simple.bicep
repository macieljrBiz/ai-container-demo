// ============================================================================
// AZURE FUNCTIONS DEPLOYMENT - SEM BUILD AUTOMÁTICO
// ============================================================================
// Este template cria a infraestrutura mas NÃO faz build da imagem
// Você precisa fazer o build manualmente usando:
// az acr build --registry <ACR_NAME> --image ai-functions:latest --file ./functions/Dockerfile ./functions
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARÂMETROS
// ============================================================================

@description('Nome do Azure Container Registry')
@minLength(5)
@maxLength(50)
param acrName string

@description('Nome da Function App')
@minLength(2)
@maxLength(60)
param functionAppName string

@description('Nome da Storage Account para Functions')
@minLength(3)
@maxLength(24)
param storageAccountName string = 'stfunc${uniqueString(resourceGroup().id)}'

@description('Location para os recursos')
param location string = 'eastus'

@description('Tag da imagem Docker')
param imageTag string = 'latest'

// ============================================================================
// VARIÁVEIS
// ============================================================================

var appInsightsName = 'ai-${functionAppName}'
var appServicePlanName = 'plan-${functionAppName}'

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
// 2. STORAGE ACCOUNT (para Azure Functions)
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: true
  }
}

// ============================================================================
// 3. LOG ANALYTICS E APPLICATION INSIGHTS
// ============================================================================

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${take(functionAppName, 55)}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ============================================================================
// 4. APP SERVICE PLAN
// ============================================================================

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

// ============================================================================
// 5. FUNCTION APP
// ============================================================================

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux,container'
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${acr.properties.loginServer}/ai-functions:${imageTag}'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${acr.properties.loginServer}'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: acr.listCredentials().username
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: acr.listCredentials().passwords[0].value
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output functionAppName string = functionApp.name
output acrLoginServer string = acr.properties.loginServer
output resourceGroupName string = resourceGroup().name
output acrName string = acr.name

output nextSteps string = '''
PRÓXIMOS PASSOS:

1. Fazer build da imagem no ACR:
   az acr build --registry ${acrName} --image ai-functions:${imageTag} --file ./functions/Dockerfile ./functions

2. Atualizar Function App (se necessário):
   az functionapp config container set --name ${functionAppName} --resource-group ${resourceGroupName} --docker-custom-image-name ${acr.properties.loginServer}/ai-functions:${imageTag}

3. Acessar aplicação:
   https://${functionApp.properties.defaultHostName}
'''
