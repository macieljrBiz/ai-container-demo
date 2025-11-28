// Prerequisites: Run build-identity.ps1 first to create Managed Identity and role assignments

param location string = resourceGroup().location
param acrName string
param containerAppName string
param azureOpenAIName string

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-ai-container'
  location: location
  properties: {
    retentionInDays: 30
  }
}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'env-ai-container'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logWorkspace.properties.customerId
        sharedKey: logWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: { adminUserEnabled: true }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'staihub${uniqueString(resourceGroup().id)}'
  location: location
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: 'kv-aihub-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-aihub-${uniqueString(resourceGroup().id)}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logWorkspace.id
  }
}

resource azureOpenAI 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: azureOpenAIName
  location: location
  kind: 'OpenAI'
  sku: { name: 'S0' }
  properties: {
    publicNetworkAccess: 'Enabled'
    customSubDomainName: azureOpenAIName
  }
}

resource deployModel 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: azureOpenAI
  name: 'gpt-4o-mini'
  sku: {
    name: 'Standard'
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4o-mini'
      version: '2024-07-18'
    }
  }
}

resource aiHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: 'ai-hub-demo'
  location: location
  kind: 'Hub'
  identity: { type: 'SystemAssigned' }
  properties: {
    friendlyName: 'AI Hub Demo'
    description: 'AI Hub para gerenciar projetos e conexões'
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    applicationInsights: appInsights.id
    hbiWorkspace: false
    publicNetworkAccess: 'Enabled'
  }
}

resource aiProject 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: 'ai-project-demo'
  location: location
  kind: 'Project'
  identity: { type: 'SystemAssigned' }
  properties: {
    friendlyName: 'AI Project Demo'
    description: 'Projeto para Container App com OpenAI'
    hubResourceId: aiHub.id
    publicNetworkAccess: 'Enabled'
  }
}

resource openAIConnection 'Microsoft.MachineLearningServices/workspaces/connections@2024-10-01' = {
  parent: aiProject
  name: 'aoai-connection'
  properties: {
    category: 'AzureOpenAI'
    target: azureOpenAI.properties.endpoint
    authType: 'AAD'
    isSharedToAll: true
    metadata: {
      ApiVersion: '2024-02-01'
      ApiType: 'azure'
      ResourceId: azureOpenAI.id
    }
  }
}

// Foundry Online Endpoint removed - Container App accesses Azure OpenAI directly

resource containerAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: 'id-${containerAppName}'
}

// Role Assignment: Container App Identity → Azure OpenAI
resource roleAssignmentOpenAI 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerAppIdentity.id, azureOpenAI.id, 'Cognitive Services OpenAI User')
  scope: azureOpenAI
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') // Cognitive Services OpenAI User
    principalId: containerAppIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment: Container App Identity → ACR
resource roleAssignmentACR 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerAppIdentity.id, acr.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: containerAppIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerAppIdentity.id}': {}
    }
  }
  dependsOn: [
    roleAssignmentOpenAI
    roleAssignmentACR
  ]
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8000
      }
      registries: [
        {
          server: acr.properties.loginServer
          identity: containerAppIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: containerAppName
          image: 'mcr.microsoft.com/k8se/quickstart:latest'
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output containerAppUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'
output acrLoginServer string = acr.properties.loginServer
output azureOpenAIEndpoint string = azureOpenAI.properties.endpoint
output azureOpenAIDeployment string = deployModel.name
output aiFoundryPortalUrl string = 'https://ai.azure.com/resource/${aiProject.id}'
output foundryDeploymentEndpoint string = foundryDeployment.properties.scoringUri
