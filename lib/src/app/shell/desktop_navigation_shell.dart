import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_environment.dart';
import '../../core/presentation/loading_overlay.dart';
import '../router/route_paths.dart';

class DesktopNavigationShell extends StatelessWidget {
  const DesktopNavigationShell({
    required this.environment,
    required this.navigationShell,
    super.key,
  });

  final AppEnvironment environment;
  final StatefulNavigationShell navigationShell;

  static const double _desktopBreakpoint = 1024;

  static const List<_ShellDestination> _destinations = [
    _ShellDestination(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      route: RoutePaths.home,
    ),
    _ShellDestination(
      label: '2-Windings',
      icon: Icons.calculate_outlined,
      selectedIcon: Icons.calculate,
      route: RoutePaths.twoWindings,
    ),
    _ShellDestination(
      label: 'Core',
      icon: Icons.donut_large_outlined,
      selectedIcon: Icons.donut_large,
      route: RoutePaths.core,
    ),
    _ShellDestination(
      label: 'Fabrication',
      icon: Icons.precision_manufacturing_outlined,
      selectedIcon: Icons.precision_manufacturing,
      route: RoutePaths.fabrication,
    ),
    _ShellDestination(
      label: 'Files',
      icon: Icons.folder_open_outlined,
      selectedIcon: Icons.folder_open,
      route: RoutePaths.files,
    ),
    _ShellDestination(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      route: RoutePaths.profile,
    ),
    _ShellDestination(
      label: 'Users',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
      route: RoutePaths.users,
    ),
    _ShellDestination(
      label: 'LOM Cost',
      icon: Icons.tune_outlined,
      selectedIcon: Icons.tune,
      route: RoutePaths.lomCost,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDesktopShell = constraints.maxWidth >= _desktopBreakpoint;
        final hasDrawerNavigation =
            useDesktopShell && navigationShell.currentIndex != 0;

        return Scaffold(
          drawer: hasDrawerNavigation
              ? _ShellDrawer(
                  destinations: _destinations,
                  currentIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                )
              : null,
          body: SafeArea(
            child: _ContentPane(
              child: navigationShell,
              showDrawerButton: hasDrawerNavigation,
            ),
          ),
          bottomNavigationBar: useDesktopShell
              ? null
              : NavigationBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: [
                    for (final destination in _destinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                ),
        );
      },
    );
  }

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _ShellDrawer extends StatelessWidget {
  const _ShellDrawer({
    required this.destinations,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final List<_ShellDestination> destinations;
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

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
                  for (var index = 0; index < destinations.length; index++)
                    _DrawerDestinationTile(
                      destination: destinations[index],
                      selected: index == currentIndex,
                      onTap: () {
                        Navigator.of(context).pop();
                        onDestinationSelected(index);
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
  const _ContentPane({required this.child, required this.showDrawerButton});

  final Widget child;
  final bool showDrawerButton;

  @override
  Widget build(BuildContext context) {
    final shell = context
        .findAncestorWidgetOfExactType<DesktopNavigationShell>()!;
    final destination = DesktopNavigationShell
        ._destinations[shell.navigationShell.currentIndex];

    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white,
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
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String route;
}
