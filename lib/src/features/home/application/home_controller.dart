import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/models/design_list_query.dart';
import '../domain/models/design_search_request.dart';
import '../domain/repositories/design_repository.dart';
import 'design_table_row.dart';
import 'home_state.dart';

class HomeController extends ChangeNotifier {
  HomeController({
    required DesignRepository designRepository,
    required TokenStorage tokenStorage,
  }) : _designRepository = designRepository,
       _tokenStorage = tokenStorage;

  final DesignRepository _designRepository;
  final TokenStorage _tokenStorage;

  HomeState _state = const HomeState.initial();

  HomeState get state => _state;

  Future<void> initialize({bool forceRefresh = false}) async {
    if (_state.isInitialized && !forceRefresh) {
      return;
    }

    try {
      await _loadProfile();
    } catch (_) {
      _setState(
        _state.copyWith(
          profileName: 'User',
          profileEmail: 'N/A',
          errorMessage: '',
        ),
      );
    }

    await _loadDesigns(page: _state.currentPage);
  }

  void setSearchQuery(String value) {
    if (value == _state.searchQuery) {
      return;
    }

    _setState(_state.copyWith(searchQuery: value));
  }

  Future<void> submitSearch() async {
    await _loadDesigns(page: 1);
  }

  Future<void> changeSortOption(DesignSortOption option) async {
    if (option == _state.sortOption) {
      return;
    }

    await _loadDesigns(page: 1, sortOption: option);
  }

  Future<void> changeDesignTypeFilter(DesignTypeFilter filter) async {
    if (filter == _state.designTypeFilter) {
      return;
    }

    await _loadDesigns(page: 1, designTypeFilter: filter);
  }

  Future<void> goToPage(int page) async {
    final totalPages = _state.totalPages;
    if (totalPages == 0) {
      if (_state.currentPage != 1) {
        _setState(_state.copyWith(currentPage: 1));
      }
      return;
    }

    final nextPage = page.clamp(1, totalPages);
    if (nextPage == _state.currentPage) {
      return;
    }

    await _loadDesigns(page: nextPage);
  }

  Future<void> goToNextPage() async {
    await goToPage(_state.currentPage + 1);
  }

  Future<void> goToPreviousPage() async {
    await goToPage(_state.currentPage - 1);
  }

  void toggleSelection(String designId) {
    final selected = Set<String>.from(_state.selectedDesignIds);
    if (!selected.add(designId)) {
      selected.remove(designId);
    }

    _setState(_state.copyWith(selectedDesignIds: selected));
  }

  void toggleSelectAllVisible(bool selected) {
    if (selected) {
      _setState(
        _state.copyWith(
          selectedDesignIds: _state.rows.map((row) => row.id).toSet(),
        ),
      );
      return;
    }

    clearSelection();
  }

  void clearSelection() {
    if (_state.selectedDesignIds.isEmpty) {
      return;
    }

    _setState(_state.copyWith(selectedDesignIds: <String>{}));
  }

  void clearErrorMessage() {
    if (_state.errorMessage.isEmpty) {
      return;
    }

    _setState(_state.copyWith(errorMessage: ''));
  }

