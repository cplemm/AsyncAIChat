// https://github.com/Azure/bicep-registry-modules/blob/main/avm/res/service-bus/namespace
targetScope = 'resourceGroup'

param location string
param sbName string
param sbSku string
param sbCapacity int
param sbQueueName string

@description('The principalId of the APIM managed identity to grant Service Bus Data Sender role')
param apimPrincipalId string = ''

module namespace 'br/public:avm/res/service-bus/namespace:0.15.0' = {
  name: sbName
  params: {
    name: sbName
    location: location
    disableLocalAuth: false
    skuObject: {
      capacity: sbCapacity
      name: sbSku
    }
    queues: [
      {
        authorizationRules: [
          {
            name: 'RootManageSharedAccessKey'
            rights: [
              'Listen'
              'Manage'
              'Send'
            ]
          }
        ]
        name: sbQueueName
      }
    ]
  }
}

// Assign 'Azure Service Bus Data Sender' role to APIM managed identity if principalId is provided
resource sbNamespace 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' existing = {
  name: sbName
}

resource apimToSbRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(apimPrincipalId)) {
  name: guid(resourceGroup().id, sbName, apimPrincipalId, 'AzureServiceBusDataSender')
  scope: sbNamespace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39')
    principalId: apimPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Output the Service Bus namespace resourceId
output namespaceResourceId string = namespace.outputs.resourceId
