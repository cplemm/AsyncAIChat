// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/signal-r-service/signal-r
targetScope = 'subscription'

param rgName string
param location string = deployment().location

param signalRName string
param signalRSku string
param signalRCapacity int
param tags object

var serviceTags = union(tags, {
  'azd-service-name': 'signalr'
})

module signalR 'br/public:avm/res/signal-r-service/signal-r:0.10.0' = {
  scope: resourceGroup(rgName)
  name: signalRName
  params: {
    name: signalRName
    location: location
    tags: serviceTags
    sku: signalRSku
    capacity: signalRCapacity
    disableLocalAuth: false
    features: [
      {
        flag: 'ServiceMode'
        value: 'Default'
      }
    ]
  }
}
