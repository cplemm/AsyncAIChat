targetScope = 'subscription'

param rgName string
param location string
param sbName string

/////////////////
// APIM
/////////////////
param apimName string
param apimSku string

/////////////////
// SignalR
/////////////////
param signalRName string
param signalRSku string
param signalRCapacity int

/////////////////
// Azure OpenAI
/////////////////
param csName string
param modelTPM int

/////////////////
// Service Bus
/////////////////
param sbSku string
param sbCapacity int
param sbQueueName string

// submodules
module apimModule 'APIM/main.bicep' = {
  name: 'deploy-APIM'
  scope: resourceGroup(rgName)
  params: {
    location: location
    apimName: apimName
    apimSku: apimSku
    sbName: sbName
  }
}

module openaiModule 'OpenAI/main.bicep' = {
  name: 'deploy-OpenAI'
  scope: resourceGroup(rgName)
  params: {
    location: location
    csName: csName
    modelTPM: modelTPM
  }
}

module sbModule 'ServiceBus/main.bicep' = {
  name: 'deploy-ServiceBus'
  scope: resourceGroup(rgName)
  params: {
    location: location
    sbName: sbName
    sbSku: sbSku
    sbCapacity: sbCapacity
    sbQueueName: sbQueueName
  apimPrincipalId: apimModule.outputs.principalId
  }
}

module signalRModule 'SignalR/main.bicep' = {
  name: 'deploy-SignalR'
  scope: subscription()
  params: {
    rgName: rgName
    location: location
    signalRName: signalRName
    signalRSku: signalRSku
    signalRCapacity: signalRCapacity
  }
}

