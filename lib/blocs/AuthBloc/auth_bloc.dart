import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import '../../services/supabase_service.dart';
import 'auth_event.dart';
import 'auth_state.dart';
import 'package:flutter/material.dart';
import '../../widgets/auth/email_verification_screen.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseService _supabaseService;
  late final StreamSubscription<AuthEvent> _authStateSubscription;
  AuthState? _lastKnownState;

  AuthBloc(this._supabaseService) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthSignInRequested>(_onAuthSignInRequested);
    on<AuthSignOutRequested>(_onAuthSignOutRequested);
    on<AuthUserUpdated>(_onAuthUserUpdated);

    // Initialize with cached state if available
    _initializeAuthState();

    // Listen to auth state changes
    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.map((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      switch (event) {
        case AuthChangeEvent.signedIn:
          return AuthUserUpdated(session?.user.id);
        case AuthChangeEvent.signedOut:
          return AuthUserUpdated(null);
        case AuthChangeEvent.userUpdated:
          return AuthUserUpdated(session?.user.id);
        default:
          return AuthUserUpdated(session?.user.id);
      }
    }).listen((event) => add(event));
  }

  Future<void> _initializeAuthState() async {
    try {
      final user = await _supabaseService.getUserData();
      if (user != null) {
        _lastKnownState = AuthAuthenticated(user);
        emit(_lastKnownState!);
      }
    } catch (e) {
      // Ignore errors during initialization
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
        if (event.context.mounted) {
          Navigator.of(event.context).pop();
        }
        _lastKnownState = AuthAuthenticated(user);
        emit(_lastKnownState!);
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
      await _supabaseService.signOut();
      _lastKnownState = AuthUnauthenticated();
      emit(_lastKnownState!);
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onAuthUserUpdated(
    AuthUserUpdated event,
    Emitter<AuthState> emit,
  ) async {
    try {
      if (event.userId != null) {
        if (_lastKnownState is! AuthAuthenticated) {
          emit(AuthLoading());
        }

        final user = await _supabaseService.getUserData();
        if (user != null) {
          _lastKnownState = AuthAuthenticated(user);
          emit(_lastKnownState!);
        } else {
          _lastKnownState = AuthUnauthenticated();
          emit(_lastKnownState!);
        }
      } else {
        _lastKnownState = AuthUnauthenticated();
        emit(_lastKnownState!);
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _authStateSubscription.cancel();
    return super.close();
  }
}
