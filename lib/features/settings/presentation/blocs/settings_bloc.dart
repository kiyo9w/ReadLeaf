import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Settings Events
abstract class SettingsEvent extends Equatable {
  const SettingsEvent();

  @override
  List<Object?> get props => [];
}

class SettingsInitialized extends SettingsEvent {}

class LoadingScreenToggled extends SettingsEvent {
  final bool value;

  const LoadingScreenToggled(this.value);

  @override
  List<Object?> get props => [value];
}

class RemindersToggled extends SettingsEvent {
  final bool value;

  const RemindersToggled(this.value);

  @override
  List<Object?> get props => [value];
}

// Settings State
class SettingsState extends Equatable {
  final bool showLoadingScreen;
  final bool remindersEnabled;

  const SettingsState({
    required this.showLoadingScreen,
    required this.remindersEnabled,
  });

  @override
  List<Object?> get props => [showLoadingScreen, remindersEnabled];

  SettingsState copyWith({
    bool? showLoadingScreen,
    bool? remindersEnabled,
  }) {
    return SettingsState(
      showLoadingScreen: showLoadingScreen ?? this.showLoadingScreen,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
    );
  }
}

// Settings Bloc
class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc()
      : super(const SettingsState(
          showLoadingScreen: true,
          remindersEnabled: true,
        )) {
    on<SettingsInitialized>(_onInitialized);
    on<LoadingScreenToggled>(_onLoadingScreenToggled);
    on<RemindersToggled>(_onRemindersToggled);

    // Initialize settings
    add(SettingsInitialized());
  }

  Future<void> _onInitialized(
      SettingsInitialized event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();

    // Load reader loading screen preference (default to true if not set)
    final showLoadingScreen = prefs.getBool('show_loading_screen') ?? true;

    // Load reading reminders preference (default to true if not set)
    final remindersEnabled = prefs.getBool('reminders_enabled') ?? true;

    emit(state.copyWith(
      showLoadingScreen: showLoadingScreen,
      remindersEnabled: remindersEnabled,
    ));
  }

  Future<void> _onLoadingScreenToggled(
      LoadingScreenToggled event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_loading_screen', event.value);

    emit(state.copyWith(
      showLoadingScreen: event.value,
    ));
  }

  Future<void> _onRemindersToggled(
      RemindersToggled event, Emitter<SettingsState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminders_enabled', event.value);

    emit(state.copyWith(
      remindersEnabled: event.value,
    ));
  }
}
