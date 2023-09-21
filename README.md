# Kestrel/AKS certificate auto-rotation test

## Prerequisites
* PowerShell 7
* Azure CLI
* Docker CLI

## Steps
1. Log into Azure:
   ```powershell
   az login
   az account set -s <subscription>
   ```
1. Set up the environment:
   ```powershell
   $name = 'auto-rotation-test'
   $location = 'westeurope'
   ```
1. Deploy:
   ```powershell
   ./deploy.ps1 -ResourceGroup $name -Location  $location -ClusterName $name -VaultName  $name -AcrName $name
   ```
   :bulb: The Key Vault and ACR names have to be globally unique
1. Check certificates by running the above command with `-Action ShowCertOnDisk` and `-Action ShowTlsCert`.
1. Rotate certificates by running the above command with `-Action RotateCert`.
1. Check certificates again.
1. Check logs by running the above command with `-Action ShowLogs`.
