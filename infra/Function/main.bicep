// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/web/site 
targetScope = 'resourceGroup'

param rgName string
param location string 

param logAnalyticsName string 
param functionPlanName string 
param functionAppName string 
param storageAccountName string 
param csAccountName string 
param modelName string
param signalRName string
param applicationInsightsName string 
param sbName string
param sbQueueName string

param functionAppRuntime string = 'dotnet-isolated'
param functionAppRuntimeVersion string = '8.0'
param maximumInstanceCount int = 100
param instanceMemoryMB int = 2048
param tags object

var serviceTags = union(tags, {
  'azd-service-name': 'function'
})

// Generate a unique token to be used in naming resources.
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string = 'xyz'
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
// Ensure the container name is all lowercase and only contains valid characters
var deploymentStorageContainerName = toLower(replace('app-package-${take(functionAppName, 32)}-${take(resourceToken, 7)}', '[^a-z0-9-]', ''))

resource csAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: csAccountName
}

resource signalR 'Microsoft.SignalRService/signalR@2024-03-01' existing = {
  name: signalRName
}

resource authRule 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2024-01-01' existing = {
    name: '${sbName}/RootManageSharedAccessKey'
}

module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: '${uniqueString(deployment().name, location)}-loganalytics'
  scope: resourceGroup(rgName)
  params: {
    name: logAnalyticsName
    tags: tags
    location: location
    dataRetention: 30
  }
}

module applicationInsights 'br/public:avm/res/insights/component:0.6.0' = {
  name: '${uniqueString(deployment().name, location)}-appinsights'
  scope: resourceGroup(rgName)
  params: {
    name: applicationInsightsName
    tags: tags
    location: location
    workspaceResourceId: logAnalytics.outputs.resourceId
    disableLocalAuth: false
  }
}

module storage 'br/public:avm/res/storage/storage-account:0.25.0' = {
  name: '${uniqueString(deployment().name, location)}-storage'
  scope: resourceGroup(rgName)
  params: {
    name: storageAccountName
    tags: tags
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // disable for MI authentication 
    dnsEndpointType: 'Standard'
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    blobServices: {
      containers: [{name: deploymentStorageContainerName}]
    }
    tableServices:{}
    queueServices: {}
    minimumTlsVersion: 'TLS1_2'  // Enforcing TLS 1.2 for better security
    location: location
  }
}

module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: '${uniqueString(deployment().name, location)}-appserviceplan'
  scope: resourceGroup(rgName)
  params: {
    name: functionPlanName
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
    reserved: true
    location: location
    zoneRedundant: false
  }
}

module functionApp 'br/public:avm/res/web/site:0.16.0' = {
  name: '${uniqueString(deployment().name, location)}-functionapp'
  scope: resourceGroup(rgName)
  params: {
    tags: serviceTags
    kind: 'functionapp,linux'
    name: functionAppName
    location: location
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.outputs.primaryBlobEndpoint}${deploymentStorageContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: instanceMemoryMB
        alwaysReady: [
          {
            name: 'function:processmessage'
            instanceCount: 1
          }
        ]
      }
      runtime: { 
        name: functionAppRuntime
        version: functionAppRuntimeVersion
      }
    }
    siteConfig: {
      alwaysOn: false
    }
    configs: [{
      name: 'appsettings'
      properties:{
        // Only include required credential settings unconditionally
        AzureWebJobsStorage__credential: 'managedidentity'
        AzureWebJobsStorage__blobServiceUri: 'https://${storage.outputs.name}.blob.${environment().suffixes.storage}'
        AzureWebJobsStorage__queueServiceUri: 'https://${storage.outputs.name}.queue.${environment().suffixes.storage}'
        AzureWebJobsStorage__tableServiceUri: 'https://${storage.outputs.name}.table.${environment().suffixes.storage}'

        // Application Insights settings are always included
        APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.outputs.connectionString
        APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD'
        AzureOpenAIDeployment: modelName
        AzureOpenAIEndpoint: 'https://${location}.api.cognitive.microsoft.com/'
        AzureOpenAIKey: csAccount.listKeys().key1
        AzureSignalRConnectionString: signalR.listKeys().primaryConnectionString
        AzureSignalRHubName: 'groupchathub'
        ServiceBusQueueName: sbQueueName
        ServiceBusConnection: authRule.listKeys().primaryConnectionString
        DelayInSeconds: '0' // Simulate processing delay
        MaxTokens: '100' // Maximum tokens for LLM response
      }
    }]
  }
}

// Role Assignments
module rbacAssignments './rbac.bicep' = {
  name: 'rbacAssignmentsFunction'
  scope: resourceGroup(rgName)
  params: {
    storageAccountName: storage.outputs.name
    appInsightsName: applicationInsights.outputs.name
    managedIdentityPrincipalId: functionApp.outputs.?systemAssignedMIPrincipalId ?? ''
  }
}
