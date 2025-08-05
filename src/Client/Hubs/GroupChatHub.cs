using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Options;
//using OpenAI;
using System.Text;

namespace AIStreaming.Hubs
{
    public class GroupChatHub : Hub
    {
        private readonly GroupAccessor _groupAccessor;
        private readonly GroupHistoryStore _history;

        public GroupChatHub(GroupAccessor groupAccessor, GroupHistoryStore history)
        {
            _groupAccessor = groupAccessor ?? throw new ArgumentNullException(nameof(groupAccessor));
            _history = history ?? throw new ArgumentNullException(nameof(history));
        }

        public async Task JoinGroup(string groupName)
        {
            await Groups.AddToGroupAsync(Context.ConnectionId, groupName);
            _groupAccessor.Join(Context.ConnectionId, groupName);
        }

        public override Task OnDisconnectedAsync(Exception? exception)
        {
            _groupAccessor.Leave(Context.ConnectionId);
            return Task.CompletedTask;
        }

        public async Task Chat(string userName, string message)
        {
            if (!_groupAccessor.TryGetGroup(Context.ConnectionId, out var groupName))
            {
                throw new InvalidOperationException("Not in a group.");
            }
            _history.GetOrAddGroupHistory(groupName, userName, message);
            await Clients.OthersInGroup(groupName).SendAsync("NewMessage", userName, message);
        }
    }
}
