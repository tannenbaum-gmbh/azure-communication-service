using 'main.bicep'

// Resource names – adjust to match your naming conventions.
// Names must be globally unique within Azure.
param communicationServiceName = 'acs-playground'
param emailServiceName = 'ecs-playground'

// Data location – choose the Azure geography closest to your users.
// Must be identical for both the Communication Service and the Email Service.
param dataLocation = 'Europe'

// Tags applied to all resources.
param tags = {
  environment: 'playground'
  project: 'azure-communication-service'
  managedBy: 'bicep'
}
