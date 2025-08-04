// https://github.com/Azure/bicep-registry-modules/blob/main/avm/res/service-bus/namespace
targetScope = 'resourceGroup'

param location string
param sbName string
param sbSku string
param sbCapacity int
param sbQueueName string
param tags object

var serviceTags = union(tags, {
  'azd-service-name': 'servicebus'
})

module namespace 'br/public:avm/res/service-bus/namespace:0.15.0' = {
  name: sbName
  params: {
    name: sbName
    location: location
    tags: serviceTags
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
