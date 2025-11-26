// ============================================================================
// CONTAINER APP DEPLOYMENT - Build + Deploy com Toggle BuildLocal
// ============================================================================
targetScope = 'resourceGroup'

// ============================================================================
// PARÂMETROS
// ============================================================================
@description('Nome do Azure Container Registry (deve ser único globalmente)')
param acrName string

@description('Nome do Container App')
param containerAppName string = 'ai-container-app'

@description('Endpoint do Azure OpenAI')
param azureOpenAIEndpoint string

@description('Nome do deployment no Azure OpenAI')
param azureOpenAIDeployment string = 'gpt-4'

@description('Location para os recursos')
param location string = resourceGroup().location

@description('URL do repositório Git para build automático')
param gitRepoUrl string = 'https://github.com/macieljrBiz/ai-container-demo.git'

@description('Branch do repositório Git')
param gitBranch string = 'main'

@description('Se TRUE faz build via Deployment Script, senão assume imagem existente')
param buildLocal bool = true

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
    adminUserEnabled: false
  }
}

// ============================================================================
// 2. STORAGE ACCOUNT (somente se buildLocal == true)
// ============================================================================
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = if (buildLocal) {
  name: storageName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowSharedKeyAccess: false
    allowBlobPublicAccess: false
  }
}

// ============================================================================
// 3. MANAGED IDENTITY (somente se buildLocal == true)
// ============================================================================
resource managedIdentityForBuild 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (buildLocal) {
  name: managedIdentityName
  location: location
}

// Permissão push no ACR
resource acrPushRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (buildLocal) {
  name: guid(acr.id, managedIdentityForBuild.id, 'AcrPush')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
    principalId: managedIdentityForBuild.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Permissão Storage Blob Data Owner
resource storageBlobOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (buildLocal) {
  name: guid(storageAccount.id, managedIdentityForBuild.id, 'StorageBlobDataOwner')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b')
    principalId: managedIdentityForBuild.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// 4. DEPLOYMENT SCRIPT (somente se buildLocal == true)
// ============================================================================
resource buildScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (buildLocal) {
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

    // ⛔ SEM ESSA PROPRIEDADE → runtime tenta usar chave e dá erro!
    storageAccountSettings: {
      storageAccountName: storageAccount.name
      authMode: 'login' // <<< ESSENCIAL!
    }

    environmentVariables: [
      { name: 'ACR_NAME'; value: acr.name }
      { name: 'GIT_REPO_URL'; value: gitRepoUrl }
      { name: 'GIT_BRANCH'; value: gitBranch }
    ]
    scriptContent: '''
      az login --identity

      Write-Output "==> Autenticando via Entra ID..."
      $acrToken = az acr login --name $env:ACR_NAME --expose-token --output json | ConvertFrom-Json
      az acr login --name $env:ACR_NAME --username 00000000-0000-0000-0000-000000000000 --password $acrToken.accessToken

      Write-Output "==> Clonando repositório..."
      git clone -b $env:GIT_BRANCH $env:GIT_REPO_URL repo
      cd repo

      Write-Output "==> Build Container App Image..."
      az acr build `
        --registry $env:ACR_NAME `
        --image "ai-container-app:latest" `
        --file "./container-app/Dockerfile" `
        ./container-app

      $DeploymentScriptOutputs = @{
        containerAppImage = "$env:ACR_NAME.azurecr.io/ai-container-app:latest"
      }
    '''
  }
  dependsOn: [
    acrPushRole
    storageBlobOwnerRole
  ]
}

// ============================================================================
// 5. LOG ANALYTICS
// ============================================================================
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ============================================================================
// 6. CONTAINER APP ENVIRONMENT
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
var containerAppImage = buildLocal
  ? buildScript.properties.outputs.containerAppImage
  : '${acr.properties.loginServer}/ai-container-app:latest'

resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: { type: 'SystemAssigned' }
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
        { server: acr.properties.loginServer; identity: 'system' }
      ]
    }
    template: {
      containers: [
        {
          name: 'ai-container-app'
          image: containerAppImage
          resources: { cpu: json('0.5'); memory: '1Gi' }
          env: [
            { name: 'AZURE_OPENAI_ENDPOINT'; value: azureOpenAIEndpoint }
            { name: 'AZURE_OPENAI_DEPLOYMENT'; value: azureOpenAIDeployment }
          ]
        }
      ]
    }
  }
  dependsOn: [
    buildLocal ? buildScript : ''
  ]
}

// ============================================================================
// PERMISSÃO ACR PULL
// ============================================================================
resource containerAppAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, containerApp.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: containerApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================
output url string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output rg string = resourceGroup().name
output image string = containerAppImage
