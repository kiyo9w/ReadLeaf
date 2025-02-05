import 'package:equatable/equatable.dart';
import '../../models/user.dart' as app_models;

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final app_models.User user;

  const AuthAuthenticated(this.user);

  @override
  List<Object> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String message;

  const AuthFailure(this.message);

  @override
  List<Object> get props => [message];
}

class AuthSignUpSuccess extends AuthState {
  final app_models.User user;

  const AuthSignUpSuccess(this.user);

  @override
  List<Object> get props => [user];
}

class AuthSignInSuccess extends AuthState {
  final app_models.User user;

  const AuthSignInSuccess(this.user);

  @override
  List<Object> get props => [user];
}
