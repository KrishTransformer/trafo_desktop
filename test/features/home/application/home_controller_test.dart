import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/network/api_exception.dart';
import 'package:trafo_desktop/src/core/storage/token_storage.dart';
import 'package:trafo_desktop/src/features/home/application/home_controller.dart';
import 'package:trafo_desktop/src/features/home/application/home_state.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_list_query.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_search_request.dart';
import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';
import 'package:trafo_desktop/src/features/home/domain/models/paginated_response.dart';
import 'package:trafo_desktop/src/features/home/domain/repositories/design_repository.dart';

void main() {
  test(
    'initialize loads rows and derives profile information from the token',
    () async {
      final repository = _FakeDesignRepository()
        ..fetchResponse = PaginatedResponse<DesignSummary>(
          data: <DesignSummary>[
            DesignSummary.fromJson(<String, dynamic>{
              'id': 'entity-1',
              'designId': '100k-82911',
              'twoWindings':
                  '{"kVA":100,"lowVoltage":433,"highVoltage":11000,"ez":4.5,"voltsPerTurn":3.21,"coreLoss":123,"loadLoss":456,"cost":{"capitalCost":7890},"core":{"coreDia":210,"limbHt":640,"cenDist":420}}',
              'createdAt': '2026-07-15T08:00:00.000Z',
              'updatedAt': '2026-07-15T10:00:00.000Z',
            }),
          ],
          total: 1,
        );
      final controller = HomeController(
        designRepository: repository,
        tokenStorage: _InMemoryTokenStorage(token: _jwtToken()),
      );

      await controller.initialize();

      expect(repository.fetchCalls, hasLength(1));
      expect(controller.state.profileName, 'Krish User');
      expect(controller.state.profileEmail, 'user@example.com');
      expect(controller.state.rows, hasLength(1));
      expect(controller.state.rows.first.designId, '100k-82911');
      expect(controller.state.rows.first.capacity, '100');
      expect(controller.state.rows.first.voltage, '433/11000');
      expect(controller.state.rows.first.frame, '210 x 640 x 420');
    },
  );

  test('submitSearch uses the documented designId search payload', () async {
    final repository = _FakeDesignRepository()
      ..fetchResponse = const PaginatedResponse<DesignSummary>(
        data: <DesignSummary>[],
        total: 0,
      )
      ..searchResponse = const PaginatedResponse<DesignSummary>(
        data: <DesignSummary>[],
        total: 0,
      );
    final controller = HomeController(
      designRepository: repository,
      tokenStorage: _InMemoryTokenStorage(),
    );

    await controller.initialize();
    controller.setSearchQuery('250k');
    await controller.changeSortOption(DesignSortOption.designIdAsc);
    await controller.submitSearch();

    expect(repository.searchCalls, isNotEmpty);
    final searchCall = repository.searchCalls.last;
    expect(searchCall.query.offset, 0);
    expect(searchCall.query.size, 20);
    expect(searchCall.request.toJson(), <String, dynamic>{
      'attributeName': <String>['designId'],
      'attributeValue': '250k',
      'sortAttribute': 'updatedAt',
      'sortOrder': 'DESC',
    });
  });

  test(
    'deleteSelectedDesigns deletes each selected record and reloads the list',
    () async {
      final repository = _FakeDesignRepository()
        ..fetchResponse = PaginatedResponse<DesignSummary>(
          data: <DesignSummary>[
            DesignSummary.fromJson(<String, dynamic>{
              'id': 'entity-1',
              'designId': 'A-1',
              'twoWindings': '{}',
            }),
            DesignSummary.fromJson(<String, dynamic>{
              'id': 'entity-2',
              'designId': 'A-2',
              'twoWindings': '{}',
            }),
          ],
          total: 2,
        );
      final controller = HomeController(
        designRepository: repository,
        tokenStorage: _InMemoryTokenStorage(),
      );

      await controller.initialize();
      controller.toggleSelection('entity-1');
      controller.toggleSelection('entity-2');

      final deleted = await controller.deleteSelectedDesigns();

      expect(deleted, isTrue);
      expect(repository.deletedIds, <String>['entity-1', 'entity-2']);
      expect(controller.state.selectedDesignIds, isEmpty);
      expect(repository.fetchCalls.length, 2);
    },
  );

  test('load failure surfaces an error message', () async {
    final controller = HomeController(
      designRepository: _FailingDesignRepository(),
      tokenStorage: _InMemoryTokenStorage(),
    );

    await controller.initialize();

    expect(controller.state.rows, isEmpty);
    expect(controller.state.errorMessage, 'The request timed out.');
  });

  test(
    'initialize tolerates token storage read failures and still loads designs',
    () async {
      final repository = _FakeDesignRepository()
        ..fetchResponse = PaginatedResponse<DesignSummary>(
          data: <DesignSummary>[
            DesignSummary.fromJson(<String, dynamic>{
              'id': 'entity-1',
              'designId': '100k-82911',
              'twoWindings': '{}',
            }),
          ],
          total: 1,
        );
      final controller = HomeController(
        designRepository: repository,
        tokenStorage: _ThrowingTokenStorage(),
      );

      await controller.initialize();

      expect(controller.state.profileName, 'User');
      expect(controller.state.profileEmail, 'N/A');
      expect(controller.state.rows, hasLength(1));
    },
  );
}

