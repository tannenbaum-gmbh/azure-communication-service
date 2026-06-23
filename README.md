# azure-communication-service

Playground to understand Azure Communication Service – including infrastructure deployment, email sending, and CI/CD integration using OpenID Connect (OIDC) for passwordless authentication.

## Overview

This repository contains:

| Path | Purpose |
|------|---------|
| `infra/main.bicep` | Bicep template (AVM-style) deploying Azure Communication Service + Email Communication Service + Azure Managed Domain |
| `infra/main.bicepparam` | Default parameter values |
| `infra/bicepconfig.json` | Bicep configuration (linting rules, AVM registry alias) |
| `.github/workflows/deploy.yml` | GitHub Actions – deploy infrastructure via OIDC |
| `.github/workflows/destroy.yml` | GitHub Actions – delete infrastructure via OIDC |
| `.github/workflows/send-test-email.yml` | GitHub Actions – send a test email via OIDC |
| `azure-pipelines/send-test-email.yml` | Azure Pipeline – send a test email via OIDC (Workload Identity Federation) |

## Architecture

```
Azure Resource Group
├── Email Communication Service  (emailServiceName)
│   └── AzureManagedDomain       – pre-verified domain: <emailServiceName>.azurecomm.net
└── Communication Service        (communicationServiceName)
    └── linkedDomains → AzureManagedDomain
```

The **Email Communication Service** and its **Azure Managed Domain** are prerequisites for sending emails. The managed domain provides a pre-verified `@<emailServiceName>.azurecomm.net` address so you can start sending immediately without custom DNS setup.

## Prerequisites

### Azure

1. An Azure subscription with the `Microsoft.Communication` resource provider registered:
   ```bash
   az provider register --namespace Microsoft.Communication
   ```

2. A resource group (created automatically by the deploy workflow).

### OIDC Setup (GitHub Actions)

To authenticate without long-lived secrets, create a **federated credential** on an Entra ID app registration:

1. **Create an app registration** in [Entra ID](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/RegisteredApps).

2. **Add a federated credential** (Settings → Certificates & secrets → Federated credentials):
   - Scenario: *GitHub Actions deploying Azure resources*
   - Organization: `tannenbaum-gmbh`
   - Repository: `azure-communication-service`
   - Entity type: `Branch` → `main` (or `Environment`, `Pull request` as needed)

3. **Assign RBAC roles** on the target subscription or resource group:
   - `Contributor` – to create/delete resources
   - `User Access Administrator` *(optional)* – only if role assignments are needed

4. **Add repository secrets** (Settings → Secrets and variables → Actions):

   | Secret | Value |
   |--------|-------|
   | `AZURE_CLIENT_ID` | Application (client) ID of the app registration |
   | `AZURE_TENANT_ID` | Azure AD / Entra ID tenant ID |
   | `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |

### OIDC Setup (Azure Pipelines)

Create a service connection using **Workload Identity Federation**:

1. In Azure DevOps go to **Project Settings → Service connections → New service connection → Azure Resource Manager**.
2. Select **Workload Identity federation (automatic)** and follow the wizard.
3. Note the service connection name and set it as the pipeline variable `AZURE_SERVICE_CONNECTION`.

## Infrastructure

### Deploy

```bash
# Using Azure CLI directly
az group create --name rg-acs-playground --location westeurope

az deployment group create \
  --name acs-deployment \
  --resource-group rg-acs-playground \
  --template-file infra/main.bicep \
  --parameters infra/main.bicepparam
```

Or trigger the **Deploy Azure Communication Service** GitHub Actions workflow from the Actions tab.
When workflow name overrides are left blank, it derives deterministic defaults by appending a 6-letter hash-based suffix from the subscription ID (for example, `acs-playground-abcdef` and `ecs-playground-abcdef`). Use these same names when running other workflows (e.g., **Send Test Email**), or copy them from the deploy workflow outputs.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `communicationServiceName` | string | `acs-playground` | Name of the Azure Communication Service |
| `emailServiceName` | string | `ecs-playground` | Name of the Email Communication Service |
| `dataLocation` | string | `Europe` | Data-at-rest location (must match for both services) |
| `tags` | object | `{}` | Tags applied to all resources |

### Outputs

| Output | Description |
|--------|-------------|
| `communicationServiceName` | Resource name of the Communication Service |
| `communicationServiceResourceId` | Resource ID of the Communication Service |
| `emailServiceName` | Resource name of the Email Communication Service |
| `emailServiceResourceId` | Resource ID of the Email Communication Service |
| `emailServiceDomainResourceId` | Resource ID of the Azure Managed Domain |
| `senderDomain` | Domain for constructing sender addresses (`<emailServiceName>.azurecomm.net`) |

### Destroy

Trigger the **Destroy Azure Communication Service** GitHub Actions workflow (type `delete` in the confirmation input).

## Sending a Test Email

### Via GitHub Actions

1. Go to **Actions → Send Test Email → Run workflow**.
2. Fill in:
   - **Resource group** – e.g. `rg-acs-playground`
   - **Communication Service name** – e.g. `acs-playground`
   - **Sender address** – e.g. `DoNotReply@ecs-playground.azurecomm.net`
   - **Recipient email** – your email address

### Via Azure Pipeline

1. Open the pipeline file at `azure-pipelines/send-test-email.yml` in Azure DevOps.
2. Set the pipeline variable `AZURE_SERVICE_CONNECTION` to your service connection name.
3. Run the pipeline and fill in the parameters.

### Via Azure CLI

```bash
# Install the extension (first time only)
az extension add --name communication

# Get the connection string
CONNECTION_STRING=$(az communication list-key \
  --name acs-playground \
  --resource-group rg-acs-playground \
  --query primaryConnectionString -o tsv)

# Send the email
az communication email send \
  --connection-string "$CONNECTION_STRING" \
  --sender "DoNotReply@ecs-playground.azurecomm.net" \
  --to "recipient@example.com" \
  --subject "Test Email" \
  --text "Hello from Azure Communication Service!"
```

## Notes

- **Azure Managed Domain** sender addresses follow the pattern `DoNotReply@<emailServiceName>.azurecomm.net`. To use a custom domain, update `emailServiceDomain` in `infra/main.bicep` to use `domainManagement: 'CustomerManaged'` and complete the DNS verification steps in the Azure portal.
- Both the Communication Service and Email Service **must use the same `dataLocation`**.
- The `location` property for Communication resources is always `global`; `dataLocation` determines where data is stored at rest.
- Telemetry/tracking is disabled (`userEngagementTracking: 'Disabled'`) by default and can be enabled in `infra/main.bicep` if needed.
