# Message Flow & Logic

## Complete Message Lifecycle

### 1. Sending a Message (Online)

```
User types message → taps send
        ↓
[WhatsAppChatScreen._sendMessage]
        ↓
Create LocalMessage with status='sending'
        ↓
Save to SQLite (MessageRepository.insertMessage)
        ↓
Update chat's last_message (ChatRepository.updateLastMessage)
        ↓
Add message to UI list (_messages.add)
        ↓
Scroll to bottom
        ↓
Check: EnhancedSocketService.isConnected()?
        ↓
    YES → Send via WebSocket
        ↓
    EnhancedSocketService.sendMessageToRecipient()
        ↓
    Server receives message
        ↓
    Server sends 'message_delivered' event
        ↓
    SocketEventBus.publish('message_delivered', data)
        ↓
    ChatSyncManager._handleMessageDelivered()
        ↓
    MessageRepository.updateMessageStatusByServerId()
        ↓
    Update SQLite: status='delivered'
        ↓
    UI updates: double gray tick ✓✓
        ↓
    Recipient opens chat
        ↓
    Server sends 'message_status' with status='read'
        ↓
    SocketEventBus.publish('message_status', data)
        ↓
    MessageRepository.updateMessageStatusByServerId()
        ↓
    Update SQLite: status='read'
        ↓
    UI updates: double blue tick ✓✓
```

### 2. Sending a Message (Offline)

```
User types message → taps send
        ↓
[WhatsAppChatScreen._sendMessage]
        ↓
Create LocalMessage with status='sending'
        ↓
Save to SQLite (MessageRepository.insertMessage)
        ↓
Update chat's last_message
        ↓
Add message to UI list
        ↓
Check: EnhancedSocketService.isConnected()?
        ↓
    NO → MessageOutboxQueue.triggerProcess()
        ↓
    Message saved in SQLite with status='sending'
        ↓
    UI shows clock icon ⏳
        ↓
    [Background] MessageOutboxQueue retry timer (every 30s)
        ↓
    User reconnects to internet
        ↓
    Connectivity listener detects connection
        ↓
    MessageOutboxQueue._processPendingMessages()
        ↓
    Check retry count and backoff time
        ↓
    If ready to retry:
        ↓
    EnhancedSocketService.isConnected()?
        ↓
        YES → Send via WebSocket
        ↓
        Update SQLite: status='sent'
        ↓
        UI updates: double gray tick ✓✓
        ↓
        NO → HTTP fallback
        ↓
        POST /chat/send-message-by-phone/{phone}
        ↓
        Update SQLite: status='sent' or 'failed'
        ↓
    If retry count >= 5:
        ↓
        Mark as 'failed' in SQLite
        ↓
        UI shows error icon ❌
```

### 3. Receiving a Message

```
Server sends 'new_message' event via WebSocket
        ↓
EnhancedSocketService._handleMessage()
        ↓
SocketEventBus.publish('new_message', data)
        ↓
ChatSyncManager._handleIncomingMessage()
        ↓
Check: sender_phone present?
        ↓
Check: Duplicate? (getMessageCountByServerId)
        ↓
    If duplicate → Skip
        ↓
    If new → Continue
        ↓
Determine: isMe? (sender_phone == my_phone_number)
        ↓
Get or create chat (ChatRepository.getOrCreateChat)
        ↓
Create LocalMessage with direction='received', status='delivered'
        ↓
Save to SQLite (MessageRepository.insertMessage)
        ↓
If NOT isMe:
        ↓
    Increment unread count (ChatRepository.incrementUnreadCount)
        ↓
Update chat's last_message (ChatRepository.updateLastMessage)
        ↓
Notify: onNewMessageReceived callback
        ↓
Notify: onChatListUpdated callback
        ↓
UI updates: new message appears, unread badge increments
        ↓
If app in background:
        ↓
    Show local notification
```

### 4. Loading Chat List

```
User opens WhatsAppChatListScreen
        ↓
[WhatsAppChatListScreen._initialize]
        ↓
Check: ChatAccessService.hasChatAccess()?
        ↓
Initialize: ChatLocalService.instance
        ↓
Initialize: ChatSyncManager.instance
        ↓
Initialize: MessageOutboxQueue.instance
        ↓
Setup socket callbacks via SocketEventBus
        ↓
Connect WebSocket (if not connected)
        ↓
Load chats from SQLite (ChatRepository.getAllChats)
        ↓
Apply filter (if search query)
        ↓
Display chat list with:
    - Contact name/phone
    - Last message preview
    - Timestamp (Today/Yesterday/Day/Date)
    - Unread count badge
    - Pin/mute/archive indicators
```

