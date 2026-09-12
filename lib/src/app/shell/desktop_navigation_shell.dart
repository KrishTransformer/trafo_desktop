import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_scope.dart';
import '../../core/config/app_environment.dart';
import '../../core/presentation/app_radii.dart';
import '../../core/presentation/app_spacing.dart';
import '../../core/presentation/app_text_styles.dart';
import '../../core/presentation/loading_overlay.dart';
import '../../features/home/domain/models/design_summary.dart';
import '../router/route_paths.dart';

class DesktopNavigationShell extends StatelessWidget {
  const DesktopNavigationShell({
    required this.environment,
    required this.navigationShell,
    super.key,
  });

  final AppEnvironment environment;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final navigation = _NavigationContext.from(context);
    final destinations = _destinationsFor(navigation);
    final currentDestination = destinations.firstWhere(
      (destination) => destination.branchIndex == navigationShell.currentIndex,
      orElse: () => destinations.first,
    );
    final summary = DesignNavigationMemory.summaryFor(navigation.designId);
    final contextLabel = navigation.scope == _NavigationScope.design
        ? navigation.designId == 'new'
              ? 'New design workspace'
              : 'Ref: ${summary?.designId ?? navigation.designId} | ID: ${navigation.designId}'
        : 'Workspace';

    return Scaffold(
      drawer: _ShellDrawer(
        destinations: destinations,
        currentBranchIndex: navigationShell.currentIndex,
        onDestinationSelected: (destination) =>
            _onDestinationSelected(context, destination),
      ),
      body: SafeArea(
        child: _ContentPane(
          showDrawerButton: true,
          destination: currentDestination,
          contextLabel: contextLabel,
          child: navigationShell,
        ),
      ),
    );
  }

  void _onDestinationSelected(
    BuildContext context,
    _ShellDestination destination,
  ) {
    if (destination.route == RoutePaths.home) {
      unawaited(
        AppScope.of(context).homeController.initialize(forceRefresh: true),
      );
    }
    DesignNavigationMemory._remember(destination);
    context.go(destination.route);
  }

  List<_ShellDestination> _destinationsFor(_NavigationContext navigation) {
    const home = _ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: RoutePaths.home,
      branchIndex: 0,
    );
    if (navigation.scope == _NavigationScope.home) {
      return const [home];
    }
    if (navigation.scope == _NavigationScope.administration) {
      return const [
        home,
        _ShellDestination(
          label: 'Profile',
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          route: RoutePaths.profile,
          branchIndex: 6,
        ),
        _ShellDestination(
          label: 'Users',
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          route: RoutePaths.users,
          branchIndex: 7,
        ),
        _ShellDestination(
          label: 'LOM Material Rate',
          icon: Icons.tune_outlined,
          selectedIcon: Icons.tune,
          route: RoutePaths.lomCost,
          branchIndex: 8,
        ),
      ];
    }

    final designId = navigation.designId;
    final isMulti = navigation.designType == DesignType.multiWinding;
    return [
      home,
      if (isMulti)
        _ShellDestination(
          label: 'MWdg',
          icon: Icons.account_tree_outlined,
          selectedIcon: Icons.account_tree,
          route: RoutePaths.multiWindingsDesign(designId),
          branchIndex: 1,
        )
      else
        _ShellDestination(
          label: '2Wdg',
          icon: Icons.calculate_outlined,
          selectedIcon: Icons.calculate,
          route: RoutePaths.twoWindingsDesign(designId),
          branchIndex: 2,
        ),
      _ShellDestination(
        label: 'Core',
        icon: Icons.donut_large_outlined,
        selectedIcon: Icons.donut_large,
        route: RoutePaths.coreDesign(designId),
        branchIndex: 3,
      ),
      _ShellDestination(
        label: 'Fabrication',
        icon: Icons.precision_manufacturing_outlined,
        selectedIcon: Icons.precision_manufacturing,
        route: RoutePaths.fabricationDesign(designId),
        branchIndex: 4,
      ),
      _ShellDestination(
        label: 'Files',
        icon: Icons.folder_open_outlined,
        selectedIcon: Icons.folder_open,
        route: RoutePaths.filesDesign(designId),
        branchIndex: 5,
      ),
    ];
  }
}

