// ============================================================================
// Módulo auxiliar para atribuir role em Azure OpenAI cross-resource-group
// ============================================================================

targetScope = 'resourceGroup'

@description('Principal ID do Container App')
param principalId string

@description('Nome do Azure OpenAI account')
param openAiAccountName string

// Referência ao recurso OpenAI existente
resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiAccountName
}

// Role assignment
resource openAiUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openAi.id, principalId, 'CognitiveServicesOpenAIUser')
  scope: openAi
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd') // Cognitive Services OpenAI User
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
