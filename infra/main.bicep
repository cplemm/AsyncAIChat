targetScope = 'subscription'

param environmentName string
param location string
param rgName string

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, environmentName, location)

var tags = {
  'azd-env-name': environmentName
}

/////////////////
// APIM
/////////////////
param apimName string = ''
param apimSku string

/////////////////
// SignalR
/////////////////
param signalRName string = ''
param signalRSku string
param signalRCapacity int

/////////////////
// Azure OpenAI
/////////////////
param csAccountName string = ''
param modelTPM int

/////////////////
// Service Bus
/////////////////
param sbName string = ''
param sbSku string
param sbCapacity int
param sbQueueName string

/////////////////
// Function App
/////////////////
param functionAppName string = ''
param logAnalyticsName string = ''
param applicationInsightsName string = ''
param functionPlanName string = ''
param storageAccountName string = ''

/////////////////
// Web App
/////////////////
param webappName string = ''
param webappPlanName string = ''
param webappPlanSku string 
param webappPlanCapacity int

/////////////////
// Load Testing
/////////////////
param loadtestName string = ''

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
  tags: tags
}

var csAccountNameRedacted = !empty(csAccountName) ? csAccountName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
module openaiModule './OpenAI/main.bicep' = {
  name: 'deploy-OpenAI'
  scope: rg
  params: {
    location: location
    csAccountName: csAccountNameRedacted
    modelTPM: modelTPM
    tags: tags
  }
}

var signalRNameRedacted = !empty(signalRName) ? signalRName : '${abbrs.signalRServiceSignalR}${resourceToken}'
module signalRModule './SignalR/main.bicep' = {
  name: 'deploy-SignalR'
  scope: subscription()
  params: {
    rgName: rgName
    location: location
    signalRName: signalRNameRedacted
    signalRSku: signalRSku
    signalRCapacity: signalRCapacity
    tags: tags
  }
}

var sbNameRedacted = !empty(sbName) ? sbName : '${abbrs.serviceBusNamespaces}${resourceToken}'
module sbModule './ServiceBus/main.bicep' = {
  name: 'deploy-ServiceBus'
  scope: rg
  params: {
    location: location
    sbName: sbNameRedacted
    sbSku: sbSku
    sbCapacity: sbCapacity
    sbQueueName: sbQueueName
    tags: tags
  }
}

var apimNameRedacted = !empty(apimName) ? apimName : '${abbrs.apiManagementService}${resourceToken}'
module apimModule './APIM/main.bicep' = {
  name: 'deploy-APIM'
  scope: rg
  dependsOn: [
    sbModule
  ]
  params: {
    location: location
    apimName: apimNameRedacted
    apimSku: apimSku
    sbName: sbNameRedacted
    tags: tags
  }
}

module functionModule './Function/main.bicep' = {
  name: 'deploy-Function'
  scope: rg
  dependsOn: [
    sbModule
    openaiModule
    signalRModule
  ]
  params: {
    location: location
    rgName: rgName
    functionAppName: !empty(functionAppName) ? functionAppName : '${abbrs.webSitesFunctions}${resourceToken}'
    functionPlanName: !empty(functionPlanName) ? functionPlanName : 'func${abbrs.webServerFarms}${resourceToken}'
    sbName: sbNameRedacted
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.appInsights}${resourceToken}'
    csAccountName: csAccountNameRedacted
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    sbQueueName: sbQueueName
    signalRName: signalRNameRedacted
    storageAccountName: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    tags: tags
  }
}

module clientModule './Client/main.bicep' = {
  name: 'deploy-WebApp'
  scope: rg
  dependsOn: [
    apimModule
    signalRModule
  ]
  params: {
    location: location
    rgName: rgName
    webappName: !empty(webappName) ? webappName : '${abbrs.webSitesAppService}${resourceToken}'
    webappPlanName: !empty(webappPlanName) ? webappPlanName : 'web${abbrs.webServerFarms}${resourceToken}'
    signalRName: signalRNameRedacted
    apimName: apimNameRedacted
    webappPlanCapacity: webappPlanCapacity
    webappPlanSku: webappPlanSku
    tags: tags
  }
}

module loadtestModule './LoadTesting/main.bicep' = {
  name: 'deploy-LoadTesting'
  scope: rg
  params: {
    location: location
    loadtestName: !empty(loadtestName) ? loadtestName : 'lt-${resourceToken}'
    tags: tags
  }
}
