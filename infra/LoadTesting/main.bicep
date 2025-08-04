// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/load-test-service/load-test
targetScope = 'resourceGroup'

param location string
param loadtestName string
param tags object

var serviceTags = union(tags, {
  'azd-service-name': 'load-test-service'
})

module loadtest 'br/public:avm/res/load-test-service/load-test:0.4.2' = {
  name: loadtestName
  params: {
    location: location
    tags: serviceTags
    name: loadtestName
  }
}