### 5. Loading Messages

```
User taps a chat in the list
        ↓
Navigate to WhatsAppChatScreen
        ↓
[WhatsAppChatScreen._initializeChat]
        ↓
Get my phone number from storage
        ↓
Get or create chat (ChatRepository.getOrCreateChat)
        ↓
Load messages (MessageRepository.getMessagesByPhone)
    - Limit: 100 messages
    - Order: created_at DESC
    - Filter: is_deleted=0, delete_for_me=0
        ↓
Display messages (reversed for bottom-up)
        ↓
Mark chat as seen (ChatRepository.resetUnreadCount)
        ↓
Setup socket callbacks for this chat
        ↓
Connect WebSocket (if not connected)
        ↓
[Scroll up to load older]
        ↓
_loadOlderMessages()
        ↓
MessageRepository.getMessagesBeforeDate()
    - Limit: 50 messages
    - Before: oldest message date
        ↓
Prepend older messages to list
```

### 6. Media Message Flow

```
User selects image/video/document
        ↓
[WhatsAppChatScreen._sendImage / _sendDocument]
        ↓
Create LocalMessage with media_local_path
        ↓
Save to SQLite (MessageRepository.insertMessage)
        ↓
Update chat's last_message
        ↓
Add to UI list
        ↓
Upload media to server (HTTP POST)
        ↓
    /chat/upload-media-by-phone/{phone}?message_type={type}
        ↓
Get remote URL from response
        ↓
Update SQLite: media_remote_url, status='sent'
        ↓
UI updates: double gray tick ✓✓
        ↓
[Recipient receives media message]
        ↓
Message saved with media_remote_url
        ↓
UI shows "Tap to download" placeholder
        ↓
User taps to download
        ↓
ChatSyncManager.downloadMedia()
        ↓
HTTP GET media_remote_url
        ↓
Save to local file system (ChatMediaStorage.saveImageBytes/etc)
        ↓
Update SQLite: media_local_path
        ↓
Save to media_cache table
        ↓
UI shows image/video/document
```

### 7. Message Actions

#### Delete for Me
```
User long-presses message → Delete → Delete for Me
        ↓
MessageActionService.deleteForMe(messageId)
        ↓
MessageRepository.softDeleteMessage()
        ↓
Update SQLite: is_deleted=1, delete_for_me=1
        ↓
If has media: delete local files
        ↓
UI updates: "🚫 This message was deleted"
```

#### Delete for Everyone
```
User long-presses message → Delete → Delete for Everyone
        ↓
Check: canDeleteForEveryone()?
    - Must be sent by me
    - Within 60 minutes
        ↓
MessageActionService.deleteForEveryone(messageId)
        ↓
MessageRepository.deleteMessageForEveryone()
        ↓
Update SQLite: is_deleted=1, delete_for_me=0, content='🚫 This message was deleted'
        ↓
If has media: delete local files
        ↓
If serverMessageId exists:
        ↓
    ChatSyncManager.sendDeleteForEveryone()
        ↓
    POST /chat/delete-for-everyone/{serverMessageId}
        ↓
Server notifies recipient
        ↓
Recipient updates their SQLite
```

#### Edit Message
```
User long-presses message → Edit
        ↓
Check: canEditMessage()?
    - Must be sent by me
    - Must be text type
    - Within 15 minutes
        ↓
MessageActionService.editMessage(messageId, newContent)
        ↓
MessageRepository.updateMessage()
        ↓
Update SQLite: content=newContent, updatedAt=now()
        ↓
If serverMessageId exists:
        ↓
    ChatSyncManager.sendEditMessage()
        ↓
    PUT /chat/edit-message/{serverMessageId}
        ↓
Server notifies recipient
        ↓
Recipient updates their SQLite
```

#### Forward Message
```
User long-presses message → Forward → Select contact
        ↓
MessageActionService.forwardMessage()
        ↓
Create new LocalMessage with:
    - Same content/media
    - forwarded_from=original chat phone
    - direction='sent'
    - status='sending'
        ↓
Save to SQLite (MessageRepository.insertMessage)
        ↓
Update target chat's last_message
        ↓
Send via WebSocket or queue for retry
```

