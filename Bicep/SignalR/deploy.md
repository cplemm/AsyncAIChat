# Deploy SignalR 
All deployments will be done using Azure Verified Modules (AVM). AVM is an initiative to consolidate and set the standards for what a good Infrastructure-as-Code module looks like.

Modules will then align to these standards, across languages (Bicep, Terraform etc.) and will then be classified as AVMs and available from their respective language specific registries. These AVMs are fully supported by Microsoft and customers can use them in their production Bicep Code. For more information about AVM, check out the [AVM website](https://azure.github.io/Azure-Verified-Modules/).

The following resources will be created:

* SignalR Service

Navigate to "Bicep/SignalR" folder

```bash
cd ./Bicep/SignalR
```

Review the "parameters-main.json" file and update the parameter values if required according to your needs. 

Once the files are updated, deploy using the Azure CLI.

# [CLI](#tab/CLI)

```azurecli
REGION=swedencentral
az deployment sub create -n AsyncChat-SignalR -l $REGION -f main.bicep -p parameters-main.json
```