class _FakeDesignRepository implements DesignRepository {
  PaginatedResponse<DesignSummary> fetchResponse =
      const PaginatedResponse<DesignSummary>(data: <DesignSummary>[], total: 0);
  PaginatedResponse<DesignSummary> searchResponse =
      const PaginatedResponse<DesignSummary>(data: <DesignSummary>[], total: 0);
  final List<DesignListQuery> fetchCalls = <DesignListQuery>[];
  final List<_SearchCall> searchCalls = <_SearchCall>[];
  final List<String> deletedIds = <String>[];

  @override
  Future<void> deleteDesign(String designId) async {
    deletedIds.add(designId);
  }

  @override
  Future<PaginatedResponse<DesignSummary>> fetchDesigns(
    DesignListQuery query,
  ) async {
    fetchCalls.add(query);
    return fetchResponse;
  }

  @override
  Future<PaginatedResponse<DesignSummary>> searchDesigns({
    required DesignListQuery query,
    required DesignSearchRequest request,
  }) async {
    searchCalls.add(_SearchCall(query: query, request: request));
    return searchResponse;
  }
}

class _FailingDesignRepository extends _FakeDesignRepository {
  @override
  Future<PaginatedResponse<DesignSummary>> fetchDesigns(
    DesignListQuery query,
  ) async {
    throw const ApiException(
      type: ApiExceptionType.timeout,
      message: 'The request timed out.',
    );
  }
}

class _SearchCall {
  const _SearchCall({required this.query, required this.request});

  final DesignListQuery query;
  final DesignSearchRequest request;
}

class _InMemoryTokenStorage implements TokenStorage {
  _InMemoryTokenStorage({this.token});

  String? token;

  @override
  Future<void> clear() async {
    token = null;
  }

  @override
  Future<String?> read() async => token;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write(String token) async {
    this.token = token;
  }

  @override
  Future<void> writeRefreshToken(String token) async {}
}

class _ThrowingTokenStorage implements TokenStorage {
  @override
  Future<void> clear() async {}

  @override
  Future<String?> read() {
    throw Exception('Secure storage read failed');
  }

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> writeRefreshToken(String token) async {}
}

String _jwtToken() {
  final header = base64Url.encode(utf8.encode('{"alg":"none","typ":"JWT"}'));
  final payload = base64Url.encode(
    utf8.encode(
      '{"name":"Krish User","email":"user@example.com","preferred_username":"krish"}',
    ),
  );

  return '$header.$payload.signature';
}
