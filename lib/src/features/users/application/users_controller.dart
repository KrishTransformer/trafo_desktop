import 'package:flutter/foundation.dart';

import '../../../core/models/entity_list_query.dart';
import '../../../core/network/api_exception.dart';
import '../domain/models/user_draft.dart';
import '../domain/repositories/users_repository.dart';
import 'users_state.dart';

class UsersController extends ChangeNotifier {
  UsersController({required UsersRepository repository})
    : _repository = repository;

  final UsersRepository _repository;

  UsersState _state = const UsersState.initial();

  UsersState get state => _state;

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
      final response = await _repository.fetchUsers(
        const EntityListQuery(
          offset: 0,
          size: 10,
          sortAttribute: 'createdAt',
          sortOrder: 'ASC',
        ),
      );
      _setState(_state.copyWith(isLoading: false, users: response.data));
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          isLoading: false,
          users: const [],
          errorMessage: exception.message,
        ),
      );
    } catch (_) {
      _setState(
        _state.copyWith(
          isLoading: false,
          users: const [],
          errorMessage: 'Unable to load users.',
        ),
      );
    }
  }

  void clearErrorMessage() {
    if (_state.errorMessage.isEmpty) {
      return;
    }
    _setState(_state.copyWith(errorMessage: ''));
  }

  Future<bool> addUser({required String name, required String email}) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim();
    if (normalizedName.isEmpty || normalizedEmail.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage: 'Please fill all fields before adding a user.',
        ),
      );
      return false;
    }

    _setState(_state.copyWith(isSaving: true, errorMessage: ''));

    try {
      await _repository.createUser(
        UserDraft(name: normalizedName, email: normalizedEmail),
      );
      _setState(_state.copyWith(isSaving: false));
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
          errorMessage: 'Unable to add the user.',
        ),
      );
      return false;
    }
  }

  Future<bool> updateUser({
    required String entityId,
    required String name,
    required String email,
  }) async {
    final normalizedName = name.trim();
    final normalizedEmail = email.trim();
    if (entityId.isEmpty || normalizedName.isEmpty || normalizedEmail.isEmpty) {
      _setState(
        _state.copyWith(
          errorMessage: 'Please provide a valid name and email before saving.',
        ),
      );
      return false;
    }

    _setState(_state.copyWith(isSaving: true, errorMessage: ''));

    try {
      await _repository.updateUser(
        entityId: entityId,
        user: UserDraft(name: normalizedName, email: normalizedEmail),
      );
      _setState(_state.copyWith(isSaving: false));
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
          errorMessage: 'Unable to update the user.',
        ),
      );
      return false;
    }
  }

  Future<bool> deleteUser(String entityId) async {
    if (entityId.isEmpty) {
      return false;
    }

    _setState(_state.copyWith(isSaving: true, errorMessage: ''));

    try {
      await _repository.deleteUser(entityId);
      _setState(_state.copyWith(isSaving: false));
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
          errorMessage: 'Unable to delete the user.',
        ),
      );
      return false;
    }
  }

  void _setState(UsersState value) {
    if (_state == value) {
      return;
    }
    _state = value;
    notifyListeners();
  }
}
