// ============================================================================
// AZURE FUNCTIONS DEPLOYMENT - Build + Deploy
// ============================================================================
// Deploy APENAS do Azure Functions com build automático da imagem
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARÂMETROS
// ============================================================================

@description('Nome do Azure Container Registry (deve ser único globalmente)')
@minLength(5)
@maxLength(50)
param acrName string

@description('Nome do Azure Functions (deve ser único globalmente)')
@minLength(2)
@maxLength(60)
param functionAppName string

@description('Location para os recursos')
param location string = resourceGroup().location

@description('URL do repositório Git para fazer clone e build')
param gitRepoUrl string = 'https://github.com/macieljrBiz/ai-container-demo.git'

@description('Branch do repositório Git')
param gitBranch string = 'main'

// ============================================================================
// VARIÁVEIS
// ============================================================================

var appInsightsName = 'ai-${functionAppName}'
var storageName = 'st${uniqueString(resourceGroup().id)}'
var buildScriptName = 'build-${functionAppName}'
var managedIdentityName = 'id-build-${functionAppName}'
var hostingPlanName = 'plan-${functionAppName}'

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
// 4. MANAGED IDENTITY PARA DEPLOYMENT SCRIPT
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
// 5. DEPLOYMENT SCRIPT - BUILD DA IMAGEM NO ACR
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
    retentionInterval: 'P1D'
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
      
      Write-Output "==> Build Azure Functions Image..."
      az acr build `
        --registry $env:ACR_NAME `
        --image "ai-functions:latest" `
        --image "ai-functions:$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
        --file "./azure-functions/Dockerfile" `
        ./azure-functions
      
      if ($LASTEXITCODE -ne 0) {
        Write-Error "Falha no build da imagem Azure Functions"
        exit 1
      }
      
      Write-Output "==> Listando imagens criadas..."
      az acr repository list --name $env:ACR_NAME --output table
      
      Write-Output "==> Build concluído com sucesso!"
      
      # Output para usar em outros recursos
      $DeploymentScriptOutputs = @{}
      $DeploymentScriptOutputs['functionsImage'] = "$env:ACR_NAME.azurecr.io/ai-functions:latest"
      $DeploymentScriptOutputs['acrLoginServer'] = "$env:ACR_NAME.azurecr.io"
    '''
  }
  dependsOn: [
    acrPushRole
  ]
}

// ============================================================================
// 6. HOSTING PLAN (Consumption Plan Linux)
// ============================================================================

resource hostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: hostingPlanName
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
// 7. FUNCTION APP
// ============================================================================

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux,container'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${buildScript.properties.outputs.functionsImage}'
      appSettings: [
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
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
      ]
    }
  }
  dependsOn: [
    buildScript
  ]
}

// Permissão ACR Pull para Function App
resource functionAppAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, functionApp.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output acrLoginServer string = acr.properties.loginServer
output functionsImage string = buildScript.properties.outputs.functionsImage
output resourceGroupName string = resourceGroup().name

output nextSteps string = '''
✅ Azure Functions deployado com sucesso!

Imagem criada:
- ${buildScript.properties.outputs.functionsImage}

URL do app:
- https://${functionApp.properties.defaultHostName}

Próximos passos:
1. Fazer deploy do código das functions:
   func azure functionapp publish ${functionAppName}

2. Verificar logs:
   az functionapp log tail --name ${functionAppName} --resource-group ${resourceGroup().name}

3. Listar functions:
   az functionapp function list --name ${functionAppName} --resource-group ${resourceGroup().name}

4. Testar function:
   curl https://${functionApp.properties.defaultHostName}/api/<function-name>
'''
