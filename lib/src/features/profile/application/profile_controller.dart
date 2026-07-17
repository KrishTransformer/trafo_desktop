import 'package:flutter/foundation.dart';

import '../../../core/models/entity_list_query.dart';
import '../../../core/network/api_exception.dart';
import '../domain/models/profile_record.dart';
import '../domain/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({required ProfileRepository repository})
    : _repository = repository;

  final ProfileRepository _repository;

  ProfileState _state = ProfileState.initial();

  ProfileState get state => _state;

  Future<void> initialize({bool forceRefresh = false}) async {
    if (_state.isInitialized && !forceRefresh) {
      return;
    }

    await refresh();
  }

  Future<void> refresh() async {
    _setState(
      _state.copyWith(isInitialized: true, isLoading: true, errorMessage: ''),
    );

    try {
      final response = await _repository.fetchProfiles(
        const EntityListQuery(
          offset: 0,
          size: 10,
          sortAttribute: 'createdAt',
          sortOrder: 'ASC',
        ),
      );

      final profile = response.data.isEmpty
          ? ProfileRecord.initial()
          : response.data.first;
      final entityId = response.data.isEmpty ? '' : profile.stringAt('id');

      _setState(
        _state.copyWith(
          isLoading: false,
          entityId: entityId,
          profile: profile,
          editableProfile: profile,
        ),
      );
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          isLoading: false,
          profile: ProfileRecord.initial(),
          editableProfile: ProfileRecord.initial(),
          errorMessage: exception.message,
        ),
      );
    } catch (_) {
      _setState(
        _state.copyWith(
          isLoading: false,
          profile: ProfileRecord.initial(),
          editableProfile: ProfileRecord.initial(),
          errorMessage: 'Unable to load the profile.',
        ),
      );
    }
  }

  void startEditing() {
    _setState(
      _state.copyWith(
        isEditing: true,
        editableProfile: _state.profile,
        errorMessage: '',
      ),
    );
  }

  void cancelEditing() {
    _setState(
      _state.copyWith(
        isEditing: false,
        editableProfile: _state.profile,
        errorMessage: '',
      ),
    );
  }

  void updateField(String path, String value) {
    _setState(
      _state.copyWith(
        editableProfile: _state.editableProfile.copyWithPath(path, value),
        errorMessage: '',
      ),
    );
  }

  void clearErrorMessage() {
    if (_state.errorMessage.isEmpty) {
      return;
    }
    _setState(_state.copyWith(errorMessage: ''));
  }

  Future<bool> save() async {
    _setState(_state.copyWith(isSaving: true, errorMessage: ''));

    try {
      await _repository.saveProfile(
        entityId: _state.entityId,
        profile: _state.editableProfile,
      );
      _setState(
        _state.copyWith(
          isSaving: false,
          isEditing: false,
          profile: _state.editableProfile,
        ),
      );
      await refresh();
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isSaving: false, errorMessage: exception.message),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isSaving: false,
          errorMessage: 'Unable to save the profile.',
        ),
      );
      return false;
    }
  }

  void _setState(ProfileState value) {
    if (_state == value) {
      return;
    }
    _state = value;
    notifyListeners();
  }
}