  Future<bool> deleteSelectedDesigns() async {
    if (_state.selectedDesignIds.isEmpty) {
      return false;
    }

    _setState(_state.copyWith(isDeleting: true, errorMessage: ''));

    try {
      for (final designId in _state.selectedDesignIds) {
        await _designRepository.deleteDesign(designId);
      }

      _setState(
        _state.copyWith(isDeleting: false, selectedDesignIds: <String>{}),
      );
      await _loadDesigns(page: _state.currentPage);
      return true;
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(isDeleting: false, errorMessage: exception.message),
      );
      return false;
    } catch (_) {
      _setState(
        _state.copyWith(
          isDeleting: false,
          errorMessage: 'Unable to delete the selected designs.',
        ),
      );
      return false;
    }
  }

  Future<void> _loadDesigns({
    required int page,
    DesignSortOption? sortOption,
    DesignTypeFilter? designTypeFilter,
  }) async {
    final nextSortOption = sortOption ?? _state.sortOption;
    final nextDesignTypeFilter = designTypeFilter ?? _state.designTypeFilter;
    final nextPage = page < 1 ? 1 : page;

    _setState(
      _state.copyWith(
        isLoading: true,
        isInitialized: true,
        currentPage: nextPage,
        sortOption: nextSortOption,
        designTypeFilter: nextDesignTypeFilter,
        errorMessage: '',
      ),
    );

    try {
      final query = DesignListQuery(
        offset: nextPage - 1,
        size: _state.pageSize,
        sortAttribute: nextSortOption.sortAttribute,
        sortOrder: nextSortOption.sortOrder,
        filters: _filtersFor(nextDesignTypeFilter),
      );

      final response = _state.searchQuery.trim().isEmpty
          ? await _designRepository.fetchDesigns(query)
          : await _designRepository.searchDesigns(
              query: query,
              request: DesignSearchRequest(
                attributeName: const <String>['designId'],
                attributeValue: _state.searchQuery.trim(),
                sortAttribute: nextSortOption.sortAttribute,
                sortOrder: nextSortOption.sortOrder,
                filters: _filtersFor(nextDesignTypeFilter),
              ),
            );

      final rows = response.data
          .map(DesignTableRow.fromSummary)
          .toList(growable: false);
      final totalPages = response.total == 0
          ? 0
          : (response.total / _state.pageSize).ceil();

      if (totalPages > 0 && nextPage > totalPages) {
        await _loadDesigns(
          page: totalPages,
          sortOption: nextSortOption,
          designTypeFilter: nextDesignTypeFilter,
        );
        return;
      }

      _setState(
        _state.copyWith(
          isLoading: false,
          currentPage: totalPages == 0 ? 1 : nextPage,
          totalEntries: response.total,
          rows: rows,
          selectedDesignIds: <String>{},
        ),
      );
    } on ApiException catch (exception) {
      _setState(
        _state.copyWith(
          isLoading: false,
          rows: const <DesignTableRow>[],
          totalEntries: 0,
          selectedDesignIds: <String>{},
          errorMessage: exception.message,
        ),
      );
    } catch (_) {
      _setState(
        _state.copyWith(
          isLoading: false,
          rows: const <DesignTableRow>[],
          totalEntries: 0,
          selectedDesignIds: <String>{},
          errorMessage: 'Unable to load the design list.',
        ),
      );
    }
  }

  Map<String, dynamic> _filtersFor(DesignTypeFilter filter) {
    return switch (filter) {
      DesignTypeFilter.all => const <String, dynamic>{},
      DesignTypeFilter.twoWinding => <String, dynamic>{
        'designType': <Object?>['two', null],
      },
      DesignTypeFilter.multiWinding => <String, dynamic>{
        'designType': <String>['multi'],
      },
    };
  }

  Future<void> _loadProfile() async {
    final token = await _tokenStorage.read();
    final profile = _decodeProfile(token);

    _setState(
      _state.copyWith(profileName: profile.name, profileEmail: profile.email),
    );
  }

  _DecodedProfile _decodeProfile(String? token) {
    if (token == null || token.isEmpty) {
      return const _DecodedProfile(name: 'User', email: 'N/A');
    }

    final segments = token.split('.');
    if (segments.length < 2) {
      return const _DecodedProfile(name: 'User', email: 'N/A');
    }

    try {
      final payload = segments[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);

      if (json is! Map<Object?, Object?>) {
        return const _DecodedProfile(name: 'User', email: 'N/A');
      }

      final data = Map<String, Object?>.from(json);

      return _DecodedProfile(
        name:
            _readFirstString(data, const <String>[
              'name',
              'preferred_username',
              'username',
            ]) ??
            'User',
        email: _readFirstString(data, const <String>['email']) ?? 'N/A',
      );
    } catch (_) {
      return const _DecodedProfile(name: 'User', email: 'N/A');
    }
  }

  String? _readFirstString(
    Map<String, Object?> data,
    List<String> candidateKeys,
  ) {
    for (final key in candidateKeys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  void _setState(HomeState nextState) {
    _state = nextState;
    notifyListeners();
  }
}

@immutable
class _DecodedProfile {
  const _DecodedProfile({required this.name, required this.email});

  final String name;
  final String email;
}
