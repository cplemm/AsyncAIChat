using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Azure.AI.OpenAI;
using Azure;

namespace SBTriggerOAI
{
    public class ServiceBusQueueTrigger
    {
        private readonly ILogger<ServiceBusQueueTrigger> _logger;
        private static readonly Lazy<OpenAIClient> _openAIClient = new Lazy<OpenAIClient>(() =>
        {
            var endpoint = Environment.GetEnvironmentVariable("AzureOpenAIEndpoint");
            var apiKey = Environment.GetEnvironmentVariable("AzureOpenAIKey");
            
            if (string.IsNullOrEmpty(endpoint) || string.IsNullOrEmpty(apiKey))
            {
                throw new InvalidOperationException("Azure OpenAI configuration is missing. Please set AzureOpenAIEndpoint and AzureOpenAIKey environment variables.");
            }
            
            return new OpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey));
        });

        private static OpenAIClient OpenAIClient => _openAIClient.Value;

        public ServiceBusQueueTrigger(ILogger<ServiceBusQueueTrigger> logger)
        {
            _logger = logger;
        }

        [Function("ProcessMessage")]
        [SignalROutput(HubName = "%AzureSignalRHubName%")]
        public async Task<SignalRMessageAction> Run(
            [ServiceBusTrigger("%ServiceBusQueueName%", Connection = "ServiceBusConnection")] string message)
        {
            _logger.LogInformation($"Message: {message}");

            string userName, groupName, userMessage, timestamp;
            try
            {
                var obj = JsonSerializer.Deserialize<Dictionary<string, string>>(message);
                if (obj == null)
                    throw new Exception("Deserialized message is null.");
                userName = obj.GetValueOrDefault("userName") ?? "Unknown";
                groupName = obj.GetValueOrDefault("groupName") ?? "default";
                userMessage = obj.GetValueOrDefault("message") ?? "";
                timestamp = obj.GetValueOrDefault("timestamp") ?? "";
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to parse incoming message JSON: {ex.Message}");
                return new SignalRMessageAction("NewMessage")
                {
                    Arguments = new object[] { "System", DateTime.Now, "Error processing message" },
                    GroupName = "default"
                };
            }

            string responseMessage = userMessage;

            if (userMessage.StartsWith("@gpt"))
            {
                // Get deployment name from environment variable
                var deployment = Environment.GetEnvironmentVariable("AzureOpenAIDeployment");
                
                if (string.IsNullOrEmpty(deployment))
                {
                    _logger.LogError("Azure OpenAI deployment configuration is missing. Please set AzureOpenAIDeployment environment variable.");
                    responseMessage = "Configuration error: OpenAI deployment not configured";
                }
                else
                {
                    try
                    {
                        // Use the static OpenAI client
                        var client = OpenAIClient;

                        // Create chat completion options
                        var chatCompletionsOptions = new ChatCompletionsOptions()
                        {
                            DeploymentName = deployment,
                            Messages = { new ChatRequestUserMessage(userMessage) },
                            MaxTokens = 200
                        };

                        // Get response from Azure OpenAI
                        var response = await client.GetChatCompletionsAsync(chatCompletionsOptions);
                        if (response.Value?.Choices?.Count > 0)
                        {
                            responseMessage = response.Value.Choices[0].Message.Content;
                            _logger.LogInformation($"LLM Response: {responseMessage}");
                        }
                        else
                        {
                            _logger.LogError("No response received from Azure OpenAI");
                            responseMessage = "No response from AI service";
                        }
                    }
                    catch (InvalidOperationException ex)
                    {
                        _logger.LogError($"Azure OpenAI configuration error: {ex.Message}");
                        responseMessage = "AI service configuration error";
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError($"Exception calling Azure OpenAI: {ex.Message}");
                        responseMessage = "Error processing AI request";
                    }
                }
            }

            // Return SignalR message action
            return new SignalRMessageAction("NewMessage")
            {
                Arguments = new object[] { userName, DateTime.Now, responseMessage },
                GroupName = groupName
            };
        }
    }
}
