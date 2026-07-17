import 'package:flutter/foundation.dart';

import '../domain/models/user_record.dart';

@immutable
class UsersState {
  const UsersState({
    required this.isInitialized,
    required this.isLoading,
    required this.isSaving,
    required this.users,
    required this.errorMessage,
  });

  const UsersState.initial()
    : isInitialized = false,
      isLoading = false,
      isSaving = false,
      users = const <UserRecord>[],
      errorMessage = '';

  final bool isInitialized;
  final bool isLoading;
  final bool isSaving;
  final List<UserRecord> users;
  final String errorMessage;

  bool get isBusy => isLoading || isSaving;

  UsersState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isSaving,
    List<UserRecord>? users,
    String? errorMessage,
  }) {
    return UsersState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      users: users ?? this.users,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
