using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Configuration;

namespace TestClient
{
    class Program
    {
        static async Task Main(string[] args)
        {
            // Load configuration
            var config = new ConfigurationBuilder()
                .SetBasePath(AppContext.BaseDirectory)
                .AddJsonFile("appsettings.json", optional: false)
                .Build();

            var hubUrl = config["SignalR:Endpoint"];
            if (string.IsNullOrWhiteSpace(hubUrl))
            {
                Console.WriteLine("SignalR endpoint not configured.");
                return;
            }

            Console.Write("Enter group name to join: ");
            var groupName = Console.ReadLine();

            var connection = new HubConnectionBuilder()
                .WithUrl(hubUrl)
                .WithAutomaticReconnect()
                .Build();

            connection.Closed += async (error) =>
            {
                Console.WriteLine("Connection closed. Reconnecting...");
                await Task.Delay(2000);
                await connection.StartAsync();
            };

            connection.On<string, string, string, string>("NewMessage", (name, timestampClient, timestampServer, message) =>
            {
                Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.ff")} - {name}\n{timestampClient}\n{timestampServer}\n{message}");
            });

            connection.On<string, string, string, string, string>("newMessageWithId", (name, id, timestampClient, timestampServer, message) =>
            {
                Console.WriteLine($"{DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.ff")} - {name} (id: {id})\n{timestampClient}\n{timestampServer}\n{message}");
            });

            await connection.StartAsync();
            Console.WriteLine("Connected!");

            await connection.InvokeAsync("JoinGroup", groupName);
            Console.WriteLine($"Joined group: {groupName}");

            Console.WriteLine("Listening for messages. Press Ctrl+C to exit.");
            await Task.Delay(-1);
        }
    }
}