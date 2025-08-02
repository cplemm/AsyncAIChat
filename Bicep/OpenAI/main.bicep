// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/cognitive-services/account
targetScope = 'resourceGroup'

param location string
param csName string
param modelTPM int

module account 'br/public:avm/res/cognitive-services/account:0.12.0' = {
  name: csName
  params: {
    kind: 'AIServices'
    location: location
    name: csName
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
  }
}
