using './main.bicep'

param location = 'eastus2'
param workloadName = '3tier'
param environment = 'prod'
// Replace with the SSH public key (or wire via Key Vault reference at deploy time).
param adminSshPublicKey = 'ssh-rsa AAAA...replace-me...'