class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({
    required this.destinations,
    required this.currentBranchIndex,
    required this.onDestinationSelected,
  });

  final List<_ShellDestination> destinations;
  final int currentBranchIndex;
  final ValueChanged<_ShellDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: AppSpacing.sidebarWidth,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trafo Desktop',
                    style: AppTextStyles.pageTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Navigation',
                    style: AppTextStyles.muted(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final destination in destinations)
                    _DrawerDestinationTile(
                      destination: destination,
                      selected: destination.branchIndex == currentBranchIndex,
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(destination);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentPane extends StatelessWidget {
  const _ContentPane({
    required this.child,
    required this.showDrawerButton,
    required this.destination,
    required this.contextLabel,
  });

  final Widget child;
  final bool showDrawerButton;
  final _ShellDestination destination;
  final String contextLabel;

  @override
  Widget build(BuildContext context) {
    final shell = context
        .findAncestorWidgetOfExactType<DesktopNavigationShell>()!;
    return Column(
      children: [
        Container(
          height: AppSpacing.topBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              if (showDrawerButton)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: Builder(
                    builder: (context) {
                      return IconButton(
                        tooltip: 'Open navigation',
                        onPressed: Scaffold.of(context).openDrawer,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.menu, size: 20),
                      );
                    },
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      destination.label,
                      style: AppTextStyles.sectionTitle(context),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      contextLabel,
                      style: AppTextStyles.muted(context),
                    ),
                  ],
                ),
              ),
              _EnvironmentChip(flavor: shell.environment.flavor),
            ],
          ),
        ),
        Expanded(
          child: LoadingOverlay(
            isLoading: false,
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class _DrawerDestinationTile extends StatelessWidget {
  const _DrawerDestinationTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _ShellDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
        minLeadingWidth: 28,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        selected: selected,
        selectedTileColor: theme.colorScheme.primaryContainer,
        selectedColor: theme.colorScheme.primary,
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.control),
        leading: Icon(
          selected ? destination.selectedIcon : destination.icon,
          size: 18,
        ),
        title: Text(
          destination.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EnvironmentChip extends StatelessWidget {
  const _EnvironmentChip({required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    final label = switch (flavor) {
      AppFlavor.development => 'Development',
      AppFlavor.production => 'Production',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppRadii.pillRadius,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ShellDestination {
  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.route,
    required this.branchIndex,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
  final int branchIndex;
}

enum _NavigationScope { home, design, administration }

class _NavigationContext {
  const _NavigationContext({
    required this.scope,
    required this.designId,
    required this.designType,
  });

  final _NavigationScope scope;
  final String designId;
  final DesignType designType;

  factory _NavigationContext.from(BuildContext context) {
    final state = GoRouterState.of(context);
    final path = state.uri.path;
    final scope = switch (path) {
      RoutePaths.home => _NavigationScope.home,
      RoutePaths.profile ||
      RoutePaths.users ||
      RoutePaths.lomCost => _NavigationScope.administration,
      _ => _NavigationScope.design,
    };
    final designId = _designIdFromPath(path);
    final typeFromRoute = path.startsWith(RoutePaths.multiWindings)
        ? DesignType.multiWinding
        : path.startsWith(RoutePaths.twoWindings)
        ? DesignType.twoWinding
        : null;
    final summaryFromState = state.extra is DesignSummary
        ? state.extra! as DesignSummary
        : null;
    final typeFromSummary = summaryFromState?.type;
    final designType =
        typeFromRoute ??
        typeFromSummary ??
        DesignNavigationMemory.typeFor(designId) ??
        DesignType.twoWinding;

    if (scope == _NavigationScope.design) {
      DesignNavigationMemory.rememberContext(designId, designType);
      if (summaryFromState != null) {
        DesignNavigationMemory.rememberSummary(summaryFromState);
      }
    }

    return _NavigationContext(
      scope: scope,
      designId: designId,
      designType: designType,
    );
  }

  static String _designIdFromPath(String path) {
    for (final root in <String>[
      RoutePaths.twoWindings,
      RoutePaths.multiWindings,
      RoutePaths.core,
      RoutePaths.fabrication,
      RoutePaths.files,
    ]) {
      if (path.startsWith('$root/')) {
        return Uri.decodeComponent(
          path.substring(root.length + 1).split('/').first,
        );
      }
    }
    return 'new';
  }
}

class DesignNavigationMemory {
  static int _twoWindingDraftRevision = 0;
  static int _multiWindingDraftRevision = 0;

  static int get twoWindingDraftRevision => _twoWindingDraftRevision;
  static int get multiWindingDraftRevision => _multiWindingDraftRevision;

  // An explicit New Design action starts a new draft even when the shell
  // still has the previous /2windings/new page mounted in its indexed stack.
  static int beginNewTwoWindingDesign() {
    _twoWindingDraftRevision++;
    _summariesByDesignId.remove('new');
    rememberContext('new', DesignType.twoWinding);
    return _twoWindingDraftRevision;
  }

  static int beginNewMultiWindingDesign() {
    _multiWindingDraftRevision++;
    _summariesByDesignId.remove('new');
    rememberContext('new', DesignType.multiWinding);
    return _multiWindingDraftRevision;
  }

  static final Map<String, DesignType> _typesByDesignId =
      <String, DesignType>{};
  static final Map<String, DesignSummary> _summariesByDesignId =
      <String, DesignSummary>{};

  static DesignType? typeFor(String designId) => _typesByDesignId[designId];

  static DesignSummary? summaryFor(String designId) =>
      _summariesByDesignId[designId];

  static void rememberSummary(DesignSummary summary) {
    _summariesByDesignId[summary.id] = summary;
    rememberContext(summary.id, summary.type);
  }

  static void rememberContext(String designId, DesignType designType) {
    _typesByDesignId[designId] = designType;
  }

  static void _remember(_ShellDestination destination) {
    final route = destination.route;
    if (destination.branchIndex != 1 && destination.branchIndex != 2) {
      return;
    }
    final designId = _NavigationContext._designIdFromPath(route);
    rememberContext(
      designId,
      destination.branchIndex == 1
          ? DesignType.multiWinding
          : DesignType.twoWinding,
    );
  }
}
