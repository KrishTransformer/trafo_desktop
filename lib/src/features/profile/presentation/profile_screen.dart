import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../../core/presentation/loading_overlay.dart';
import '../application/profile_controller.dart';
import '../application/profile_state.dart';
import '../data/repositories/http_profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({this.controller, super.key});

  final ProfileController? controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ProfileController? _controller;
  bool _ownsController = false;
  String _lastErrorMessage = '';
  int _activeTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final controller = widget.controller ?? _buildControllerFromScope(context);
    _ownsController = widget.controller == null;
    controller.addListener(_handleControllerChange);
    controller.initialize();
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChange);
    if (_ownsController) {
      _controller?.dispose();
    }
    super.dispose();
  }

  ProfileController _buildControllerFromScope(BuildContext context) {
    final dependencies = AppScope.of(context);
    return ProfileController(
      repository: HttpProfileRepository(dependencies.apiClient),
    );
  }

  void _handleControllerChange() {
    final controller = _controller;
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
      _controller?.clearErrorMessage();
      _lastErrorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        return LoadingOverlay(
          isLoading: state.isBusy,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: state.isEditing
                ? _EditView(
                    controller: controller,
                    state: state,
                    activeTab: _activeTab,
                    onTabChanged: (value) {
                      setState(() {
                        _activeTab = value;
                      });
                    },
                  )
                : _ReadView(controller: controller, state: state),
          ),
        );
      },
    );
  }
}

class _ReadView extends StatelessWidget {
  const _ReadView({required this.controller, required this.state});

