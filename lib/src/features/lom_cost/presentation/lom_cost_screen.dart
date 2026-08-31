import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/presentation/app_form_styles.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../../core/presentation/loading_overlay.dart';
import '../../files/domain/models/lom_material_entry.dart';
import '../../files/data/repositories/http_lom_material_repository.dart';
import '../application/lom_cost_controller.dart';
import '../application/lom_cost_state.dart';
import '../data/repositories/http_lom_material_admin_repository.dart';

class LomCostScreen extends StatefulWidget {
  const LomCostScreen({this.controller, super.key});

  final LomCostController? controller;

  @override
  State<LomCostScreen> createState() => _LomCostScreenState();
}

class _LomCostScreenState extends State<LomCostScreen> {
  LomCostController? _controller;
  bool _ownsController = false;
  String _lastErrorMessage = '';
  final TextEditingController _materialNameController = TextEditingController();
  final TextEditingController _materialRateController = TextEditingController();
  String? _editingId;
  final TextEditingController _editMaterialNameController =
      TextEditingController();
  final TextEditingController _editMaterialRateController =
      TextEditingController();

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
    _materialNameController.dispose();
    _materialRateController.dispose();
    _editMaterialNameController.dispose();
    _editMaterialRateController.dispose();
    super.dispose();
  }

  LomCostController _buildControllerFromScope(BuildContext context) {
    final dependencies = AppScope.of(context);
    return LomCostController(
      materialRepository: HttpLomMaterialRepository(dependencies.apiClient),
      adminRepository: HttpLomMaterialAdminRepository(dependencies.apiClient),
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

  void _startEditing(LomMaterialEntry material) {
    setState(() {
      _editingId = material.id;
      _editMaterialNameController.text = material.materialName;
      _editMaterialRateController.text = material.materialRate.toString();
    });
  }

  void _stopEditing() {
    setState(() {
      _editingId = null;
      _editMaterialNameController.clear();
      _editMaterialRateController.clear();
    });
  }

  Future<void> _confirmResetDefaults() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reset Material Rates'),
          content: const Text(
            'This replaces the current material list with the default rate set.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apply Defaults'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final success = await controller.resetToDefaults();
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LOM rates reset to defaults.')),
      );
    }
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
            padding: AppFormStyles.pagePadding,
            child: _WorkspaceView(
              controller: controller,
              state: state,
              materialNameController: _materialNameController,
              materialRateController: _materialRateController,
              editingId: _editingId,
              editMaterialNameController: _editMaterialNameController,
              editMaterialRateController: _editMaterialRateController,
              onStartEditing: _startEditing,
              onStopEditing: _stopEditing,
              onResetDefaults: _confirmResetDefaults,
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceView extends StatelessWidget {
  const _WorkspaceView({
    required this.controller,
    required this.state,
    required this.materialNameController,
    required this.materialRateController,
    required this.editingId,
    required this.editMaterialNameController,
    required this.editMaterialRateController,
    required this.onStartEditing,
    required this.onStopEditing,
    required this.onResetDefaults,
  });

  final LomCostController controller;
  final LomCostState state;
  final TextEditingController materialNameController;
  final TextEditingController materialRateController;
  final String? editingId;
  final TextEditingController editMaterialNameController;
  final TextEditingController editMaterialRateController;
  final ValueChanged<LomMaterialEntry> onStartEditing;
  final VoidCallback onStopEditing;
  final Future<void> Function() onResetDefaults;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 720;
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
                        'LOM Material Rate',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage material names and per-unit rates used in calculations.',
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
                    onPressed: state.isBusy ? null : onResetDefaults,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Set Rates to Default'),
                  ),
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
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  _CompactWidth(
                    width: 300,
                    child: SizedBox(
                      height: AppFormStyles.controlHeight,
                      child: TextField(
                        key: const Key('lom_cost_add_name'),
                        controller: materialNameController,
                        style: AppFormStyles.controlTextStyle(context),
                        decoration: AppFormStyles.decoration(
                          context,
                          labelText: 'Material Name',
                        ),
                      ),
                    ),
                  ),
                  _CompactWidth(
                    width: 220,
                    child: SizedBox(
                      height: AppFormStyles.controlHeight,
                      child: TextField(
                        key: const Key('lom_cost_add_rate'),
                        controller: materialRateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: AppFormStyles.controlTextStyle(context),
                        decoration: AppFormStyles.decoration(
                          context,
                          labelText: 'Material Rate',
                        ),
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('lom_cost_add_submit'),
                    onPressed: state.isBusy
                        ? null
                        : () async {
                            final saved = await controller.addMaterial(
                              materialName: materialNameController.text,
                              materialRate: materialRateController.text,
                            );
                            if (saved) {
                              materialNameController.clear();
                              materialRateController.clear();
                            }
                          },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Material'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Total materials: ${state.materials.length}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: _SurfaceCard(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 860),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Material Name')),
                            DataColumn(label: Text('Material Rate (Rs.)')),
                            DataColumn(label: Text('Options')),
                          ],
                          rows: [
                            for (final material in state.materials)
                              DataRow(
                                cells: [
                                  DataCell(
                                    editingId == material.id
                                        ? SizedBox(
                                            height: AppFormStyles.controlHeight,
                                            child: TextField(
                                              controller:
                                                  editMaterialNameController,
                                              style:
                                                  AppFormStyles.controlTextStyle(
                                                    context,
                                                  ),
                                              decoration:
                                                  AppFormStyles.decoration(
                                                    context,
                                                  ),
                                            ),
                                          )
                                        : Text(material.materialName),
                                  ),
                                  DataCell(
                                    editingId == material.id
                                        ? SizedBox(
                                            height: AppFormStyles.controlHeight,
                                            child: TextField(
                                              controller:
                                                  editMaterialRateController,
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              style:
                                                  AppFormStyles.controlTextStyle(
                                                    context,
                                                  ),
                                              decoration:
                                                  AppFormStyles.decoration(
                                                    context,
                                                  ),
                                            ),
                                          )
                                        : Text('Rs. ${material.materialRate}'),
                                  ),
                                  DataCell(
                                    editingId == material.id
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Save material',
                                                onPressed: () async {
                                                  final saved = await controller
                                                      .updateMaterial(
                                                        entityId: material.id,
                                                        materialName:
                                                            editMaterialNameController
                                                                .text,
                                                        materialRate:
                                                            editMaterialRateController
                                                                .text,
                                                      );
                                                  if (saved) {
                                                    onStopEditing();
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.save_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Cancel edit',
                                                onPressed: onStopEditing,
                                                icon: const Icon(
                                                  Icons.cancel_outlined,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Edit material',
                                                onPressed: () =>
                                                    onStartEditing(material),
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: 'Delete material',
                                                onPressed: () async {
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) {
                                                          return AlertDialog(
                                                            title: const Text(
                                                              'Delete Material',
                                                            ),
                                                            content: Text(
                                                              'Delete "${material.materialName}" from the LOM rate list?',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(
                                                                      false,
                                                                    ),
                                                                child:
                                                                    const Text(
                                                                      'Cancel',
                                                                    ),
                                                              ),
                                                              FilledButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                      context,
                                                                    ).pop(true),
                                                                child:
                                                                    const Text(
                                                                      'Delete',
                                                                    ),
                                                              ),
                                                            ],
                                                          );
                                                        },
                                                      );
                                                  if (confirmed == true) {
                                                    await controller
                                                        .deleteMaterial(
                                                          material.id,
                                                        );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CompactWidth extends StatelessWidget {
  const _CompactWidth({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final availableWidth = MediaQuery.sizeOf(context).width - 84;
    final constrainedWidth = availableWidth < 160
        ? 160.0
        : availableWidth < width
        ? availableWidth
        : width;
    return SizedBox(width: constrainedWidth, child: child);
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Padding(padding: AppFormStyles.panelPadding, child: child),
    );
  }
}
