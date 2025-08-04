# Dev Container for Async-Chat

This devcontainer is configured for:
- .NET 8 development
- Azure Developer CLI (azd)
- Azure CLI
- Bicep CLI
- Node.js (LTS)
- Recommended VS Code extensions for Azure, Bicep, and .NET

## Usage
- Open in GitHub Codespaces or locally in VS Code with the Dev Containers extension.
- Infrastructure can be provisioned with `azd provision` and deployed with `azd deploy`.

## Ports
- 7071: Azure Functions local
- 5000, 5001: ASP.NET Core (Client)
