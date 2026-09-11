import 'package:flutter/foundation.dart';

import 'design_table_row.dart';

enum DesignSortOption {
  updatedAtAsc('updatedAt', 'ASC', 'updatedAt - ASC'),
  updatedAtDesc('updatedAt', 'DESC', 'updatedAt - DESC'),
  designIdAsc('designId', 'ASC', 'designId - ASC'),
  designIdDesc('designId', 'DESC', 'designId - DESC');

  const DesignSortOption(this.sortAttribute, this.sortOrder, this.label);

  final String sortAttribute;
  final String sortOrder;
  final String label;
}

enum DesignTypeFilter {
  all('All designs'),
  twoWinding('2Wdg'),
  multiWinding('MWdg');

  const DesignTypeFilter(this.label);

  final String label;
}

@immutable
class HomeState {
  const HomeState({
    required this.isInitialized,
    required this.isLoading,
    required this.isDeleting,
    required this.searchQuery,
    required this.currentPage,
    required this.pageSize,
    required this.totalEntries,
    required this.sortOption,
    required this.designTypeFilter,
    required this.rows,
    required this.selectedDesignIds,
    required this.profileName,
    required this.profileEmail,
    required this.errorMessage,
  });

  const HomeState.initial()
    : isInitialized = false,
      isLoading = false,
      isDeleting = false,
      searchQuery = '',
      currentPage = 1,
      pageSize = 20,
      totalEntries = 0,
      sortOption = DesignSortOption.updatedAtDesc,
      designTypeFilter = DesignTypeFilter.all,
      rows = const <DesignTableRow>[],
      selectedDesignIds = const <String>{},
      profileName = 'User',
      profileEmail = 'N/A',
      errorMessage = '';

  final bool isInitialized;
  final bool isLoading;
  final bool isDeleting;
  final String searchQuery;
  final int currentPage;
  final int pageSize;
  final int totalEntries;
  final DesignSortOption sortOption;
  final DesignTypeFilter designTypeFilter;
  final List<DesignTableRow> rows;
  final Set<String> selectedDesignIds;
  final String profileName;
  final String profileEmail;
  final String errorMessage;

  bool get isBusy => isLoading || isDeleting;
  bool get isSearchActive => searchQuery.trim().isNotEmpty;
  int get totalPages {
    if (totalEntries == 0) {
      return 0;
    }

    return (totalEntries / pageSize).ceil();
  }

  bool get hasSelection => selectedDesignIds.isNotEmpty;
  int get selectionCount => selectedDesignIds.length;

  HomeState copyWith({
    bool? isInitialized,
    bool? isLoading,
    bool? isDeleting,
    String? searchQuery,
    int? currentPage,
    int? pageSize,
    int? totalEntries,
    DesignSortOption? sortOption,
    DesignTypeFilter? designTypeFilter,
    List<DesignTableRow>? rows,
    Set<String>? selectedDesignIds,
    String? profileName,
    String? profileEmail,
    String? errorMessage,
  }) {
    return HomeState(
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isDeleting: isDeleting ?? this.isDeleting,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalEntries: totalEntries ?? this.totalEntries,
      sortOption: sortOption ?? this.sortOption,
      designTypeFilter: designTypeFilter ?? this.designTypeFilter,
      rows: rows ?? this.rows,
      selectedDesignIds: selectedDesignIds ?? this.selectedDesignIds,
      profileName: profileName ?? this.profileName,
      profileEmail: profileEmail ?? this.profileEmail,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
