// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/web/site 
targetScope = 'resourceGroup'

param rgName string
param location string 

param logAnalyticsName string 
param functionPlanName string 
param functionPlanSkuName string
param functionAppName string 
param storageAccountName string 
param csAccountName string 
param modelName string
param signalRName string
param applicationInsightsName string 
param sbName string
param sbQueueName string

// param functionAppRuntime string = 'dotnet-isolated'
// param functionAppRuntimeVersion string = '8.0'
// param maximumInstanceCount int = 100
// param instanceMemoryMB int = 2048
param tags object

var serviceTags = union(tags, {
  'azd-service-name': 'function'
})

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

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: '${uniqueString(deployment().name, location)}-appserviceplan2'
  scope: resourceGroup(rgName)
  params: {
    name: functionPlanName
    tags: tags
    kind: 'Elastic'
    sku: {
      name: functionPlanSkuName
      tier: 'ElasticPremium'
    }
    reserved: false
    maximumElasticWorkerCount: 20
    location: location
    zoneRedundant: false
  }
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${storageAccount.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
module functionApp 'br/public:avm/res/web/site:0.16.0' = {
  name: '${uniqueString(deployment().name, location)}-functionapp3'
  scope: resourceGroup(rgName)
  params: {
    tags: serviceTags
    kind: 'functionapp'
    name: functionAppName
    location: location
    serverFarmResourceId: appServicePlan.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
    siteConfig: {
      alwaysOn: false
      minimumElasticInstanceCount: 1
    }
    configs: [{
      name: 'appsettings'
      properties:{
        AzureWebJobsStorage: storageConnectionString
        WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: storageConnectionString
        WEBSITE_CONTENTSHARE: toLower(functionAppName)

        // Application Insights settings are always included
        APPLICATIONINSIGHTS_CONNECTION_STRING: applicationInsights.outputs.connectionString
        APPLICATIONINSIGHTS_AUTHENTICATION_STRING: 'Authorization=AAD'
        FUNCTIONS_EXTENSION_VERSION: '~4'
        FUNCTIONS_WORKER_RUNTIME: 'dotnet-isolated'
        FUNCTIONS_WORKER_RUNTIME_VERSION: '~8'
        AzureOpenAIDeployment: modelName
        AzureOpenAIEndpoint: 'https://${location}.api.cognitive.microsoft.com/'
        AzureOpenAIKey: csAccount.listKeys().key1
        AzureSignalRConnectionString: signalR.listKeys().primaryConnectionString
        AzureSignalRHubName: 'groupchathub'
        ServiceBusQueueName: sbQueueName
        ServiceBusConnection: authRule.listKeys().primaryConnectionString
        DelayInSeconds: '10' // Simulate processing delay
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
    storageAccountName: storageAccountName
    appInsightsName: applicationInsights.outputs.name
    managedIdentityPrincipalId: functionApp.outputs.?systemAssignedMIPrincipalId ?? ''
  }
}
