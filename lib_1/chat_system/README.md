# Starlight WhatsApp-Style Chat System

## System Overview

A complete local-first chat system that mirrors WhatsApp's architecture. Messages are saved to SQLite immediately, sent to server via WebSocket in the background, and sync status flows back to update local state.

---

## Core Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        UI Layer                              │
│  ┌──────────────────────┐    ┌────────────────────────────┐  │
│  │ WhatsAppChatListScreen│    │   WhatsAppChatScreen       │  │
│  │ (Chat List)          │    │   (Individual Chat)        │  │
│  └──────────────────────┘    └────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                   Service Layer                              │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │ChatStorageSvc│ │ChatSyncMgr   │ │MessageOutboxQueue    │  │
│  │ (Local CRUD) │ │ (WS↔SQLite)  │ │ (Offline Retry)      │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────┐  │
│  │MessageAction │ │SocketEventBus│ │PhoneNormalization    │  │
│  │ (Delete/Edit)│ │ (Multi-cast) │ │ (Format Utility)     │  │
│  └──────────────┘ └──────────────┘ └──────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                   Local Database (SQLite)                    │
│  Tables: chats, messages, media_cache, chat_settings        │
│  Repositories: ChatRepository, MessageRepository, MediaRepo │
│  Storage: ChatMediaStorage (File System)                    │
└─────────────────────────────────────────────────────────────┘
                              ↕
┌─────────────────────────────────────────────────────────────┐
│                    Network Layer                             │
│  Primary: WebSocket (EnhancedSocketService)                 │
│  Fallback: HTTP REST (when offline)                         │
│  Events: SocketEventBus (multi-cast, no overrides)          │
└─────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
lib/chat_system/
├── whatsapp_chat.dart                      # Main export barrel
├── chat_system_entry.dart                  # Entry point widget
├── screens/
│   ├── screens.dart                        # Barrel export
│   ├── whatsapp_chat_list_screen.dart      # Chat list with pin/mute/archive
│   └── whatsapp_chat_screen.dart           # Individual chat with all features
├── services/
│   ├── services.dart                       # Barrel export
│   ├── chat_system_initializer.dart        # Wires all services together
│   ├── chat_storage_service.dart           # Local storage CRUD
│   ├── chat_sync_manager.dart              # WebSocket to SQLite relay
│   ├── message_outbox_queue.dart           # Offline message queue with retry
│   ├── message_action_service.dart         # Delete/edit/forward/star/disappear
│   └── socket_event_bus.dart               # Multi-cast event system
└── utils/
    └── phone_normalization.dart            # Consistent phone formatting

lib/chat_local_db/
├── database/
│   └── chat_local_database.dart            # SQLite schema (v2, WAL mode)
├── models/
│   ├── local_chat.dart                     # Chat model (phone-number keyed)
│   ├── local_message.dart                  # Message model (full media support)
│   └── media_info.dart                     # Media cache tracking
├── repositories/
│   ├── chat_repository.dart                # Chat CRUD operations
│   ├── message_repository.dart             # Message CRUD + status updates
│   └── media_repository.dart               # Media cache operations
└── storage/
    └── chat_media_storage.dart             # File system media storage
```

---

## Key Files

| File | Purpose |
|------|---------|
| `whatsapp_chat.dart` | Main export — import this to access the system |
| `chat_system_entry.dart` | Entry point — access check + initialization |
| `whatsapp_chat_list_screen.dart` | Chat list UI with pin/mute/archive/search |
| `whatsapp_chat_screen.dart` | Individual chat with send/receive/media |
| `chat_system_initializer.dart` | Initializes all services, handles connectivity |
| `chat_sync_manager.dart` | WebSocket events → SQLite saves → UI updates |
| `message_outbox_queue.dart` | Offline queue with exponential backoff retry |
| `message_action_service.dart` | Delete/edit/forward/star/disappearing messages |
| `socket_event_bus.dart` | Multi-cast event system (no callback overrides) |
| `phone_normalization.dart` | Consistent phone number formatting |

---

## Quick Start

```dart
import 'package:starlight_flutter/chat_system/whatsapp_chat.dart';

