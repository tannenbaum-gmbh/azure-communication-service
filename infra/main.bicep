metadata name = 'Azure Communication Service with Email'
metadata description = '''
Deploys an Azure Communication Service together with an Email Communication Service
and an Azure Managed Domain. The email domain is automatically linked to the
Communication Service so that emails can be sent immediately after deployment.

References the Azure Verified Modules (AVM) pattern and follows AVM conventions
for parameters, outputs, and resource structuring.
'''

targetScope = 'resourceGroup'

// ============ //
// Parameters   //
// ============ //

@description('The name of the Azure Communication Service resource.')
@minLength(1)
@maxLength(63)
param communicationServiceName string

@description('The name of the Email Communication Service resource.')
@minLength(1)
@maxLength(63)
param emailServiceName string

@description('''
The data location used to store data at rest for both the Communication Service
and Email Communication Service. Must be the same for both resources.
''')
@allowed([
  'Africa'
  'Asia Pacific'
  'Australia'
  'Brazil'
  'Canada'
  'Europe'
  'France'
  'Germany'
  'India'
  'Japan'
  'Korea'
  'Norway'
  'Switzerland'
  'UAE'
  'UK'
  'UnitedStates'
])
param dataLocation string = 'Europe'

@description('Tags to apply to all deployed resources.')
param tags object = {}

// ============ //
// Resources    //
// ============ //

// Email Communication Service
// Required to enable email sending via Azure Communication Service.
resource emailService 'Microsoft.Communication/emailServices@2023-04-01' = {
  name: emailServiceName
  location: 'global'
  tags: tags
  properties: {
    dataLocation: dataLocation
  }
}

// Azure Managed Domain
// Provides a pre-verified domain (<emailServiceName>.azurecomm.net) so emails
// can be sent without any custom DNS setup.
resource emailServiceDomain 'Microsoft.Communication/emailServices/domains@2023-04-01' = {
  parent: emailService
  name: 'AzureManagedDomain'
  location: 'global'
  tags: tags
  properties: {
    domainManagement: 'AzureManaged'
    userEngagementTracking: 'Disabled'
  }
}

// Azure Communication Service
// Core resource that exposes SDKs and connection strings for chat, SMS,
// voice, and email. Linked to the email domain above.
resource communicationService 'Microsoft.Communication/communicationServices@2023-04-01' = {
  name: communicationServiceName
  location: 'global'
  tags: tags
  properties: {
    dataLocation: dataLocation
    linkedDomains: [
      emailServiceDomain.id
    ]
  }
}

// =========== //
// Outputs     //
// =========== //

@description('The name of the deployed Azure Communication Service.')
output communicationServiceName string = communicationService.name

@description('The resource ID of the Azure Communication Service.')
output communicationServiceResourceId string = communicationService.id

@description('The name of the deployed Email Communication Service.')
output emailServiceName string = emailService.name

@description('The resource ID of the Email Communication Service.')
output emailServiceResourceId string = emailService.id

@description('The resource ID of the Email Communication Service Domain.')
output emailServiceDomainResourceId string = emailServiceDomain.id

@description('''
The sender domain for the Azure Managed Domain.
Use this value to construct sender addresses, e.g. DoNotReply@<senderDomain>.
''')
output senderDomain string = '${emailServiceName}.azurecomm.net'
