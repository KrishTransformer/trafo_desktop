import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/core/models/paginated_response.dart';
import 'package:trafo_desktop/src/features/profile/application/profile_controller.dart';
import 'package:trafo_desktop/src/features/profile/domain/models/profile_record.dart';
import 'package:trafo_desktop/src/features/profile/domain/repositories/profile_repository.dart';
import 'package:trafo_desktop/src/features/profile/presentation/profile_screen.dart';

void main() {
  testWidgets('profile screen renders the summary view', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = ProfileController(repository: _FakeProfileRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Krish Transformer'), findsWidgets);
    expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
  });

  testWidgets('profile screen edits and saves values', (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeProfileRepository();
    final controller = ProfileController(repository: repository);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ProfileScreen(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Edit'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('First Name')), 'Updated');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      repository.savedProfile?.stringAt('primaryContact.firstName'),
      'Updated',
    );
  });
}

class _FakeProfileRepository implements ProfileRepository {
  ProfileRecord? savedProfile;

  @override
  Future<PaginatedResponse<ProfileRecord>> fetchProfiles(
    EntityListQuery query,
  ) async {
    return PaginatedResponse<ProfileRecord>(
      data: <ProfileRecord>[
        ProfileRecord.fromJson(<String, dynamic>{
          'id': 'profile-1',
          'primaryContact': <String, dynamic>{
            'firstName': 'Krish',
            'lastName': 'Transformer',
            'companyName': 'Krish Transformer',
            'designation': 'Director',
            'email': 'krish@example.com',
            'phone': '9999999999',
          },
          'Address': <String, dynamic>{
            'state': 'Maharashtra',
            'city': 'Pune',
            'address': 'Industrial Area',
            'pincode': '411001',
          },
        }),
      ],
      total: 1,
    );
  }

  @override
  Future<void> saveProfile({
    required String entityId,
    required ProfileRecord profile,
  }) async {
    savedProfile = profile;
  }
}
