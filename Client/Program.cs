using AIStreaming;
using AIStreaming.Hubs;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddSignalR().AddAzureSignalR();

// Add CORS if needed
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(builder =>
    {
        builder.AllowAnyOrigin()
               .AllowAnyHeader()
               .AllowAnyMethod();
    });
});

builder.Services.AddSingleton<GroupAccessor>()
    .AddSingleton<GroupHistoryStore>()
    /*.AddAzureOpenAI(builder.Configuration)*/;

var app = builder.Build();

// Enable detailed error pages in non-production environments
if (!app.Environment.IsProduction())
{
    app.UseDeveloperExceptionPage();
}
else
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseDefaultFiles();
app.UseStaticFiles();

app.UseRouting();

// Use CORS
app.UseCors();

// Add API endpoint to expose APIM configuration
app.MapGet("/api/config", (IConfiguration configuration) =>
{
    return new
    {
        ApimEndpoint = configuration["APIM:Endpoint"],
        ApimSubscriptionKey = configuration["APIM:SubscriptionKey"]
    };
});

app.MapHub<GroupChatHub>("/groupChat");
app.Run();
