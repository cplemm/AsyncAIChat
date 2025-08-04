// https://github.com/Azure/bicep-registry-modules/tree/main/avm/res/api-management/service
targetScope = 'resourceGroup'

param location string
param apimName string
param apimSku string
param sbName string
param tags object

var serviceTags = union(tags, {
  'azd-service-name': 'apim'
})

module apimService 'br/public:avm/res/api-management/service:0.9.1' = {
  name: apimName
  params: {
    name: apimName
    location: location
    tags: serviceTags
    publisherEmail: 'someone@hotmail.com'
    publisherName: apimName
    sku: apimSku
    managedIdentities: {
      systemAssigned: true
    }
    virtualNetworkType: 'None'
    apis: [
      {
        displayName: 'SendToSB'
        name: 'sendtosb'
        path: 'sendtosb'
        protocols: [
          'https'
        ]
      }
    ]
    namedValues: [
      {
        displayName: 'queue'
        name: 'queue'
        value: 'prompt'
        secret: false
      }
      {
        displayName: 'serviceBusNamespace'
        name: 'serviceBusNamespace'
        value: sbName
        secret: false
      }
    ]
  }
}

// note: currently, there is no AVM support for some APIM sub-components
resource product 'Microsoft.ApiManagement/service/products@2024-05-01' = {
  name: '${apimName}/SB'
  dependsOn: [
    apimService
  ]
  properties: {
    displayName: 'SB'
    description: 'Product for Service Bus API'
    approvalRequired: true
    subscriptionRequired: true
  }
}

resource subscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  name: '${apimName}/SBSub'
  properties: {
    displayName: 'SB subscription'
    scope: '/products/${product.id}'
  }
}

resource sendOperation 'Microsoft.ApiManagement/service/apis/operations@2024-05-01' = {
  name: '${apimName}/sendtosb/send'
  dependsOn: [
    apimService
  ]
  properties: {
    displayName: 'Send'
    method: 'POST'
    urlTemplate: '/'
    request: {
      queryParameters: []
      headers: []
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
    responses: [
      {
        statusCode: 200
        description: 'Success'
        representations: [
          {
            contentType: 'application/json'
          }
        ]
      }
    ]
  }
}

resource sendPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2024-05-01' = {
  parent: sendOperation
  name: 'policy'
  properties: {
    format: 'xml'
    value: '<policies>\n  <inbound>\n    <cors>\n    <allowed-origins>\n    <origin>*</origin>\n    </allowed-origins>\n    <allowed-methods>\n    <method>POST</method>\n    </allowed-methods>\n    <allowed-headers>\n    <header>*</header>\n    </allowed-headers>\n    </cors>\n    <base />\n    <authentication-managed-identity resource="https://servicebus.azure.net" output-token-variable-name="msi-access-token" ignore-error="false" />\n    <set-header name="Authorization" exists-action="override">\n      <value>@((string)context.Variables["msi-access-token"])</value>\n    </set-header>\n    <set-body>@(context.Request.Body.As&lt;string&gt;())</set-body>\n    <set-backend-service base-url="https://{{serviceBusNamespace}}.servicebus.windows.net/{{queue}}/messages?api-version=2015-01" />\n  </inbound>\n  <backend>\n    <base />\n  </backend>\n  <outbound>\n    <base />\n  </outbound>\n  <on-error>\n    <base />\n  </on-error>\n</policies>'
  }
}

// Role Assignments
module rbacAssignments './rbac.bicep' = {
  name: 'rbacAssignmentsAPIM'
  params: {
    sbName: sbName
    managedIdentityPrincipalId: apimService.outputs.?systemAssignedMIPrincipalId ?? ''
  }
}
