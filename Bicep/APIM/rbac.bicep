param sbName string
param managedIdentityPrincipalId string // Principal ID for the System-Assigned Managed Identity

// Define Role Definition IDs for Azure built-in roles
var roleDefinitions = {
  sbDataSender: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39' // Azure Service Bus Data Sender
}

resource sbNamespace 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: sbName
}

// Service Bus - Data Sender Role Assignment (System-Assigned Managed Identity)
module sbRoleAssignment 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = if (!empty(managedIdentityPrincipalId)) {
  name: 'sbRoleAssignment-${uniqueString(sbNamespace.id, managedIdentityPrincipalId)}'
  params: {
    resourceId: sbNamespace.id
    roleDefinitionId: roleDefinitions.sbDataSender
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    description: 'Azure Service Bus Data Sender role for APIM system-assigned managed identity'
    roleName: 'Azure Service Bus Data Sender'
  }
}
