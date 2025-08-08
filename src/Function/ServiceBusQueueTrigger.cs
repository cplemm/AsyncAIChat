using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Azure.AI.OpenAI;
using Azure;
using System.Threading;
using System.Net.Http;

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
            
            var clientOptions = new OpenAIClientOptions()
            {
                Retry = {
                    MaxRetries = 3,
                    Delay = TimeSpan.FromSeconds(1),
                    MaxDelay = TimeSpan.FromSeconds(30),
                    Mode = Azure.Core.RetryMode.Exponential
                },
                NetworkTimeout = TimeSpan.FromMinutes(2)
            };
            
            return new OpenAIClient(new Uri(endpoint), new AzureKeyCredential(apiKey), clientOptions);
        });

        private static OpenAIClient OpenAIClient => _openAIClient.Value;

        public ServiceBusQueueTrigger(ILogger<ServiceBusQueueTrigger> logger)
        {
            _logger = logger;
        }

        [Function("ProcessMessage")]
        [SignalROutput(HubName = "%AzureSignalRHubName%")]
        public async Task<SignalRMessageAction> Run(
            [ServiceBusTrigger("%ServiceBusQueueName%", Connection = "ServiceBusConnection")] string message,
            CancellationToken cancellationToken = default)
        {
            var startTime = DateTime.UtcNow;
            _logger.LogInformation($"Processing message at {startTime:yyyy-MM-ddTHH:mm:ss.fff}: {message}");

            string userName, groupName, userMessage, timestampClient = DateTime.MinValue.ToString("yyyy-MM-ddTHH:mm:ss.ff");
            try
            {
                var obj = JsonSerializer.Deserialize<Dictionary<string, string>>(message);
                if (obj == null)
                    throw new Exception("Deserialized message is null.");
                userName = obj.GetValueOrDefault("userName") ?? "Unknown";
                groupName = obj.GetValueOrDefault("groupName") ?? "default";
                userMessage = obj.GetValueOrDefault("message") ?? "";
                timestampClient = obj.GetValueOrDefault("timestamp") ?? "";
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to parse incoming message JSON: {ex.Message}");
                return new SignalRMessageAction("NewMessage")
                {
                    Arguments = new object[] { "System", timestampClient, DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss.ff"), "Error processing message" },
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
                        // Use the static OpenAI client with timeout
                        var client = OpenAIClient;

                        // Create chat completion options
                        var chatCompletionsOptions = new ChatCompletionsOptions()
                        {
                            DeploymentName = deployment,
                            Messages = { new ChatRequestUserMessage(userMessage) },
                            MaxTokens = int.TryParse(Environment.GetEnvironmentVariable("MaxTokens"), out var maxTokens) ? maxTokens : 100
                        };

                        // Get response from Azure OpenAI with timeout
                        using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
                        cts.CancelAfter(TimeSpan.FromSeconds(30)); // 30 second timeout for OpenAI call
                        
                        var response = await client.GetChatCompletionsAsync(chatCompletionsOptions, cts.Token);
                        if (response.Value?.Choices?.Count > 0)
                        {
                            responseMessage = response.Value.Choices[0].Message.Content;
                            var endTime = DateTime.UtcNow;
                            var duration = (endTime - startTime).TotalMilliseconds;
                            _logger.LogInformation($"LLM Response received in {duration}ms: {responseMessage}");
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
                    catch (OperationCanceledException ex) when (ex.CancellationToken.IsCancellationRequested)
                    {
                        _logger.LogError($"Azure OpenAI call timed out: {ex.Message}");
                        responseMessage = "AI request timed out";
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError($"Exception calling Azure OpenAI: {ex.Message}");
                        responseMessage = "Error processing AI request";
                    }
                }
            }

            // Log final processing time
            var totalTime = DateTime.UtcNow - startTime;
            _logger.LogInformation($"Total message processing time: {totalTime.TotalMilliseconds}ms");

            // Return SignalR message action
            return new SignalRMessageAction("NewMessage")
            {
                Arguments = new object[] { userName, timestampClient, DateTime.Now.ToString("yyyy-MM-ddTHH:mm:ss.ff"), responseMessage },
                GroupName = groupName
            };
        }
    }
}
