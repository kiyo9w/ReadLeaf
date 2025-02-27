import 'dart:async';
import 'dart:collection';
import 'package:rxdart/rxdart.dart';
import 'package:logging/logging.dart';
import 'sync_types.dart';

class SyncQueue {
  final _log = Logger('SyncQueue');
  final _queue = SplayTreeMap<String, SyncTask>();
  final _statusController = BehaviorSubject<SyncStatus>.seeded(SyncStatus.idle);
  final _maxRetries = 3;
  final _retryDelays = [
    Duration(seconds: 5), // First retry after 5 seconds
    Duration(seconds: 30), // Second retry after 30 seconds
    Duration(seconds: 120), // Third retry after 2 minutes
  ];

  Stream<SyncStatus> get status => _statusController.stream;
  SyncStatus get currentStatus => _statusController.value;
  bool get isEmpty => _queue.isEmpty;
  int get length => _queue.length;

  Future<void> addTask(SyncTask task) async {
    _log.fine('Adding task to queue: ${task.type} (${task.id})');
    // Add or update task in queue
    _queue[task.id] = task;

    // If task is immediate priority, process it right away
    if (task.priority == SyncPriority.immediate) {
      await processPendingTasks();
    }
  }

  Future<List<SyncTask>> getTasks() async {
    _log.fine('Getting all tasks from queue');
    return _queue.values.toList()
      ..sort((a, b) => a.priority.index.compareTo(b.priority.index));
  }

  Future<void> removeTask(String taskId) async {
    _log.fine('Removing task from queue: $taskId');
    _queue.remove(taskId);
  }

  Future<void> addTasks(List<SyncTask> tasks) async {
    bool hasImmediate = false;
    for (final task in tasks) {
      _queue[task.id] = task;
      if (task.priority == SyncPriority.immediate) {
        hasImmediate = true;
      }
    }

    // If any task is immediate, process queue
    if (hasImmediate) {
      await processPendingTasks();
    }
  }

  Future<void> processPendingTasks() async {
    if (currentStatus == SyncStatus.syncing) return;

    try {
      _statusController.add(SyncStatus.syncing);

      // Process tasks in priority order
      final tasks = _queue.values.toList()
        ..sort((a, b) => (a.priority.index).compareTo(b.priority.index));

      for (final task in tasks) {
        try {
          // TODO: Process task through SyncManager
          _queue.remove(task.id);
        } catch (e) {
          await _handleTaskError(task, e);
        }
      }

      _statusController.add(SyncStatus.completed);
    } catch (e) {
      _statusController.add(SyncStatus.failed);
    }
  }

  Future<void> _handleTaskError(SyncTask task, dynamic error) async {
    if (task.retryCount >= _maxRetries) {
      _log.warning(
          'Task ${task.id} has failed too many times, removing from queue');
      _queue.remove(task.id);
      return;
    }

    // Schedule retry with exponential backoff
    final delay = _retryDelays[task.retryCount];
    _log.info(
        'Scheduling retry for task ${task.id} in ${delay.inSeconds} seconds');
    await Future.delayed(delay);

    // Add task back to queue with increased retry count
    _queue[task.id] = task.copyWith(
      retryCount: task.retryCount + 1,
      error: error.toString(),
    );
  }

  Future<void> retryFailedTasks() async {
    _log.info('Retrying failed tasks');
    final failedTasks = _queue.values.where((task) => task.error != null);
    for (final task in failedTasks) {
      _queue[task.id] = task.copyWith(
        retryCount: 0,
        error: null,
        timestamp: DateTime.now(),
      );
    }
    await processPendingTasks();
  }

  void setPriority(String taskId, SyncPriority priority) {
    final task = _queue[taskId];
    if (task != null) {
      _log.fine('Setting priority for task $taskId to $priority');
      _queue[taskId] = task.copyWith(priority: priority);
    }
  }

  void clear() {
    _log.info('Clearing sync queue');
    _queue.clear();
    _statusController.add(SyncStatus.idle);
  }

  void dispose() {
    _log.info('Disposing sync queue');
    _statusController.close();
  }
}