#### Star Message
```
User long-presses message → Star
        ↓
MessageActionService.starMessage(messageId)
        ↓
MessageRepository.toggleStarMessage()
        ↓
Update SQLite: is_starred = 1 - is_starred
        ↓
UI updates: star icon toggles
```

### 8. Disappearing Messages

```
[Background Timer: every 5 minutes]
        ↓
MessageActionService.processDisappearingMessages()
        ↓
Get all chats (ChatRepository.getAllChats)
        ↓
For each chat:
        ↓
    Check: disappearing_timer > 0?
        ↓
    If yes:
        ↓
    Calculate threshold: now() - timer_seconds
        ↓
    Get messages (MessageRepository.getMessagesByPhone)
        ↓
    For each message:
        ↓
        Check: created_at < threshold AND not deleted?
        ↓
        If yes:
        ↓
        MessageRepository.deleteMessageForEveryone()
        ↓
        Update SQLite: is_deleted=1, delete_for_me=0
        ↓
        Delete local media files
```

### 9. Connectivity Handling

```
[App starts]
        ↓
ChatSystemInitializer.initialize()
        ↓
Setup connectivity listener
        ↓
Connectivity.onConnectivityChanged.listen()
        ↓
[Connection lost]
        ↓
Result: ConnectivityResult.none
        ↓
Status: ChatSystemStatus.offline
        ↓
UI shows orange banner: "No internet connection"
        ↓
Messages saved to SQLite with status='sending'
        ↓
[Connection restored]
        ↓
Result: ConnectivityResult.wifi/mobile
        ↓
Status: ChatSystemStatus.ready
        ↓
Connect WebSocket
        ↓
MessageOutboxQueue.triggerProcess()
        ↓
Send all pending messages
        ↓
ChatSyncManager.sendLastSeen()
        ↓
Perform delta sync
```

### 10. Socket Event Bus (Multi-Cast)

```
[Component A subscribes]
        ↓
SocketEventBus.instance.subscribe('new_message', callbackA)
        ↓
[Component B subscribes]
        ↓
SocketEventBus.instance.subscribe('new_message', callbackB)
        ↓
[Component C subscribes]
        ↓
SocketEventBus.instance.subscribe('new_message', callbackC)
        ↓
[WebSocket receives event]
        ↓
EnhancedSocketService._handleMessage()
        ↓
SocketEventBus.instance.publish('new_message', data)
        ↓
All callbacks executed:
    - callbackA(data)
    - callbackB(data)
    - callbackC(data)
        ↓
No callback overrides!
        ↓
[Component unsubscribes]
        ↓
SocketEventBus.instance.unsubscribe('new_message', callbackA)
        ↓
Only callbackB and callbackC receive future events
```

---

## Error Handling

### Message Send Failure
1. Save to SQLite with status='sending'
2. Try WebSocket send
3. If fails → try HTTP fallback
4. If fails → mark as 'failed' with error message
5. Outbox queue retries with exponential backoff
6. After 5 retries → permanent failure

### Database Corruption
1. All repository methods wrapped in try/catch
2. Errors logged to console
3. UI shows error state with retry button
4. User can clear all data and start fresh

### WebSocket Disconnect
1. isConnected() checks closeCode
2. Auto-reconnect with exponential backoff
3. Messages queued in outbox
4. Reconnect triggers outbox processing

### Media Download Failure
1. HTTP GET with 60s timeout
2. If fails → show "Tap to retry"
3. User can retry download
4. Failed downloads not cached

---

## Performance Optimizations

| Optimization | Implementation |
|--------------|----------------|
| **WAL Mode** | SQLite Write-Ahead Logging for concurrent reads/writes |
| **Lazy Loading** | 100 messages initially, 50 on scroll up |
| **Indexed Queries** | All frequently queried columns indexed |
| **Media Cache** | LRU eviction for old media files |
| **Exponential Backoff** | Retry delays: 5s → 15s → 60s → 5min → 15min |
| **Delta Sync** | Only sync new messages, not full history |
| **Image Compression** | Max 1280px, quality 80 (when integrated) |
| **Multi-Cast Events** | SocketEventBus prevents callback conflicts |
| **File Size Limits** | 10MB images, 100MB video, 50MB docs |
