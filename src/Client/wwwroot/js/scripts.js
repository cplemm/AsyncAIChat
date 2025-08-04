var connection = null
var realUserName = null
var groupName = null
var apimConfig = {
    endpoint: null,
    subscriptionKey: null
}
updateConnectionStatus(false)

// Load configuration from server
async function loadConfig() {
    try {
        const response = await fetch('/api/config');
        if (response.ok) {
            const config = await response.json();
            apimConfig.endpoint = config.apimEndpoint;
            apimConfig.subscriptionKey = config.apimSubscriptionKey;
            console.log('Configuration loaded successfully');
        } else {
            throw new Error(`Failed to load configuration: ${response.status}`);
        }
    } catch (error) {
        console.error('Error loading configuration:', error);
        // Fallback to default values or show error
        alert('Failed to load APIM configuration. Please check server settings.');
    }
}

// Initialize configuration when page loads
document.addEventListener('DOMContentLoaded', function() {
    loadConfig();
});

document.getElementById('userName').addEventListener('keydown', function (event) {
    if (!realUserName && event.key === 'Enter') {
        submitName();
    }
});

document.getElementById('chatInput').addEventListener('keydown', function (event) {
    const textValue = document.getElementById('chatInput').value;
    if (textValue && event.key === 'Enter') {
        sendMessage();
    }
});

function submitName() {
    const userName = document.getElementById('userName').value;
    if (userName) {
        document.getElementById('namePrompt').classList.add('hidden');
        document.getElementById('groupSelection').classList.remove('hidden');
        document.getElementById('userNameDisplay').innerText = userName;

        realUserName = userName;
    } else {
        alert('Please enter your name');
    }
}

function createGroup() {
    groupName = Math.random().toString(36).substr(2, 6);
    joinGroupWithName(groupName);
}

function joinGroup() {
    groupName = document.getElementById('groupName').value;
    if (groupName) {
        joinGroupWithName(groupName);
    } else {
        alert('Please enter a group name');
    }
}

function joinGroupWithName(groupName) {
    document.getElementById('groupSelection').classList.add('hidden');
    document.getElementById('chatGroupName').innerText = 'Group: ' + groupName;
    document.getElementById('chatPage').classList.remove('hidden');

    connection = new signalR.HubConnectionBuilder().withUrl(`/groupChat`).withAutomaticReconnect().build();
    bindConnectionMessages(connection);
    connection.start().then(() => {
        updateConnectionStatus(true);
        onConnected(connection);
        connection.send("JoinGroup", groupName);
    }).catch(error => {
        updateConnectionStatus(false);
        console.error(error);
    })
}

function bindConnectionMessages(connection) {
    connection.on('newMessage', (name, timestamp, message) => {
        const localTimestamp = new Date().toLocaleString();
        // console.log('Received message:', name, timestamp, `(local: ${localTimestamp})`, message);
        appendMessage(false, `${name}:\n${timestamp}\n${localTimestamp}\n${message}`);
    });
    connection.on('newMessageWithId', (name, id, message) => {
        appendMessageWithId(id, `${name}:\n${timestamp}\n${message}`);
    });
    connection.onclose(() => {
        updateConnectionStatus(false);
    });
}

function onConnected(connection) {
    console.log('connection started');
}

// Modified sendMessage function with better error handling
async function sendMessage() {
    const message = document.getElementById('chatInput').value;
    if (message) {
        appendMessage(true, message);
        document.getElementById('chatInput').value = '';
        //connection.send("Chat", realUserName, message);
        
        // Ensure config is loaded
        if (!apimConfig.endpoint || !apimConfig.subscriptionKey) {
            await loadConfig();
        }
        
        // Check if config is still missing
        if (!apimConfig.endpoint || !apimConfig.subscriptionKey) {
            appendMessage(false, `Error: APIM configuration not available`);
            return;
        }
        
        try {
            // Send to APIM endpoint instead of SignalR
            const response = await fetch(apimConfig.endpoint, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Ocp-Apim-Subscription-Key': apimConfig.subscriptionKey,
                    'Accept': 'application/json'
                },
                body: JSON.stringify({
                    userName: realUserName,
                    groupName: groupName, 
                    message: message,
                    timestamp: new Date().toISOString()
                })
            });

            // Log response details for debugging
            console.log('Response status:', response.status);
            console.log('Response headers:', response.headers);
            
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            // Get response as text first to check if it's valid JSON
            const responseText = await response.text();
            console.log('Raw response:', responseText);
            
            // Check if response is empty
            if (!responseText || responseText.trim() === '') {
                console.log('Empty response received');
                //appendMessage(false, `API: Message sent successfully (no response content)`);
                return;
            }
            
            // Try to parse as JSON
            let result;
            try {
                result = JSON.parse(responseText);
            } catch (jsonError) {
                console.error('Failed to parse JSON:', jsonError);
                console.log('Response was:', responseText);
                appendMessage(false, `API Response: ${responseText}`);
                return;
            }
            
            console.log('Message sent successfully:', result);
            
            // Handle the response from APIM
            if (result && result.response) {
                //appendMessage(false, `API: ${result.response}`);
            } else if (result) {
                //appendMessage(false, `API: ${JSON.stringify(result)}`);
            }
            
        } catch (error) {
            console.error('Error sending message to APIM:', error);
            appendMessage(false, `Error: Failed to send message - ${error.message}`);
        }
    }
}

function appendMessage(isSender, message) {
    const chatMessages = document.getElementById('chatMessages');
    const messageElement = createMessageElement(message, isSender, null)
    chatMessages.appendChild(messageElement);
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function appendMessageWithId(id, message) {
    // We update the full message
    const chatMessages = document.getElementById('chatMessages');
    if (document.getElementById(id)) {
        let messageElement = document.getElementById(id);
        messageElement.innerText = message;
    } else {
        let messageElement = createMessageElement(message, false, id);
        chatMessages.appendChild(messageElement);
    }
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function createMessageElement(message, isSender, id) {
    const messageElement = document.createElement('div');
    messageElement.classList.add('message', isSender ? 'sent' : 'received');
    messageElement.innerText = message;
    if (id) {
        messageElement.id = id;
    }
    return messageElement;
}

function updateConnectionStatus(isConnected) {
    const statusElement = document.getElementById('connectionStatus');
    if (isConnected) {
        statusElement.innerText = 'Connected';
        statusElement.classList.remove('status-disconnected');
        statusElement.classList.add('status-connected');
    } else {
        statusElement.innerText = 'Disconnected';
        statusElement.classList.remove('status-connected');
        statusElement.classList.add('status-disconnected');
    }
}