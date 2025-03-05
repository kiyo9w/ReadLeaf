import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../../settings/data/sync/supabase_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:flutter/material.dart';
import '../../../companion_chat/data/chat_service.dart';
import 'package:read_leaf/features/library/data/book_metadata_repository.dart';
import '../../../settings/data/sync/user_preferences_service.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseService _supabaseService;
  late final StreamSubscription<AuthState> _authStateSubscription;
  AuthState? _lastKnownState;
  final ChatService _chatService;
  final BookMetadataRepository _bookMetadataRepository;
  final UserPreferencesService _userPreferencesService;

  AuthBloc(
    this._supabaseService,
    this._chatService,
    this._bookMetadataRepository,
    this._userPreferencesService,
  ) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthSignOutRequested>(_onAuthSignOutRequested);
    on<AuthUserUpdated>(_onAuthUserUpdated);

    // Initialize with cached state if available
    _initializeAuthState();

    // Listen to auth state changes
    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.distinct().map((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        return AuthUnauthenticated();
      } else if (data.session?.user != null &&
          data.event != AuthChangeEvent.tokenRefreshed) {
        return AuthLoading();
      }
      return state;
    }).listen((authState) {
      if (authState is AuthUnauthenticated) {
        add(AuthUserUpdated(null));
      } else if (authState is AuthLoading) {
        add(AuthUserUpdated(Supabase.instance.client.auth.currentUser?.id));
      }
    });
  }

  Future<void> _initializeAuthState() async {
    try {
      final user = await _supabaseService.getUserData();
      if (user != null) {
        _lastKnownState = AuthAuthenticated(user);
        emit(_lastKnownState!);
      } else {
        _lastKnownState = AuthUnauthenticated();
        emit(_lastKnownState!);
      }
    } catch (e) {
      // Ignore errors during initialization
      _lastKnownState = AuthUnauthenticated();
      emit(_lastKnownState!);
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Emit loading state only if we don't have a cached state
      if (_lastKnownState == null) {
        emit(AuthLoading());
      } else {
        // Emit cached state immediately
        emit(_lastKnownState!);
      }

      final user = await _supabaseService.getUserData();
      if (user != null) {
        _lastKnownState = AuthAuthenticated(user);
        emit(_lastKnownState!);
      } else {
        _lastKnownState = AuthUnauthenticated();
        emit(_lastKnownState!);
      }
    } catch (e) {
      // If there's an error, try to recreate user data
      try {
        final user = await _supabaseService.getUserData();
        if (user != null) {
          _lastKnownState = AuthAuthenticated(user);
          emit(_lastKnownState!);
          return;
        }
      } catch (_) {
        // If recreation fails, emit failure
      }
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      final (user, _) = await _supabaseService.signUp(
        email: event.email,
        password: event.password,
        username: event.username,
      );

      if (user != null) {
        // Wait a bit longer for the trigger to complete
        await Future.delayed(const Duration(seconds: 1));

        // Verify user data was created
        final verifiedUser = await _supabaseService.getUserData();
        if (verifiedUser != null) {
          if (event.context.mounted) {
            Navigator.of(event.context).pop();
          }
          _lastKnownState = AuthAuthenticated(verifiedUser);
          emit(_lastKnownState!);
        } else {
          emit(AuthFailure('Failed to create user profile'));
        }
      } else {
        emit(AuthFailure('Sign up failed'));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());
      final user = await _supabaseService.signIn(
        email: event.email,
        password: event.password,
      );
      if (user != null) {
        _lastKnownState = AuthAuthenticated(user);
        emit(_lastKnownState!);
      } else {
        emit(AuthFailure('Sign in failed'));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(AuthLoading());

      // Cancel existing subscription first
      await _authStateSubscription.cancel();

      // Clear all local user data
      await Future.wait([
        _chatService.clearAllData(),
        _bookMetadataRepository.clear(),
        _userPreferencesService.clear(),
      ]);

      // Sign out from Supabase
      await _supabaseService.signOut();

      // Reset the last known state
      _lastKnownState = AuthUnauthenticated();
      emit(_lastKnownState!);

      // Reinitialize auth state subscription
      _authStateSubscription = Supabase.instance.client.auth.onAuthStateChange
          .distinct()
          .map((data) {
        if (data.event == AuthChangeEvent.signedOut) {
          return AuthUnauthenticated();
        } else if (data.session?.user != null &&
            data.event != AuthChangeEvent.tokenRefreshed) {
          return AuthLoading();
        }
        return state;
      }).listen((authState) {
        if (authState is AuthUnauthenticated) {
          add(AuthUserUpdated(null));
        } else if (authState is AuthLoading) {
          add(AuthUserUpdated(Supabase.instance.client.auth.currentUser?.id));
        }
      });
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthUserUpdated(
    AuthUserUpdated event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (event.userId == null) {
        _lastKnownState = AuthUnauthenticated();
        emit(_lastKnownState!);
        return;
      }

      // Only proceed with authentication if we're not already authenticated
      if (_lastKnownState is! AuthAuthenticated) {
        emit(AuthLoading());
        final user = await _supabaseService.getUserData();
        if (user != null) {
          _lastKnownState = AuthAuthenticated(user);
          emit(_lastKnownState!);
        } else {
          _lastKnownState = AuthUnauthenticated();
          emit(_lastKnownState!);
        }
      }
    } catch (e) {
      _lastKnownState = AuthUnauthenticated();
      emit(_lastKnownState!);
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    return super.close();
  }
}
