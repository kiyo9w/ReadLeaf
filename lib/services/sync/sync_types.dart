import 'package:equatable/equatable.dart';

/// Priority levels for sync tasks
enum SyncPriority {
  immediate,  // For critical updates that need instant sync
  high,       // For important but not critical updates
  normal,     // For regular updates
  low,        // For background updates
  batch       // For grouped updates
}

/// Status of sync operations
enum SyncStatus {
  idle,       // No sync in progress
  syncing,    // Sync in progress
  completed,  // Sync completed successfully
  failed,     // Sync failed
  offline,    // Device is offline
  conflicted  // Sync encountered conflicts
}

/// Direction of sync operation
enum SyncDirection {
  upload,     // Local to server
  download,   // Server to local
  bidirectional
}

/// Represents a single sync task
class SyncTask extends Equatable {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final SyncPriority priority;
  final SyncDirection direction;
  final int retryCount;
  final String? error;

  const SyncTask({
    required this.id,
    required this.type,
    required this.data,
    required this.timestamp,
    this.priority = SyncPriority.normal,
    this.direction = SyncDirection.bidirectional,
    this.retryCount = 0,
    this.error,
  });

  SyncTask copyWith({
    String? id,
    String? type,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    SyncPriority? priority,
    SyncDirection? direction,
    int? retryCount,
    String? error,
  }) {
    return SyncTask(
      id: id ?? this.id,
      type: type ?? this.type,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      priority: priority ?? this.priority,
      direction: direction ?? this.direction,
      retryCount: retryCount ?? this.retryCount,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        data,
        timestamp,
        priority,
        direction,
        retryCount,
        error,
      ];
}

/// Represents a sync error
class SyncError extends Error {
  final String message;
  final String code;
  final dynamic originalError;
  final SyncTask? task;

  SyncError({
    required this.message,
    required this.code,
    this.originalError,
    this.task,
  });

  @override
  String toString() => 'SyncError($code): $message';
}

/// Task types for sync operations
class SyncTaskType {
  static const String preferences = 'preferences';
  static const String readingProgress = 'reading_progress';
  static const String characterPreferences = 'character_preferences';
  static const String chatHistory = 'chat_history';
  static const String customCharacter = 'custom_character';
} 