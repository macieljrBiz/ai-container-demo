// ============================================================================
// ALL-IN-ONE DEPLOYMENT - Build + Deploy em um único Bicep
// ============================================================================
// Este template usa Deployment Scripts para fazer build das imagens no ACR
// antes de criar os Container Apps e Functions
// ============================================================================

targetScope = 'resourceGroup'

// ============================================================================
// PARÂMETROS
// ============================================================================

@description('Nome do Azure Container Registry')
param acrName string = 'acraicondemo'

@description('Nome do Container App')
param containerAppName string = 'ai-container-app'

@description('Nome do Azure Functions')
param functionAppName string = 'funcappaidessa'

@description('Endpoint do Azure OpenAI')
param azureOpenAIEndpoint string

@description('Nome do deployment do Azure OpenAI')
param azureOpenAIDeployment string = 'gpt-4'

@description('Location para os recursos')
param location string = resourceGroup().location

@description('URL do repositório Git (para fazer git clone e build)')
param gitRepoUrl string = 'https://github.com/macieljrBiz/ai-container-demo.git'

@description('Branch do repositório Git')
param gitBranch string = 'main'

// ============================================================================
// VARIÁVEIS
// ============================================================================

var logAnalyticsName = 'log-${containerAppName}'
var appInsightsName = 'ai-${functionAppName}'
var containerAppEnvName = 'env-${containerAppName}'
var storageName = 'st${uniqueString(resourceGroup().id)}'
var buildScriptName = 'build-container-images'

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
  }
}

// ============================================================================
// 3. DEPLOYMENT SCRIPT - BUILD DAS IMAGENS NO ACR
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
    azPowerShellVersion: '10.0'
    retentionInterval: 'P1D'
    timeout: 'PT30M'
    cleanupPreference: 'OnSuccess'
    storageAccountSettings: {
      storageAccountName: storageAccount.name
      storageAccountKey: storageAccount.listKeys().keys[0].value
    }
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
      $DeploymentScriptOutputs['containerAppImage'] = "$env:ACR_NAME.azurecr.io/ai-container-app:latest"
      $DeploymentScriptOutputs['functionsImage'] = "$env:ACR_NAME.azurecr.io/ai-functions:latest"
      $DeploymentScriptOutputs['acrLoginServer'] = "$env:ACR_NAME.azurecr.io"
    '''
  }
  dependsOn: [
    acr
    storageAccount
  ]
}

// ============================================================================
// 4. MANAGED IDENTITY PARA DEPLOYMENT SCRIPT
// ============================================================================

resource managedIdentityForBuild 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-build-${containerAppName}'
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
// 6. APPLICATION INSIGHTS
// ============================================================================

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
// 7. CONTAINER APPS ENVIRONMENT
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
// 8. CONTAINER APP
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
// 9. AZURE FUNCTIONS (Plan + App)
// ============================================================================

resource hostingPlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: 'plan-${functionAppName}'
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

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      linuxFxVersion: 'PYTHON|3.11'
      appSettings: [
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
}

// ============================================================================
// OUTPUTS
// ============================================================================

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output functionAppUrl string = 'https://${functionApp.properties.defaultHostName}'
output acrLoginServer string = acr.properties.loginServer
output containerAppImage string = buildScript.properties.outputs.containerAppImage
output functionsImage string = buildScript.properties.outputs.functionsImage

output nextSteps string = '''
✅ Deploy concluído com sucesso!

Imagens criadas:
- Container App: ${buildScript.properties.outputs.containerAppImage}
- Functions: ${buildScript.properties.outputs.functionsImage}

URLs:
- Container App: https://${containerApp.properties.configuration.ingress.fqdn}
- Functions: https://${functionApp.properties.defaultHostName}

Próximos passos:
1. Configurar permissões Azure OpenAI (se necessário):
   az role assignment create --assignee ${containerApp.identity.principalId} --role "Cognitive Services OpenAI User" --scope <OPENAI_RESOURCE_ID>

2. Verificar logs:
   az containerapp logs show --name ${containerAppName} --resource-group ${resourceGroup().name} --follow
'''
