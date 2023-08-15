# Kestrel/AKS certificate auto-rotation test

## Prerequisites
* Azure CLI
* Docker CLI
* .NET 8 SDK
* PowerShell 7

## Steps
1. Set up the environment:
   ```powershell
   $name = 'test1'
   $location = 'westeurope'
1. Deploy:
   ```powershell
   ./deploy.ps1 -ResourceGroup $name -Location  $location -ClusterName $name -VaultName  $name -AcrName $name
   ```
1. Check certificates by running the above command with `-Action ShowCertOnDisk` and `-Action ShowTlsCert`.
1. Rotate certificates by running the above command with `-Action RotateCert`.
1. Check certificates again.
1. Check logs by running the above command with `-Action ShowLogs`.
