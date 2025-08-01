# Async AI Chat Solution

This repo contains a sample for implementing asynchronous, decoupled communication with a Large Language Model (LLM) for systems that need to scale to many concurrent users.

## Scenario

Let's assume you have implemented the following architecture: a desktop app or SPA client is sending requests (incl. a natural language prompt from the user) to an API exposed in Azure via API Management (APIM). The API itself can be hosted using different services like Azure Functions, AKS, Container Apps, etc. The API component accesses a large language model (LLM) to retrieve a response for the user's prompt. All calls/connections are made synchronously.

![](Doc/sync_chat.png)

**Note:** The scenario is intentionally kept simple for the purposes of this sample. It can obviously be much more complicated, with the 'API' consisting of one or multiple collaborating agents, talking to multiple (different) LLMS, that can be base or reasoning models. 

## Challenge
Due to the nature of LLMs and also the introduction of further capabilities like retrieval augmented generation, multi-agent orchestration, etc., the end-to-end response time might be significant and easily be in the double-digits seconds range. Specifically, if the system has to handle complex prompts or if you are using reasoning models, overall latency might be high.

## Deployment 

...
