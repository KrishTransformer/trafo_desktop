import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/models/entity_list_query.dart';
import 'package:trafo_desktop/src/core/models/paginated_response.dart';
import 'package:trafo_desktop/src/features/profile/application/profile_controller.dart';
import 'package:trafo_desktop/src/features/profile/domain/models/profile_record.dart';
import 'package:trafo_desktop/src/features/profile/domain/repositories/profile_repository.dart';

void main() {
  test('initialize loads the first profile record', () async {
    final controller = ProfileController(repository: _FakeProfileRepository());

    await controller.initialize();

    expect(
      controller.state.profile.stringAt('primaryContact.firstName'),
      'Krish',
    );
    expect(controller.state.entityId, 'profile-1');
  });

  test('editing updates fields and save persists the draft', () async {
    final repository = _FakeProfileRepository();
    final controller = ProfileController(repository: repository);

    await controller.initialize();
    controller.startEditing();
    controller.updateField('primaryContact.firstName', 'Transformer');

    final saved = await controller.save();

    expect(saved, isTrue);
    expect(
      repository.savedProfile?.stringAt('primaryContact.firstName'),
      'Transformer',
    );
  });

  test('cancelEditing restores the persisted profile', () async {
    final controller = ProfileController(repository: _FakeProfileRepository());

    await controller.initialize();
    controller.startEditing();
    controller.updateField('Address.city', 'Nashik');
    controller.cancelEditing();

    expect(controller.state.isEditing, isFalse);
    expect(controller.state.editableProfile.stringAt('Address.city'), 'Pune');
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