  final ProfileController controller;
  final ProfileState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = state.profile.stringAt('primaryContact.firstName');
    final lastName = state.profile.stringAt('primaryContact.lastName');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 620;
            return Flex(
              direction: stacked ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: stacked
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              children: [
                Flexible(
                  fit: stacked ? FlexFit.loose : FlexFit.tight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${state.profile.stringAt('primaryContact.designation')}, ${state.profile.stringAt('primaryContact.companyName')}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: stacked ? 0 : 16, height: stacked ? 12 : 0),
                Align(
                  alignment: stacked ? Alignment.centerRight : Alignment.center,
                  child: FilledButton.icon(
                    onPressed: controller.startEditing,
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isEmpty && lastName.isEmpty
                    ? 'Not added'
                    : '$firstName $lastName'.trim(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.profile.stringAt('primaryContact.email', fallback: 'N/A'),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                state.profile.stringAt('primaryContact.phone', fallback: 'N/A'),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 700;
              final primaryContact = _SurfaceCard(
                child: _SectionList(
                  title: 'Primary Contact',
                  rows: <MapEntry<String, String>>[
                    MapEntry('Company Name', state.profile.stringAt('primaryContact.companyName', fallback: 'N/A')),
                    MapEntry('Designation', state.profile.stringAt('primaryContact.designation', fallback: 'N/A')),
                    MapEntry('Email', state.profile.stringAt('primaryContact.email', fallback: 'N/A')),
                    MapEntry('Phone', state.profile.stringAt('primaryContact.phone', fallback: 'N/A')),
                  ],
                ),
              );
              final address = _SurfaceCard(
                child: _SectionList(
                  title: 'Address',
                  rows: <MapEntry<String, String>>[
                    MapEntry('State', state.profile.stringAt('Address.state', fallback: 'N/A')),
                    MapEntry('City', state.profile.stringAt('Address.city', fallback: 'N/A')),
                    MapEntry('Address', state.profile.stringAt('Address.address', fallback: 'N/A')),
                    MapEntry('Pincode', state.profile.stringAt('Address.pincode', fallback: 'N/A')),
                  ],
                ),
              );
              return SingleChildScrollView(
                child: stacked
                    ? Column(children: [primaryContact, const SizedBox(height: 18), address])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: primaryContact),
                          const SizedBox(width: 18),
                          Expanded(child: address),
                        ],
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EditView extends StatelessWidget {
  const _EditView({
    required this.controller,
    required this.state,
    required this.activeTab,
    required this.onTabChanged,
  });

  final ProfileController controller;
  final ProfileState state;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 620;
            return Flex(
              direction: stacked ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment:
                  stacked ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
              children: [
                Flexible(
                  fit: stacked ? FlexFit.loose : FlexFit.tight,
                  child: Text(
                    'Edit Profile',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: stacked ? 0 : 16, height: stacked ? 12 : 0),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: stacked ? WrapAlignment.end : WrapAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.cancelEditing,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                    ),
                    FilledButton.icon(
                      onPressed: controller.save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment<int>(value: 0, label: Text('Primary Contact')),
                  ButtonSegment<int>(value: 1, label: Text('Address')),
                ],
                selected: <int>{activeTab},
                onSelectionChanged: (value) {
                  onTabChanged(value.first);
                },
              ),
              const SizedBox(height: 18),
              if (activeTab == 0)
                _PrimaryContactForm(
                  state: state,
                  onChanged: controller.updateField,
                )
              else
                _AddressForm(state: state, onChanged: controller.updateField),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrimaryContactForm extends StatelessWidget {
  const _PrimaryContactForm({required this.state, required this.onChanged});

  final ProfileState state;
  final void Function(String path, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ProfileField(
          width: 280,
          label: 'First Name',
          value: state.editableProfile.stringAt('primaryContact.firstName'),
          onChanged: (value) => onChanged('primaryContact.firstName', value),
        ),
        _ProfileField(
          width: 280,
          label: 'Last Name',
          value: state.editableProfile.stringAt('primaryContact.lastName'),
          onChanged: (value) => onChanged('primaryContact.lastName', value),
        ),
        _ProfileField(
          width: 300,
          label: 'Company Name',
          value: state.editableProfile.stringAt('primaryContact.companyName'),
          onChanged: (value) => onChanged('primaryContact.companyName', value),
        ),
        _ProfileField(
          width: 260,
          label: 'Designation',
          value: state.editableProfile.stringAt('primaryContact.designation'),
          onChanged: (value) => onChanged('primaryContact.designation', value),
        ),
        _ProfileField(
          width: 320,
          label: 'Email',
          value: state.editableProfile.stringAt('primaryContact.email'),
          onChanged: (value) => onChanged('primaryContact.email', value),
        ),
        _ProfileField(
          width: 240,
          label: 'Phone',
          value: state.editableProfile.stringAt('primaryContact.phone'),
          onChanged: (value) => onChanged('primaryContact.phone', value),
        ),
      ],
    );
  }
}

class _AddressForm extends StatelessWidget {
  const _AddressForm({required this.state, required this.onChanged});

  final ProfileState state;
  final void Function(String path, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _ProfileField(
          width: 260,
          label: 'State',
          value: state.editableProfile.stringAt('Address.state'),
          onChanged: (value) => onChanged('Address.state', value),
        ),
        _ProfileField(
          width: 260,
          label: 'City',
          value: state.editableProfile.stringAt('Address.city'),
          onChanged: (value) => onChanged('Address.city', value),
        ),
        _ProfileField(
          width: 560,
          label: 'Address',
          value: state.editableProfile.stringAt('Address.address'),
          maxLines: 3,
          onChanged: (value) => onChanged('Address.address', value),
        ),
        _ProfileField(
          width: 220,
          label: 'Pincode',
          value: state.editableProfile.stringAt('Address.pincode'),
          onChanged: (value) => onChanged('Address.pincode', value),
        ),
      ],
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.width,
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final double width;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 84;
    final constrainedWidth = availableWidth < 160
        ? 160.0
        : availableWidth < width
        ? availableWidth
        : width;
    return SizedBox(
      width: constrainedWidth,
      child: TextField(
        key: Key(label),
        controller: TextEditingController(text: value)
          ..selection = TextSelection.collapsed(offset: value.length),
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({required this.title, required this.rows});

  final String title;
  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        for (final row in rows) ...[
          Text(
            row.key,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(row.value),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.05),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}
