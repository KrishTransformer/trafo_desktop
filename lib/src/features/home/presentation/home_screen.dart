import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_scope.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../../core/presentation/loading_overlay.dart';
import '../../authentication/application/auth_controller.dart';
import '../../authentication/application/auth_state.dart';
import '../application/home_controller.dart';
import '../application/home_state.dart';
import '../domain/models/design_summary.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  HomeController? _homeController;
  AuthController? _authController;
  String _lastErrorMessage = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final dependencies = AppScope.of(context);
    final nextHomeController = dependencies.homeController;
    final nextAuthController = dependencies.authController;

    if (_homeController != nextHomeController) {
      _homeController?.removeListener(_handleControllerChange);
      _homeController = nextHomeController;
      _homeController?.addListener(_handleControllerChange);
      _searchController.text = _homeController?.state.searchQuery ?? '';
      _homeController?.initialize();
    }

    _authController = nextAuthController;
  }

  @override
  void dispose() {
    _homeController?.removeListener(_handleControllerChange);
    _searchController.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final controller = _homeController;
    if (controller == null) {
      return;
    }

    final errorMessage = controller.state.errorMessage;
    if (errorMessage.isEmpty || errorMessage == _lastErrorMessage) {
      return;
    }

    _lastErrorMessage = errorMessage;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      await AppErrorDialog.show(context, message: errorMessage);
      _homeController?.clearErrorMessage();
      _lastErrorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final homeController = _homeController;
    final authController = _authController;
    if (homeController == null || authController == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[homeController, authController]),
      builder: (context, _) {
        final state = homeController.state;
        final isSigningOut =
            authController.state.operation == AuthOperation.signingOut;

        return LoadingOverlay(
          isLoading: state.isBusy || isSigningOut,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HomeHeader(
                  profileName: state.profileName,
                  profileEmail: state.profileEmail,
                  onCreateNewDesign: () => _showDesignTypeDialog(context),
                  onOpenRates: () => context.go(RoutePaths.lomCost),
                  onLogout: () => _handleLogout(authController),
                ),
                const SizedBox(height: 12),
                _SearchToolbar(
                  searchController: _searchController,
                  state: state,
                  onSearchChanged: homeController.setSearchQuery,
                  onSearchSubmitted: () => homeController.submitSearch(),
                  onSortChanged: homeController.changeSortOption,
                  onDeleteSelected: () =>
                      _confirmDeleteSelected(homeController),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Expanded(
                          child: _HomeTable(
                            state: state,
                            onToggleAll: homeController.toggleSelectAllVisible,
                            onToggleSelection: homeController.toggleSelection,
                            onOpenDesign: (design) {
                              context.go(
                                RoutePaths.twoWindingsDesign(design.id),
                                extra: design,
                              );
                            },
                          ),
                        ),
                        _PaginationFooter(
                          state: state,
                          onPageSelected: homeController.goToPage,
                          onPrevious: homeController.goToPreviousPage,
                          onNext: homeController.goToNextPage,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDesignTypeDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Design'),
          content: SizedBox(
            width: 340,
            child: _DesignTypeCard(
              badge: '2W',
              tag: 'Production Flow',
              title: '2 Winding',
              description:
                  'Start the current two-winding design workflow with the full calculation page.',
              features: const <String>[
                'Oil Type',
                'Dry Type',
                'Mechanical Design',
              ],
              cta: 'Open 2 Winding',
              onTap: () {
                Navigator.of(context).pop();
                this.context.go(RoutePaths.twoWindingsDesign('new'));
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteSelected(HomeController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete selected designs?'),
          content: const Text(
            'This cannot be undone and the selected records will be deleted permanently.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await controller.deleteSelectedDesigns();
    }
  }

  Future<void> _handleLogout(AuthController controller) async {
    await controller.signOut();
    if (mounted) {
      context.go(RoutePaths.login);
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.profileName,
    required this.profileEmail,
    required this.onCreateNewDesign,
    required this.onOpenRates,
    required this.onLogout,
  });

  final String profileName;
  final String profileEmail;
  final VoidCallback onCreateNewDesign;
  final VoidCallback onOpenRates;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Krish Transformer Design Software',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Browse saved designs, launch new work, and continue existing calculations.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<_SettingsAction>(
              tooltip: 'Settings',
              onSelected: (value) {
                if (value == _SettingsAction.updateRates) {
                  onOpenRates();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_SettingsAction>(
                  value: _SettingsAction.updateRates,
                  child: Text('Update Rates'),
                ),
              ],
              child: const _HeaderIconButton(icon: Icons.settings_outlined),
            ),
            FilledButton.icon(
              onPressed: onCreateNewDesign,
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Design'),
            ),
            PopupMenuButton<_ProfileAction>(
              tooltip: 'Profile',
              onSelected: (value) {
                if (value == _ProfileAction.logout) {
                  onLogout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<_ProfileAction>(
                  enabled: false,
                  height: 48,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        profileName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        profileEmail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<_ProfileAction>(
                  value: _ProfileAction.logout,
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.logout),
                    title: Text('Logout'),
                  ),
                ),
              ],
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFF1B1B1B),
                child: Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchToolbar extends StatelessWidget {
  const _SearchToolbar({
    required this.searchController,
    required this.state,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSortChanged,
    required this.onDeleteSelected,
  });

  final TextEditingController searchController;
  final HomeState state;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final ValueChanged<DesignSortOption> onSortChanged;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                onSubmitted: (_) => onSearchSubmitted(),
                decoration: InputDecoration(
                  labelText: 'Search by Des Ref.',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Search',
                    onPressed: onSearchSubmitted,
                    icon: const Icon(Icons.arrow_forward),
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<DesignSortOption>(
                initialValue: state.sortOption,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sort By',
                  prefixIcon: Icon(Icons.sort),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: DesignSortOption.values
                    .map(
                      (option) => DropdownMenuItem<DesignSortOption>(
                        value: option,
                        child: Text(option.label),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (option) {
                  if (option != null) {
                    onSortChanged(option);
                  }
                },
              ),
            ),
            if (state.hasSelection)
              FilledButton.icon(
                onPressed: onDeleteSelected,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1B1B1B),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text('Delete Design (${state.selectionCount})'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeTable extends StatelessWidget {
  const _HomeTable({
    required this.state,
    required this.onToggleAll,
    required this.onToggleSelection,
    required this.onOpenDesign,
  });

  final HomeState state;
  final ValueChanged<bool> onToggleAll;
  final ValueChanged<String> onToggleSelection;
  final ValueChanged<DesignSummary> onOpenDesign;

  @override
  Widget build(BuildContext context) {
    if (!state.isLoading && state.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            state.isSearchActive
                ? 'No saved designs matched the current reference search.'
                : 'No saved designs are available yet.',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final minTableWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 16
            ? constraints.maxWidth - 16
            : 0.0;

        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minTableWidth),
                child: DataTable(
                  showCheckboxColumn: true,
                  onSelectAll: (selected) => onToggleAll(selected ?? false),
                  columns: const [
                    DataColumn(label: Text('DATE')),
                    DataColumn(label: Text('DESIGN REF.')),
                    DataColumn(label: Text('CAPACITY(kVA)')),
                    DataColumn(label: Text('VOLTAGE')),
                    DataColumn(label: Text('IMPEDANCE')),
                    DataColumn(label: Text('FRAME')),
                    DataColumn(label: Text('VOLTS/TURN')),
                    DataColumn(label: Text('CORE/LOAD LOSS')),
                    DataColumn(label: Text('COST(Rs)')),
                  ],
                  rows: state.rows
                      .map((row) {
                        final isSelected = state.selectedDesignIds.contains(
                          row.id,
                        );

                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (_) => onToggleSelection(row.id),
                          cells: [
                            DataCell(Text(row.displayDate)),
                            DataCell(
                              InkWell(
                                onTap: () => onOpenDesign(row.source),
                                child: Text(
                                  row.designId,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ),
                            ),
                            DataCell(Text(row.capacity)),
                            DataCell(Text(row.voltage)),
                            DataCell(Text(row.impedance)),
                            DataCell(Text(row.frame)),
                            DataCell(Text(row.voltsPerTurn)),
                            DataCell(Text(row.losses)),
                            DataCell(Text(row.cost)),
                          ],
                        );
                      })
                      .toList(growable: false),
                  headingRowColor: WidgetStatePropertyAll<Color>(
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  checkboxHorizontalMargin: 12,
                  columnSpacing: 16,
                  horizontalMargin: 12,
                  dataRowMinHeight: 44,
                  dataRowMaxHeight: 44,
                  headingRowHeight: 40,
                  dividerThickness: 0.6,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.state,
    required this.onPageSelected,
    required this.onPrevious,
    required this.onNext,
  });

  final HomeState state;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final pages = _visiblePages(
      currentPage: state.currentPage,
      totalPages: state.totalPages,
    );
    final totalEntries = state.totalEntries;
    final startEntry = totalEntries == 0
        ? 0
        : ((state.currentPage - 1) * state.pageSize) + 1;
    final endEntry = totalEntries == 0
        ? 0
        : (state.currentPage * state.pageSize).clamp(0, totalEntries);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 8,
        children: [
          Text(
            'Showing $startEntry to $endEntry out of $totalEntries entries',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: state.currentPage > 1 ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
              ),
              for (final page in pages) ...[
                if (page == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Text(
                      '...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: OutlinedButton(
                      onPressed: () => onPageSelected(page),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                        backgroundColor: page == state.currentPage
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                      ),
                      child: Text(
                        '$page',
                        style: TextStyle(
                          fontWeight: page == state.currentPage
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
              IconButton(
                tooltip: 'Next page',
                onPressed:
                    state.totalPages > 0 && state.currentPage < state.totalPages
                    ? onNext
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<int?> _visiblePages({
    required int currentPage,
    required int totalPages,
  }) {
    if (totalPages <= 0) {
      return const <int?>[];
    }

    const maxVisiblePages = 5;
    final halfVisiblePages = maxVisiblePages ~/ 2;
    var startPage = currentPage - halfVisiblePages;
    if (startPage < 1) {
      startPage = 1;
    }

    var endPage = startPage + maxVisiblePages - 1;
    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = (endPage - maxVisiblePages + 1).clamp(1, totalPages);
    }

    final pages = <int?>[];

    if (startPage > 1) {
      pages.add(1);
      if (startPage > 2) {
        pages.add(null);
      }
    }

    for (var page = startPage; page <= endPage; page++) {
      pages.add(page);
    }

    if (endPage < totalPages) {
      if (endPage < totalPages - 1) {
        pages.add(null);
      }
      pages.add(totalPages);
    }

    return pages;
  }
}

class _DesignTypeCard extends StatelessWidget {
  const _DesignTypeCard({
    required this.badge,
    required this.tag,
    required this.title,
    required this.description,
    required this.features,
    required this.cta,
    required this.onTap,
  });

  final String badge;
  final String tag;
  final String title;
  final String description;
  final List<String> features;
  final String cta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1B1B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: features
                  .map(
                    (feature) => Chip(
                      label: Text(feature),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            Text(
              cta,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

enum _SettingsAction { updateRates }

enum _ProfileAction { logout }
