// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/cognitive-services/account
targetScope = 'resourceGroup'

param location string
param csAccountName string
param modelTPM int
param tags object

var serviceTags = union(tags, {
  'azd-service-name': 'cognitive-services-account'
})

module csAccount 'br/public:avm/res/cognitive-services/account:0.12.0' = {
  name: csAccountName
  params: {
    kind: 'AIServices'
    location: location
    tags: serviceTags
    name: csAccountName
    deployments: [
      {
        model: {
          format: 'OpenAI'
          name: 'gpt-4o'
          version: '2024-11-20'
        }
        name: 'gpt-4o'
        sku: {
          capacity: modelTPM
          name: 'Standard'
        }
      }
    ]
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}
