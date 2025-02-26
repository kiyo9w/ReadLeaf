import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  final String username;
  final BuildContext context;

  const AuthSignUpRequested({
    required this.email,
    required this.password,
    required this.username,
    required this.context,
  });

  @override
  List<Object?> get props => [email, password, username, context];
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object> get props => [email, password];
}

class AuthSignOutRequested extends AuthEvent {}

class AuthUserUpdated extends AuthEvent {
  final String? userId;

  const AuthUserUpdated(this.userId);

  @override
  List<Object?> get props => [userId];
}
