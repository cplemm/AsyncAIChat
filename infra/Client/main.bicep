// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/web/site 
targetScope = 'resourceGroup'

param rgName string
param location string 

param webappPlanName string 
param webappName string
param webappPlanSku string 
param webappPlanCapacity int

param webAppRuntimeVersion string = '9.0'
param apimName string
param signalRName string
param tags object

var serviceTags = union(tags, {
  'azd-service-name': 'client'
})

resource apimService 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource subscription 'Microsoft.ApiManagement/service/subscriptions@2024-06-01-preview' existing = {
  parent: apimService
  name: 'SBSub'
}

resource signalR 'Microsoft.SignalRService/signalR@2024-03-01' existing = {
  name: signalRName
}

module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: '${uniqueString(deployment().name, location)}-appserviceplan'
  scope: resourceGroup(rgName)
  params: {
    name: webappPlanName
    tags: tags
    location: location
    sku: {
      name: webappPlanSku
      capacity: webappPlanCapacity
    }
    zoneRedundant: false
    reserved: false // true for Linux
  }
}

module site 'br/public:avm/res/web/site:0.16.0' = {
  name: '${uniqueString(deployment().name, location)}-webapp'
  scope: resourceGroup(rgName)
  params: {
    tags: serviceTags
    kind: 'app' // Windows
    name: webappName
    serverFarmResourceId: appServicePlan.outputs.resourceId
    configs: [
      {
        name: 'web'
        properties: {
          netFrameworkVersion: webAppRuntimeVersion
          remoteDebuggingVersion: 'VS2022'
          use32BitWorkerProcess: false
          alwaysOn: true
        }
      }
    ]
    siteConfig: {
      appSettings: [
        {
          name: 'AllowedHosts'
          value: '*'
        }
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: 'Production'
        }
        // {
        //   name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
        //   value: 'true'
        // }
        {
          name: 'APIM__Endpoint'
          value: '${apimService.properties.gatewayUrl}/sendtosb'
        }
        {
          name: 'APIM__SubscriptionKey'
          value: subscription.listSecrets().primaryKey
        }
        {
          name: 'Azure__SignalR__ConnectionString'
          value: signalR.listKeys().primaryConnectionString
        }
      ]
    }
  }
}
