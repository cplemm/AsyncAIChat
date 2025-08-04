# Async AI Chat Solution

This repo contains a sample for implementing asynchronous, decoupled communication with a Large Language Model (LLM) for systems that need to scale to many concurrent users.

## Scenario
Let's assume you have implemented the following architecture: a desktop app or SPA chat client is sending requests (incl. a natural language prompt from the user) to an API exposed in Azure via API Management (APIM). The API itself can be hosted using different services like Azure Functions, AKS, Container Apps, etc. The API component accesses a large language model (LLM) to retrieve a response for the user's prompt. All calls/connections are made synchronously.

![](Doc/sync_chat.png)

**Note:** The scenario is intentionally kept simple for the purposes of this sample. It can obviously be much more complicated, with the 'API' consisting of one or multiple collaborating agents, talking to multiple (different) LLMS, that can be base or reasoning models. 

## Challenge
Due to the nature of LLMs and also the introduction of advanced capabilities like retrieval augmented generation, multi-agent orchestration, etc., the end-to-end response time might be significant and easily be in the range of double-digits seconds. Also, if the system has to handle complex prompts or if you are using reasoning models, overall latency might be fairly high.

Now, imagine your app is going viral, more and more users are using it, so a large number of concurrent requests (e.g. hundreds of requests per second) are hitting the APIM layer: this would potentially lead to a lot of synchronous requests having to stay open for many, many seconds. This will most likely lead to typical issues seen in synchronous designs when operated at scale: SNAT port/socket exhaustion, timeouts, connection pool saturation, etc. 

**Long story short**: long‑running synchronous calls are an anti-pattern, specifically when used at scale.

## Solution
The way to tackle this is to decouple components by using asynchronicity and messaging. In order to avoid UI clients having to keep HTTP connections to APIM open for a long time, we can implement a pattern where clients just 'hand off' their request and 'wait' in an intelligent way for the response.

### Hand off request
An easy way to do that in APIM is to implement a policy that takes the request coming from the client and passes it as a message into an Azure Service Bus (SB) queue. As soon as SB has persisted the message (and ACKed it back to APIM), APIM sends an 'HTTP 201 Created' response back to the client (where the user can potentially continue to do stuff, as the UI thread is not freezing 🙂).

TODO: _include reference to policy snippet_

### Work on request
Now, a scalable worker component running in Azure Functions, Container Apps, AKS, etc. pulls the message from the queue and starts processing in the backend. In our simple scenario that's just an asynchronous call to an Azure OpenAI endpoint to retrieve an LLM response for the user's prompt. 

**Note:** This processing step can obviously be a much more complex procedure (RAG, multi-agent collaboration, etc.) and might involve even more layers of decoupling/messaging. But let's keep it with a single layer of decoupling for now and observe the effect this already has on latency & scale.

### Pass back response
So, how do we deliver the response back to the UI client, as the initial call has returned immediately after the message has been passed to Azure Servce Bus, and that connection has been closed?
Well, why not use a fully managed Azure Service like [Azure SignalR](https://learn.microsoft.com/en-us/azure/azure-signalr/signalr-overview) that has been built specifically for that scenario: pushing content to connected clients at scale, without the client having to poll.
The service is designed for large-scale, real-time applications and has been tested to handle millions of client connections.

### Approach
The picture below shows our revised approach:

![](Doc/async_chat.png)

Potentially, we can now connect thousands and thousands of clients at the same time and let them send requests, without running into the issues described above. The interesting piece is: you don't actually have to change too much of your existing code (well, obviously that depends on what you already have and where you're coming from). 

In order to demonstrate that, this repo shows a revised version for one of the canoncial SignalR Chat examples, see [Build an AI-powered group chat with Azure SignalR and OpenAI Completion API](https://learn.microsoft.com/en-us/azure/azure-signalr/signalr-tutorial-group-chat-with-openai) and the associated [GitHub repo](https://github.com/aspnet/AzureSignalR-samples/tree/main/samples/AIStreaming).

The app implements a SignalR group chat with ChatGPT integration, see below.

![](Doc/chat.jpg)

## Getting Started 
The fastest way to get started with this repo is spinning the environment up in GitHub Codespaces, as it will set up everything for you autgomatically. You can also [set it up locally](#local-environment).

### GitHub Codespaces
Open a web-based VS Code tab in your browser:

[![Open in GitHub Codespaces](https://img.shields.io/static/v1?style=for-the-badge&label=GitHub+Codespaces&message=Open&color=brightgreen&logo=github)](https://github.com/codespaces/new?template_repository=cplemm/AsyncAIChat)

### Local Environment
1. Install the required tools:
    - [Azure Developer CLI](https://aka.ms/azure-dev/install)
    - [Azure Functions Core Tools](https://github.com/Azure/azure-functions-core-tools/blob/main/README.md)
    - [.NET 8.0](https://dotnet.microsoft.com/download/dotnet/8.0)
2. Clone this repo:
```bash  
git clone https://github.com/cplemm/AsyncAIChat.git
```

## Deployment

### Deploy Azure Services

The steps below will provision the required Azure resources. Enter the following commands inside a terminal in the root directory of the repo. 

1. Login to your Azure account:

    ```shell
    azd auth login
    ```

    For GitHub Codespaces users, if the previous command fails, try:

   ```shell
    azd auth login --use-device-code
    ```

2. Create a new azd environment:

    ```shell
    azd env new
    ```

    Enter a name that will be used for the resource group.
    This will create a new `.azure` folder and set it as the active environment for any calls to `azd` going forward.
   
3. Start provisioning of the Azure resources:

    ```shell
    azd provision
    ```

    You will have to select your subscription and an Azure region, and specify a name for the target resource group (rgName).

4. Wait for the provisioning process to complete.
5. Optional: you can test the app & function locally before deploying them to Azure:
   
     - Azure Function
         - In the ./src/Function folder, create a copy of the ```local.settings.sample.json``` file and name it ```local.settings.json```.
         - Fill in all required configuration values => you can find them in the Azure Portal in the resources you have provisioned above.
         - Open a terminal window and navigate to the Functions directory (```cd ./src/Function```)
         - Start the Function locally by running ```func start```
     - Web App
         - In the ./src/Client folder, create a copy of the ```appsettings.sample.json``` file and name it ```appsettings.json```.
         - Fill the required configuration values for APIM and SignalR => again, find them in the Azure Portal. Copy the APIM subscription key from the 'SB subscription' that you find under APIs->Subscriptions.
         - Open a NEW terminal window and navigate to the Client directory (```cd ./src/Client```)
         - Start the web app locally by running ```dotnet run```
         - Open the browser on the port shown and [test](#test) the app.

### Deploy App & Function

1.  The statement below will provision (a) the Azure Function to process messages and (b) the Web App for the chat UI.
   
    ```shell
    azd deploy
    ```

2. Wait for the deployment process to complete.
3. (You can also combine the provisioning & deployment steps above in a single go using ```azd up```).  

## Test

To test the app, wait for the app deployment to finish. Then navigate to the URL of the web app and open it up in the browser. Check out the [original repo](https://github.com/aspnet/AzureSignalR-samples/tree/main/samples/AIStreaming#how-it-works) to see how the chat app works.

Go [here](https://microsoft.com) for more information about test results.

## Clean up

1.  To clean up all the resources created by this sample run the following statement, which will delete all resources, incl. the resource group.

    ```shell
    azd down --purge
    ```

The purge switch will make sure that the APIM and the Cognitive Services instances will get deleted permanently - otherwise, as soft deletion is the default, re-running the provisioning process will run into errors.

