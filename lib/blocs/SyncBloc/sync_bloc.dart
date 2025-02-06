import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../services/sync/sync_manager.dart';
import '../../services/sync/sync_types.dart';

// Events
abstract class SyncEvent extends Equatable {
  const SyncEvent();

  @override
  List<Object?> get props => [];
}

class SyncStarted extends SyncEvent {}

class SyncStopped extends SyncEvent {}

class SyncStatusChanged extends SyncEvent {
  final SyncStatus status;
  const SyncStatusChanged(this.status);

  @override
  List<Object?> get props => [status];
}

class SyncTaskAdded extends SyncEvent {
  final SyncTask task;
  const SyncTaskAdded(this.task);

  @override
  List<Object?> get props => [task];
}

class SyncRetryRequested extends SyncEvent {}

// States
abstract class SyncState extends Equatable {
  const SyncState();

  @override
  List<Object?> get props => [];
}

class SyncInitial extends SyncState {}

class SyncInProgress extends SyncState {
  final int pendingTasks;
  final SyncStatus status;

  const SyncInProgress({
    required this.pendingTasks,
    required this.status,
  });

  @override
  List<Object?> get props => [pendingTasks, status];
}

class SyncComplete extends SyncState {}

class SyncError extends SyncState {
  final String message;

  const SyncError(this.message);

  @override
  List<Object?> get props => [message];
}

class SyncOffline extends SyncState {}

// BLoC
class SyncBloc extends Bloc<SyncEvent, SyncState> {
  final SyncManager _syncManager;
  StreamSubscription? _statusSubscription;
  Timer? _periodicSync;

  SyncBloc(this._syncManager) : super(SyncInitial()) {
    on<SyncStarted>(_onSyncStarted);
    on<SyncStopped>(_onSyncStopped);
    on<SyncStatusChanged>(_onSyncStatusChanged);
    on<SyncTaskAdded>(_onSyncTaskAdded);
    on<SyncRetryRequested>(_onSyncRetryRequested);
  }

  Future<void> _onSyncStarted(
    SyncStarted event,
    Emitter<SyncState> emit,
  ) async {
    // Start periodic sync every 5 minutes
    _periodicSync?.cancel();
    _periodicSync = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _syncManager.processPendingTasks(),
    );

    // Listen to sync status changes
    _statusSubscription?.cancel();
    _statusSubscription = _syncManager.status.listen(
      (status) => add(SyncStatusChanged(status)),
    );

    emit(const SyncInProgress(
      pendingTasks: 0,
      status: SyncStatus.idle,
    ));
  }

  Future<void> _onSyncStopped(
    SyncStopped event,
    Emitter<SyncState> emit,
  ) async {
    _periodicSync?.cancel();
    _statusSubscription?.cancel();
    emit(SyncInitial());
  }

  Future<void> _onSyncStatusChanged(
    SyncStatusChanged event,
    Emitter<SyncState> emit,
  ) async {
    switch (event.status) {
      case SyncStatus.syncing:
        emit(SyncInProgress(
          pendingTasks: _syncManager.pendingTaskCount,
          status: event.status,
        ));
        break;
      case SyncStatus.completed:
        emit(SyncComplete());
        break;
      case SyncStatus.failed:
        emit(const SyncError('Sync failed'));
        break;
      case SyncStatus.offline:
        emit(SyncOffline());
        break;
      default:
        emit(SyncInProgress(
          pendingTasks: _syncManager.pendingTaskCount,
          status: event.status,
        ));
    }
  }

  Future<void> _onSyncTaskAdded(
    SyncTaskAdded event,
    Emitter<SyncState> emit,
  ) async {
    await _syncManager.addTask(event.task);
    if (state is SyncInProgress) {
      emit(SyncInProgress(
        pendingTasks: _syncManager.pendingTaskCount,
        status: (state as SyncInProgress).status,
      ));
    }
  }

  Future<void> _onSyncRetryRequested(
    SyncRetryRequested event,
    Emitter<SyncState> emit,
  ) async {
    await _syncManager.retryFailedTasks();
  }

  @override
  Future<void> close() {
    _periodicSync?.cancel();
    _statusSubscription?.cancel();
    return super.close();
  }
}
