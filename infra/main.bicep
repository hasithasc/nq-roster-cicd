// Student Roster API - all infrastructure for ONE environment, in ONE resource group.
//
// ISOLATION: this template is self-contained. It creates its own Log Analytics workspace,
// its own Application Insights, its own storage account and its own Flex Consumption plan.
// It takes no resource names from any other project and writes nothing outside its own
// resource group. Do not add a parameter that points at an existing workspace, Key Vault,
// Service Bus or Application Insights belonging to another demo segment.
//
// Deployed by .github/workflows/deploy.yml. Do not deploy by hand except for the first
// bootstrap run described in docs/SETUP.md.
targetScope = 'resourceGroup'

@description('Environment this deployment represents. Drives resource names and app settings.')
@allowed(['dev', 'test', 'prod'])
param envShort string

@description('Friendly environment name shown by GET /api/version.')
param environmentName string

@description('Canadian regions only. The college is an Alberta public body; data stays in Canada.')
@allowed(['canadacentral', 'canadaeast'])
param location string = 'canadacentral'

@description('Cost allocation tag. Every resource carries it so a cost view can be grouped by it.')
param costCenter string = 'IT-Integration-Demo'

// ---- the two settings that prove configuration lives outside the build -------------------
@description('Mask learner IDs in API responses (DEMO-1001 -> DEMO-**01). TRUE in production.')
param maskStudentIds bool

@description('Largest roster this environment will return.')
@minValue(1)
@maxValue(2000)
param maxRosterSize int

// ---- stamped by the pipeline, surfaced by GET /api/version --------------------------------
@description('Release version, e.g. 1.0.0. Set by the deployment workflow.')
param appVersion string = '0.0.0-manual'

@description('Git commit SHA being deployed. Set by the deployment workflow.')
param gitCommit string = 'manual'

@description('UTC build timestamp. Set by the deployment workflow.')
param buildUtc string = ''

// ---- scale and cost caps -----------------------------------------------------------------
@description('Scale cap: the most instances this app may run. A cost and blast-radius control.')
@minValue(1)
@maxValue(100)
param maximumInstanceCount int = 5

@allowed([512, 2048])
@description('512 MB is ample for a read-only JSON API and keeps Flex Consumption quota use low.')
param instanceMemoryMB int = 512

@description('Daily ingestion cap on the workspace, in GB. A monitoring cost control.')
param workspaceDailyCapGb int = 1

// ------------------------------------------------------------------------------------------
var suffix = substring(uniqueString(resourceGroup().id), 0, 6)
var appName = 'func-roster-nqcicd-${envShort}-${suffix}'
var storageName = 'stroster${envShort}${suffix}'
var deploymentContainer = 'deploymentpackage'
var tags = {
  costCenter: costCenter
  environment: envShort
  project: 'roster-api-cicd-demo'
  managedBy: 'github-actions'
}
var roles = {
  blobOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  tableContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  queueContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
}

@description('Name of the user-assigned managed identity created in docs/SETUP.md. It must already exist in THIS resource group.')
param identityName string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

// ---------------------------------------------------------------- observability (its own)
resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-roster-nqcicd-${envShort}-${suffix}'
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
    workspaceCapping: { dailyQuotaGb: workspaceDailyCapGb }
  }
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: 'appi-roster-nqcicd-${envShort}-${suffix}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: law.id
    IngestionMode: 'LogAnalytics'
  }
}

// ---------------------------------------------------------------- storage
resource st 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    supportsHttpsTrafficOnly: true
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: st
  name: 'default'
}

resource pkg 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobSvc
  name: deploymentContainer
}

resource raBlob 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: st
  name: guid(st.id, uami.id, roles.blobOwner)
  properties: {
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.blobOwner)
  }
}
resource raTable 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: st
  name: guid(st.id, uami.id, roles.tableContributor)
  properties: {
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.tableContributor)
  }
}
resource raQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: st
  name: guid(st.id, uami.id, roles.queueContributor)
  properties: {
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.queueContributor)
  }
}

// ---------------------------------------------------------------- function app
resource plan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: 'plan-${appName}'
  location: location
  tags: tags
  kind: 'functionapp'
  sku: { name: 'FC1', tier: 'FlexConsumption' }
  properties: { reserved: true }
}

resource site 'Microsoft.Web/sites@2024-04-01' = {
  name: appName
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${uami.id}': {} }
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        { name: 'AzureWebJobsStorage__accountName', value: st.name }
        { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
        { name: 'AzureWebJobsStorage__clientId', value: uami.properties.clientId }
        { name: 'AZURE_CLIENT_ID', value: uami.properties.clientId }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appi.properties.ConnectionString }
        // --- environment-specific configuration: same build, different behaviour ---
        { name: 'ENVIRONMENT_NAME', value: environmentName }
        { name: 'MASK_STUDENT_IDS', value: string(maskStudentIds) }
        { name: 'MAX_ROSTER_SIZE', value: string(maxRosterSize) }
        // --- stamped by the pipeline so GET /api/version cannot lie ---
        { name: 'APP_VERSION', value: appVersion }
        { name: 'GIT_COMMIT', value: gitCommit }
        { name: 'BUILD_UTC', value: buildUtc }
      ]
    }
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${st.properties.primaryEndpoints.blob}${deploymentContainer}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: uami.id
          }
        }
      }
      scaleAndConcurrency: {
        maximumInstanceCount: maximumInstanceCount
        instanceMemoryMB: instanceMemoryMB
      }
      runtime: { name: 'python', version: '3.12' }
    }
  }
  dependsOn: [pkg, raBlob, raTable, raQueue]
}

output functionAppName string = site.name
output functionAppUrl string = 'https://${site.properties.defaultHostName}'
output resourceGroupName string = resourceGroup().name
output appInsightsName string = appi.name
