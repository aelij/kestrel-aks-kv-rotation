[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  $ResourceGroup,
  [Parameter(Mandatory = $true)]
  $Location,
  [Parameter(Mandatory = $true)]
  $ClusterName,
  [Parameter(Mandatory = $true)]
  $VaultName,
  [Parameter(Mandatory = $true)]
  $AcrName,
  [ValidateSet('Deploy', 'RotateCert', 'ShowTlsCert', 'ShowCertOnDisk', 'ShowLogs')]
  $Action = 'Deploy'
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$kvIdentityName = $VaultName

function CreateCert {
  Write-Host 'Creating certificate' -ForegroundColor Magenta
  $policy = New-TemporaryFile
  az keyvault certificate get-default-policy > $policy
  az keyvault certificate create --vault-name $VaultName -n cert1 -p "@$policy"
}

function Deploy {
  Write-Host 'Creating RG' -ForegroundColor Magenta
  az group create -g $ResourceGroup -l $Location | ConvertFrom-Json | Tee-Object -Variable rg
  Write-Host 'Creating ACR' -ForegroundColor Magenta
  az acr create -n $AcrName -g $ResourceGroup -l $Location --sku Standard
  Write-Host 'Creating KV' -ForegroundColor Magenta
  az keyvault create -n $VaultName -g $ResourceGroup -l $Location --enable-rbac-authorization
  Write-Host 'Creating AKS' -ForegroundColor Magenta
  az aks create -n $ClusterName -g $ResourceGroup -l $Location `
    --enable-oidc-issuer --enable-workload-identity `
    --enable-addons azure-keyvault-secrets-provider --enable-secret-rotation `
  | ConvertFrom-Json | Tee-Object -Variable aks

  Write-Host 'Creating MI' -ForegroundColor Magenta
  az identity create -n $kvIdentityName --resource-group $ResourceGroup | ConvertFrom-Json | Tee-Object -Variable kvIdentity
  az identity federated-credential create -n 'aks' --identity-name $kvIdentityName --resource-group $ResourceGroup `
    --issuer $aks.oidcIssuerProfile.issuerUrl --subject 'system:serviceaccount:default:test1'

  Write-Host 'Assigning roles' -ForegroundColor Magenta
  $currentUser = az ad signed-in-user show | ConvertFrom-Json
  az role assignment create --role 'Key Vault Administrator' --scope $rg.id --assignee-principal-type User --assignee-object-id $currentUser.id
  az role assignment create --role 'Key Vault Reader' --scope $rg.id --assignee-principal-type ServicePrincipal --assignee-object-id $kvIdentity.principalId
  az role assignment create --role 'Key Vault Secrets User' --scope $rg.id --assignee-principal-type ServicePrincipal --assignee-object-id $kvIdentity.principalId
  az role assignment create --role 'AcrPull' --scope $rg.id --assignee-principal-type ServicePrincipal --assignee-object-id $aks.identityProfile.kubeletidentity.objectId

  CreateCert

  Write-Host 'Logging into ACR' -ForegroundColor Magenta
  az acr login -n $AcrName

  Write-Host 'Building' -ForegroundColor Magenta
  dotnet publish --sc -r linux-x64 -p:PublishSingleFile=true -p:PublishTrimmed=true
  docker build ./bin/Release/net8.0/linux-x64/publish -f ./Dockerfile | Tee-Object -Variable dockerBuildOutput
  $digest = ($dockerBuildOutput | Select-String '\bsha256:\w+').Matches | Select-Object -Last 1 -ExpandProperty Value
  $tag = "$AcrName.azurecr.io/tests/test1:latest"
  docker image tag $digest $tag

  Write-Host 'Pushing' -ForegroundColor Magenta
  docker push $tag

  $env:PATH += ";$HOME/.azure-kubectl;$HOME/.azure-kubelogin"
  if (-not (Get-Command kubectl -ErrorAction Ignore) -or -not (Get-Command kubelogin -ErrorAction Ignore)) {
    Write-Host 'Installing K8s CLI' -ForegroundColor Magenta
    az aks install-cli
  }

  Write-Host 'Deploying pod' -ForegroundColor Magenta
  az aks get-credentials -n $ClusterName -g $ResourceGroup
  $yaml = (Get-Content ./test1.yml) `
    -replace '{{acrName}}', $AcrName `
    -replace '{{kvName}}', $VaultName `
    -replace '{{kvClientId}}', $kvIdentity.clientId `
    -replace '{{kvTenantId}}', $kvIdentity.tenantId 

  $yamlPath = New-TemporaryFile
  $yaml | Write-Host
  $yaml | Set-Content $yamlPath
  kubectl apply -f $yamlPath
}

switch ($Action) {
  'Deploy' {
    Deploy
  }
  'RotateCert' {
    CreateCert
  }
  'ShowTlsCert' {
    kubectl exec test1 -- openssl s_client -connect localhost:5001
  }
  'ShowCertOnDisk' {
    kubectl exec test1 -- cat /certs/cert1.crt
  }
  'ShowLogs' {
    kubectl logs test1
  }
}
