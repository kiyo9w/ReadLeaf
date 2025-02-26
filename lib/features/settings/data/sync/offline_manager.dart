import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:rxdart/rxdart.dart';
import 'package:logging/logging.dart';
import 'sync_types.dart';
import 'sync_queue.dart';

class OfflineManager {
  final _log = Logger('OfflineManager');
  final Connectivity _connectivity = Connectivity();
  final SyncQueue _offlineQueue;
  final _connectivityController = BehaviorSubject<bool>();
  StreamSubscription? _connectivitySubscription;

  OfflineManager(this._offlineQueue) {
    _initConnectivity();
  }

  Stream<bool> get connectivityStatus => _connectivityController.stream;
  bool get isOnline => _connectivityController.value;

  void _initConnectivity() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      final isOnline = result != ConnectivityResult.none;
      _connectivityController.add(isOnline);

      if (isOnline) {
        syncOfflineChanges();
      }
    });

    // Check initial connectivity
    _connectivity.checkConnectivity().then((result) {
      _connectivityController.add(result != ConnectivityResult.none);
    });
  }

  Future<void> queueOfflineChanges(SyncTask task) async {
    try {
      // Add task to offline queue with lower priority
      await _offlineQueue.addTask(task.copyWith(
        priority: SyncPriority.low,
        timestamp: DateTime.now(),
      ));
      _log.fine('Task queued for offline sync: ${task.type}');
    } catch (e, stackTrace) {
      _log.severe('Error queueing offline task: ${task.type}', e, stackTrace);
      rethrow;
    }
  }

  Future<void> syncOfflineChanges() async {
    if (!isOnline || _offlineQueue.isEmpty) return;

    try {
      _log.info('Starting offline changes sync...');
      await _offlineQueue.processPendingTasks();
      _log.info('Offline changes sync completed');
    } catch (e, stackTrace) {
      _log.severe('Error syncing offline changes', e, stackTrace);
      rethrow;
    }
  }

  Future<void> resolveOfflineConflicts() async {
    try {
      _log.info('Starting offline conflict resolution...');
      // TODO: Implement conflict resolution strategy
      // This will be called when online sync detects conflicts
      // with changes made while offline
    } catch (e, stackTrace) {
      _log.severe('Error resolving offline conflicts', e, stackTrace);
      rethrow;
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityController.close();
  }
}
