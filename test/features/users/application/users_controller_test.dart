import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/core/models/paginated_response.dart';
import 'package:trafo_desktop/src/core/network/api_exception.dart';
import 'package:trafo_desktop/src/features/users/application/users_controller.dart';
import 'package:trafo_desktop/src/features/users/domain/models/user_draft.dart';
import 'package:trafo_desktop/src/features/users/domain/models/user_record.dart';
import 'package:trafo_desktop/src/features/users/domain/repositories/users_repository.dart';

void main() {
  test('initialize loads users', () async {
    final controller = UsersController(repository: _FakeUsersRepository());

    await controller.initialize();

    expect(controller.state.users, hasLength(2));
    expect(controller.state.users.first.name, 'Krish');
  });

  test('addUser validates and persists a record', () async {
    final repository = _FakeUsersRepository();
    final controller = UsersController(repository: repository);

    await controller.initialize();
    final added = await controller.addUser(
      name: 'Transformer',
      email: 'transformer@example.com',
    );

    expect(added, isTrue);
    expect(repository.createdUsers.single.toJson(), <String, dynamic>{
      'name': 'Transformer',
      'email': 'transformer@example.com',
    });
  });

  test('repository failures surface a message', () async {
    final controller = UsersController(repository: _ThrowingUsersRepository());

    await controller.initialize();

    expect(controller.state.users, isEmpty);
    expect(controller.state.errorMessage, 'Unable to load users.');
  });
}

class _FakeUsersRepository implements UsersRepository {
  final List<UserDraft> createdUsers = <UserDraft>[];

  @override
  Future<void> createUser(UserDraft user) async {
    createdUsers.add(user);
  }

  @override
  Future<void> deleteUser(String entityId) async {}

  @override
  Future<PaginatedResponse<UserRecord>> fetchUsers(
    EntityListQuery query,
  ) async {
    return PaginatedResponse<UserRecord>(
      data: const <UserRecord>[
        UserRecord(id: 'user-1', name: 'Krish', email: 'krish@example.com'),
        UserRecord(
          id: 'user-2',
          name: 'Transformer',
          email: 'transformer@example.com',
        ),
      ],
      total: 2,
    );
  }

  @override
  Future<void> updateUser({
    required String entityId,
    required UserDraft user,
  }) async {}
}

class _ThrowingUsersRepository implements UsersRepository {
  @override
  Future<void> createUser(UserDraft user) async {}

  @override
  Future<void> deleteUser(String entityId) async {}

  @override
  Future<PaginatedResponse<UserRecord>> fetchUsers(EntityListQuery query) {
    throw const ApiException(
      type: ApiExceptionType.server,
      message: 'Unable to load users.',
      statusCode: 500,
    );
  }

  @override
  Future<void> updateUser({
    required String entityId,
    required UserDraft user,
  }) async {}
}
