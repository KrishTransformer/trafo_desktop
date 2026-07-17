import 'package:flutter/foundation.dart';

import '../domain/models/profile_record.dart';

@immutable
class ProfileState {
  const ProfileState({
    required this.isInitialized,
    required this.isLoading,
    required this.isSaving,
    required this.isEditing,
    required this.entityId,
    required this.profile,
    required this.editableProfile,
    required this.errorMessage,
  });

  factory ProfileState.initial() {
    final initialProfile = ProfileRecord.initial();
    return ProfileState(
      isInitialized: false,
      isLoading: false,
      isSaving: false,
      isEditing: false,
      entityId: '',
      profile: initialProfile,
      editableProfile: initialProfile,
      errorMessage: '',
    );
  }

  final bool isInitialized;
  final bool isLoading;
  final bool isSaving;
  final bool isEditing;
  final String entityId;
  final ProfileRecord profile;
  final ProfileRecord editableProfile;
  final String errorMessage;

  bool get isBusy => isLoading || isSaving;

  ProfileState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isSaving,
    bool? isEditing,
    String? entityId,
    ProfileRecord? profile,
    ProfileRecord? editableProfile,
    String? errorMessage,
  }) {
    return ProfileState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isEditing: isEditing ?? this.isEditing,
      entityId: entityId ?? this.entityId,
      profile: profile ?? this.profile,
      editableProfile: editableProfile ?? this.editableProfile,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