// Navigate to chat system
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const WhatsAppChatEntry()),
);
```

---

## Dependencies

Required packages (already in `pubspec.yaml`):
- `provider: ^6.1.2` — State management
- `connectivity_plus: ^6.1.0` — Network detection
- `sqflite: ^2.4.2+1` — Local database
- `web_socket_channel: ^3.0.3` — WebSocket communication
- `path_provider: ^2.1.5` — File system paths
- `uuid: ^4.5.3` — Unique ID generation
- `image_picker: ^1.2.2` — Image selection
- `file_picker: 11.0.2` — File selection
- `record: ^6.2.0` — Voice recording
- `just_audio: ^0.10.5` — Audio playback

---

## Backend Endpoints Required

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/chat/send-message-by-phone/{phone}` | HTTP fallback for sending |
| POST | `/chat/upload-media-by-phone/{phone}` | Upload media files |
| GET | `/chat/messages-by-phone/{phone}` | Get messages by phone |
| GET | `/chat/sync-delta` | Delta sync for offline messages |
| POST | `/chat/mark-read/{serverMessageId}` | Mark message as read |
| POST | `/chat/delete-for-everyone/{serverMessageId}` | Delete for everyone |
| PUT | `/chat/edit-message/{serverMessageId}` | Edit message content |
| POST | `/chat/last-seen` | Update last seen timestamp |

---

## WebSocket Events

| Event | Direction | Data |
|-------|-----------|------|
| `new_message` | Server → Client | sender_phone, recipient_phone, content, message_type, message_id, timestamp |
| `message_delivered` | Server → Client | message_id |
| `message_status` | Server → Client | message_id, status (delivered/read) |
| `connection_created` | Server → Client | Connection established |
| `connection_replaced` | Server → Client | Another device connected |
| `send_message` | Client → Server | recipient_phone, content, message_type, timestamp |

---

## Database Schema

### chats Table
| Column | Type | Default |
|--------|------|---------|
| phone_number | TEXT (PK) | - |
| contact_name | TEXT | '' |
| profile_image_url | TEXT | '' |
| last_message | TEXT | '' |
| last_message_time | TEXT | '' |
| last_message_type | TEXT | 'text' |
| unread_count | INTEGER | 0 |
| is_muted | INTEGER | 0 |
| is_archived | INTEGER | 0 |
| is_pinned | INTEGER | 0 |
| is_blocked | INTEGER | 0 |
| disappearing_timer | INTEGER | 0 |
| chat_created_at | TEXT | now() |
| chat_updated_at | TEXT | now() |

### messages Table
| Column | Type | Default |
|--------|------|---------|
| id | INTEGER (PK) | AUTOINCREMENT |
| chat_phone_number | TEXT (FK) | - |
| message_type | TEXT | 'text' |
| message_direction | TEXT | 'sent' |
| content | TEXT | '' |
| media_local_path | TEXT | '' |
| media_remote_url | TEXT | '' |
| media_file_name | TEXT | '' |
| media_mime_type | TEXT | '' |
| media_size_bytes | INTEGER | 0 |
| media_duration_ms | INTEGER | 0 |
| media_width | INTEGER | 0 |
| media_height | INTEGER | 0 |
| media_thumbnail_path | TEXT | '' |
| is_starred | INTEGER | 0 |
| is_deleted | INTEGER | 0 |
| delete_for_me | INTEGER | 0 |
| reply_to_message_id | INTEGER | 0 |
| reply_to_content | TEXT | '' |
| forwarded_from | TEXT | '' |
| status | TEXT | 'sent' |
| server_message_id | TEXT | '' |
| error_message | TEXT | '' |
| created_at | TEXT | now() |
| updated_at | TEXT | now() |

### media_cache Table
| Column | Type | Default |
|--------|------|---------|
| id | INTEGER (PK) | AUTOINCREMENT |
| message_id | INTEGER (FK) | - |
| file_path | TEXT (UNIQUE) | - |
| file_type | TEXT | - |
| file_size_bytes | INTEGER | - |
| is_downloaded | INTEGER | 0 |
| download_progress | REAL | 0.0 |
| last_accessed | TEXT | now() |

---

## Notes

- Phone number is the primary identifier throughout the local database
- All timestamps stored in ISO 8601 format
- Media files stored in `ApplicationDocumentsDirectory/StarlightChat/`
- Disappearing messages checked every 5 minutes
- Delete for everyone time limit: 60 minutes
- Edit message time limit: 15 minutes
- Database uses WAL mode for performance
- SocketEventBus prevents callback override issues
- Message outbox uses exponential backoff (5s → 15s → 60s → 5min → 15min)
