import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_environment.dart';
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

    return Scaffold(
      drawer: _ShellDrawer(
        destinations: destinations,
        currentBranchIndex: navigationShell.currentIndex,
        onDestinationSelected: (destination) =>
            _onDestinationSelected(context, destination),
      ),
      body: SafeArea(
        child: _ContentPane(
          child: navigationShell,
          showDrawerButton: true,
          destination: currentDestination,
        ),
      ),
    );
  }

  void _onDestinationSelected(
    BuildContext context,
    _ShellDestination destination,
  ) {
    _DesignNavigationMemory.remember(destination);
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
        _ShellDestination(label: 'Profile', icon: Icons.person_outline, selectedIcon: Icons.person, route: RoutePaths.profile, branchIndex: 6),
        _ShellDestination(label: 'Users', icon: Icons.people_outline, selectedIcon: Icons.people, route: RoutePaths.users, branchIndex: 7),
        _ShellDestination(label: 'LOM Material Rate', icon: Icons.tune_outlined, selectedIcon: Icons.tune, route: RoutePaths.lomCost, branchIndex: 8),
      ];
    }

    final designId = navigation.designId;
    final isMulti = navigation.designType == DesignType.multiWinding;
    return [
      home,
      if (isMulti)
        _ShellDestination(label: 'MWdg', icon: Icons.account_tree_outlined, selectedIcon: Icons.account_tree, route: RoutePaths.multiWindingsDesign(designId), branchIndex: 1)
      else
        _ShellDestination(label: '2Wdg', icon: Icons.calculate_outlined, selectedIcon: Icons.calculate, route: RoutePaths.twoWindingsDesign(designId), branchIndex: 2),
      _ShellDestination(label: 'Core', icon: Icons.donut_large_outlined, selectedIcon: Icons.donut_large, route: RoutePaths.coreDesign(designId), branchIndex: 3),
      if (!isMulti)
        _ShellDestination(label: 'Fabrication', icon: Icons.precision_manufacturing_outlined, selectedIcon: Icons.precision_manufacturing, route: RoutePaths.fabricationDesign(designId), branchIndex: 4),
      _ShellDestination(label: 'Files', icon: Icons.folder_open_outlined, selectedIcon: Icons.folder_open, route: RoutePaths.filesDesign(designId), branchIndex: 5),
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
    final theme = Theme.of(context);

    return Drawer(
      width: 248,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trafo Desktop',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Navigation',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
  const _ContentPane({required this.child, required this.showDrawerButton, required this.destination});

  final Widget child;
  final bool showDrawerButton;
  final _ShellDestination destination;

  @override
  Widget build(BuildContext context) {
    final shell = context
        .findAncestorWidgetOfExactType<DesktopNavigationShell>()!;
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 18),
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
                  padding: const EdgeInsets.only(right: 10),
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
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      destination.route,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: ListTile(
        onTap: onTap,
        dense: true,
        visualDensity: VisualDensity.compact,
        selected: selected,
        selectedTileColor: theme.colorScheme.primaryContainer,
        selectedColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        leading: Icon(
          selected ? destination.selectedIcon : destination.icon,
          size: 20,
        ),
        title: Text(
          destination.label,
          style: theme.textTheme.bodyMedium?.copyWith(
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
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSecondaryContainer,
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
      RoutePaths.profile || RoutePaths.users || RoutePaths.lomCost =>
        _NavigationScope.administration,
      _ => _NavigationScope.design,
    };
    final designId = _designIdFromPath(path);
    final typeFromRoute = path.startsWith(RoutePaths.multiWindings)
        ? DesignType.multiWinding
        : path.startsWith(RoutePaths.twoWindings)
        ? DesignType.twoWinding
        : null;
    final typeFromSummary = state.extra is DesignSummary
        ? (state.extra! as DesignSummary).type
        : null;
    final designType =
        typeFromRoute ??
        typeFromSummary ??
        _DesignNavigationMemory.typeFor(designId) ??
        DesignType.twoWinding;

    if (scope == _NavigationScope.design) {
      _DesignNavigationMemory.rememberContext(designId, designType);
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
        return Uri.decodeComponent(path.substring(root.length + 1).split('/').first);
      }
    }
    return 'new';
  }
}

class _DesignNavigationMemory {
  static final Map<String, DesignType> _typesByDesignId =
      <String, DesignType>{};

  static DesignType? typeFor(String designId) => _typesByDesignId[designId];

  static void rememberContext(String designId, DesignType designType) {
    _typesByDesignId[designId] = designType;
  }

  static void remember(_ShellDestination destination) {
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
