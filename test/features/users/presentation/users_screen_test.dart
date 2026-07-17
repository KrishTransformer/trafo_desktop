import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/core/models/paginated_response.dart';
import 'package:trafo_desktop/src/features/users/application/users_controller.dart';
import 'package:trafo_desktop/src/features/users/domain/models/user_draft.dart';
import 'package:trafo_desktop/src/features/users/domain/models/user_record.dart';
import 'package:trafo_desktop/src/features/users/domain/repositories/users_repository.dart';
import 'package:trafo_desktop/src/features/users/presentation/users_screen.dart';

void main() {
  testWidgets('users screen renders the admin table', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = UsersController(repository: _FakeUsersRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UsersScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Krish'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add User'), findsOneWidget);
  });

  testWidgets('users screen adds a user', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeUsersRepository();
    final controller = UsersController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: UsersScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('users_add_name')), 'New User');
    await tester.enterText(
      find.byKey(const Key('users_add_email')),
      'new@example.com',
    );
    await tester.tap(find.byKey(const Key('users_add_submit')));
    await tester.pumpAndSettle();

    expect(repository.createdUsers.single.toJson(), <String, dynamic>{
      'name': 'New User',
      'email': 'new@example.com',
    });
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
    return const PaginatedResponse<UserRecord>(
      data: <UserRecord>[
        UserRecord(id: 'user-1', name: 'Krish', email: 'krish@example.com'),
      ],
      total: 1,
    );
  }

  @override
  Future<void> updateUser({
    required String entityId,
    required UserDraft user,
  }) async {}
}
