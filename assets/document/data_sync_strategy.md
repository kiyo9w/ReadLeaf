# ReadLeaf Data Synchronization Strategy

## Overview
This document outlines the strategy for synchronizing local data (stored in Hive) with cloud storage (Supabase) in ReadLeaf. The goal is to ensure seamless data persistence and synchronization across devices while maintaining offline capabilities.

## Data Categories

### 1. User Preferences
#### Local Storage (Hive)
```dart
class UserPreferences {
  bool darkMode
  String fontSize
  bool enableAIFeatures
  bool showReadingProgress
  bool enableAutoSync
  Map<String, dynamic> customSettings
}
```

#### Cloud Storage (Supabase)
```sql
CREATE TABLE user_preferences (
    user_id UUID PRIMARY KEY,
    dark_mode BOOLEAN,
    font_size TEXT,
    enable_ai_features BOOLEAN,
    show_reading_progress BOOLEAN,
    enable_auto_sync BOOLEAN,
    custom_settings JSONB,
    last_synced_at TIMESTAMPTZ
);
```

#### Sync Strategy
- Sync Trigger: On preference changes and app launch
- Conflict Resolution: Latest timestamp wins
- Sync Direction: Bidirectional
- Batch Size: Single record per user
- Frequency: Immediate for critical settings, batched for others

### 2. Reading Progress
#### Local Storage (Hive)
```dart
class BookMetadata {
    String filePath
    int lastOpenedPage
    int totalPages
    double readingProgress
    DateTime lastReadTime
    List<TextHighlight> highlights
    List<AiConversation> aiConversations
}
```

#### Cloud Storage (Supabase)
```sql
CREATE TABLE reading_progress (
    user_id UUID,
    book_id TEXT,
    last_page INTEGER,
    total_pages INTEGER,
    reading_progress FLOAT,
    last_read_time TIMESTAMPTZ,
    highlights JSONB,
    PRIMARY KEY (user_id, book_id)
);
```

#### Sync Strategy
- Sync Trigger: Page turns, app background/foreground
- Conflict Resolution: Latest timestamp with merge for highlights
- Sync Direction: Bidirectional
- Batch Size: Up to 50 books at a time
- Frequency: Every 30 seconds while reading, immediate on app close

### 3. AI Character Preferences
#### Local Storage (Hive)
```dart
class AiCharacterPreference {
    String characterName
    DateTime lastUsed
    Map<String, dynamic> customSettings
}

class CustomCharacter {
    String name
    String imagePath
    String personality
    String promptTemplate
    Map<String, String> taskPrompts
}
```

#### Cloud Storage (Supabase)
```sql
CREATE TABLE character_preferences (
    user_id UUID,
    character_name TEXT,
    last_used TIMESTAMPTZ,
    custom_settings JSONB,
    PRIMARY KEY (user_id, character_name)
);

CREATE TABLE custom_characters (
    user_id UUID,
    name TEXT,
    image_path TEXT,
    personality TEXT,
    prompt_template TEXT,
    task_prompts JSONB,
    created_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, name)
);
```

#### Sync Strategy
- Sync Trigger: Character selection, custom character creation/deletion
- Conflict Resolution: Server-side timestamp with merge strategy
- Sync Direction: Bidirectional
- Batch Size: All characters (typically < 20 records)
- Frequency: On character switch and app launch

### 4. Chat History
#### Local Storage (Hive)
```dart
class ChatMessage {
    String text
    bool isUser
    DateTime timestamp
    String characterName
    String bookId
}
```

#### Cloud Storage (Supabase)
```sql
CREATE TABLE chat_history (
    user_id UUID,
    character_name TEXT,
    message_text TEXT,
    is_user BOOLEAN,
    timestamp TIMESTAMPTZ,
    book_id TEXT,
    PRIMARY KEY (user_id, character_name, timestamp)
);

-- Index for efficient retrieval
CREATE INDEX idx_chat_history_recent 
ON chat_history (user_id, character_name, timestamp DESC);
```

#### Sync Strategy
- Sync Trigger: New messages, app launch
- Retention: Latest 200 messages per character
- Conflict Resolution: Timestamp-based ordering
- Sync Direction: Bidirectional with server truncation
- Batch Size: 50 messages per request
- Frequency: Every 5 minutes during active chat, on app background

## Implementation Details

### 1. Sync Manager
```dart
class SyncManager {
    // Core sync scheduling
    Future<void> scheduleSyncTasks()
    Future<void> syncPreferences()
    Future<void> syncReadingProgress()
    Future<void> syncCharacterPreferences()
    Future<void> syncChatHistory()
    
    // Conflict resolution
    Future<void> resolvePreferenceConflicts()
    Future<void> resolveReadingProgressConflicts()
    Future<void> resolveCharacterConflicts()
    
    // Batch processing
    Future<void> processSyncBatch<T>(List<T> items)
    
    // Error handling
    Future<void> handleSyncError(SyncError error)
}
```

### 2. Sync Queue
```dart
class SyncQueue {
    // Queue management
    Future<void> addToQueue(SyncTask task)
    Future<void> processPendingTasks()
    Future<void> retryFailedTasks()
    
    // Priority handling
    void setPriority(SyncTask task, Priority priority)
    
    // Status tracking
    Stream<SyncStatus> get syncStatus
}
```

### 3. Offline Support
```dart
class OfflineManager {
    // Offline detection
    Stream<bool> get connectivityStatus
    
    // Queue management
    Future<void> queueOfflineChanges()
    Future<void> syncOfflineChanges()
    
    // Conflict resolution
    Future<void> resolveOfflineConflicts()
}
```

## Sync Process Flow

1. **Initial Sync**
   - On app launch, check last sync timestamp
   - Pull server changes since last sync
   - Merge with local changes
   - Update local and server timestamps

2. **Continuous Sync**
   - Monitor local changes through Hive listeners
   - Queue changes for sync based on priority
   - Process sync queue based on network status
   - Handle conflicts using timestamp-based resolution

3. **Offline Handling**
   - Queue changes when offline
   - Track failed sync attempts
   - Retry on network restoration
   - Merge conflicts on reconnection

4. **Data Pruning**
   - Maintain chat history limit (200 messages)
   - Clean up old sync records
   - Archive or delete outdated data

## Error Handling

1. **Network Errors**
   - Implement exponential backoff
   - Queue failed requests
   - Notify user of sync status

2. **Conflict Resolution**
   - Use server timestamps as source of truth
   - Merge non-conflicting changes
   - Prompt user for resolution when necessary

3. **Data Validation**
   - Validate data before sync
   - Handle schema migrations
   - Sanitize user input

## Performance Considerations

1. **Batch Processing**
   - Group similar operations
   - Use bulk updates when possible
   - Implement rate limiting

2. **Data Compression**
   - Compress large text fields
   - Optimize image storage
   - Use efficient data formats

3. **Resource Usage**
   - Monitor memory usage
   - Implement cleanup routines
   - Cache frequently accessed data

## Security

1. **Data Encryption**
   - Encrypt sensitive data
   - Use secure connections
   - Implement token-based auth

2. **Access Control**
   - Implement row-level security
   - Validate user permissions
   - Audit sync operations

## Future Improvements

1. **Sync Optimization**
   - Implement delta sync
   - Add selective sync options
   - Optimize batch sizes

2. **User Experience**
   - Add sync progress indicators
   - Implement manual sync triggers
   - Add sync status notifications

3. **Data Management**
   - Add data export/import
   - Implement backup/restore
   - Add sync history 