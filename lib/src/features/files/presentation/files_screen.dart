import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../../core/presentation/loading_overlay.dart';
import '../../home/domain/models/design_summary.dart';
import '../application/files_controller.dart';
import '../application/files_state.dart';
import '../data/repositories/http_files_design_repository.dart';
import '../data/repositories/http_files_lom_repository.dart';
import '../data/repositories/http_lom_material_repository.dart';
import '../domain/models/lom_line_item.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({
    required this.routeDesignId,
    this.initialDesignSummary,
    this.controller,
    super.key,
  });

  final String routeDesignId;
  final DesignSummary? initialDesignSummary;
  final FilesController? controller;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  FilesController? _controller;
  bool _ownsController = false;
  String _lastErrorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _specificationController =
      TextEditingController();
  final TextEditingController _unitController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  String _searchQuery = '';
  bool _showAddItemForm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final controller = widget.controller ?? _buildControllerFromScope(context);
    _ownsController = widget.controller == null;
    controller.addListener(_handleControllerChange);
    if (!controller.state.isInitialized) {
      controller.initialize(initialSummary: widget.initialDesignSummary);
    }
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChange);
    if (_ownsController) {
      _controller?.dispose();
    }
    _searchController.dispose();
    _descriptionController.dispose();
    _specificationController.dispose();
    _unitController.dispose();
    _quantityController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  FilesController _buildControllerFromScope(BuildContext context) {
    final dependencies = AppScope.of(context);
    return FilesController(
      routeId: widget.routeDesignId,
      lomRepository: HttpFilesLomRepository(dependencies.apiClient),
      lomMaterialRepository: HttpLomMaterialRepository(dependencies.apiClient),
      designRepository: HttpFilesDesignRepository(dependencies.apiClient),
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

  void _addCustomItem() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    controller.addCustomItem(
      description: _descriptionController.text,
      specification: _specificationController.text,
      unit: _unitController.text,
      quantity: _quantityController.text,
      rate: _rateController.text,
    );

    if (controller.state.errorMessage.isNotEmpty) {
      return;
    }

    _descriptionController.clear();
    _specificationController.clear();
    _unitController.clear();
    _quantityController.clear();
    _rateController.clear();
    setState(() {
      _showAddItemForm = false;
    });
  }

  Future<void> _editRate({
    required BuildContext context,
    required LomLineItem row,
    required int rowIndex,
  }) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    final rateController = TextEditingController(
      text: row.numberAt('rate').toString(),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Update Rate'),
          content: TextField(
            controller: rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Rate',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final updated = await controller.updateRate(
                  rowIndex: rowIndex,
                  rate: rateController.text,
                );
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop(updated);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    rateController.dispose();

    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rate updated.')));
    }
  }

  void _showExportPendingMessage(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label export is pending migration.')),
    );
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
            child: state.hasGenerationContext
                ? _WorkspaceView(
                    controller: controller,
                    state: state,
                    searchController: _searchController,
                    searchQuery: _searchQuery,
                    onSearchChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                    showAddItemForm: _showAddItemForm,
                    onToggleAddItemForm: () {
                      setState(() {
                        _showAddItemForm = !_showAddItemForm;
                      });
                    },
                    descriptionController: _descriptionController,
                    specificationController: _specificationController,
                    unitController: _unitController,
                    quantityController: _quantityController,
                    rateController: _rateController,
                    onAddCustomItem: _addCustomItem,
                    onEditRate: _editRate,
                    onExportPressed: _showExportPendingMessage,
                  )
                : _FilesEmptyState(routeId: widget.routeDesignId),
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
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.showAddItemForm,
    required this.onToggleAddItemForm,
    required this.descriptionController,
    required this.specificationController,
    required this.unitController,
    required this.quantityController,
    required this.rateController,
    required this.onAddCustomItem,
    required this.onEditRate,
    required this.onExportPressed,
  });

  final FilesController controller;
  final FilesState state;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final bool showAddItemForm;
  final VoidCallback onToggleAddItemForm;
  final TextEditingController descriptionController;
  final TextEditingController specificationController;
  final TextEditingController unitController;
  final TextEditingController quantityController;
  final TextEditingController rateController;
  final VoidCallback onAddCustomItem;
  final Future<void> Function({
    required BuildContext context,
    required LomLineItem row,
    required int rowIndex,
  })
  onEditRate;
  final void Function(BuildContext context, String label) onExportPressed;

  @override
  Widget build(BuildContext context) {
    final filteredRows = state.displayRows
        .asMap()
        .entries
        .where((entry) {
          if (searchQuery.isEmpty) {
            return true;
          }

          final row = entry.value;
          final haystack = <String>[
            row.stringAt('description'),
            row.stringAt('specification'),
            row.stringAt('unit'),
          ].join(' ').toLowerCase();
          return haystack.contains(searchQuery);
        })
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkspaceHeader(controller: controller, state: state),
        const SizedBox(height: 18),
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 1360),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 1020,
                        child: Column(
                          children: [
                            _CustomerCard(controller: controller, state: state),
                            const SizedBox(height: 16),
                            _DetailsCard(
                              controller: controller,
                              state: state,
                              searchController: searchController,
                              onSearchChanged: onSearchChanged,
                              filteredRows: filteredRows,
                              showAddItemForm: showAddItemForm,
                              onToggleAddItemForm: onToggleAddItemForm,
                              descriptionController: descriptionController,
                              specificationController: specificationController,
                              unitController: unitController,
                              quantityController: quantityController,
                              rateController: rateController,
                              onAddCustomItem: onAddCustomItem,
                              onEditRate: onEditRate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(
                        width: 320,
                        child: _ActionPanel(
                          state: state,
                          onExportPressed: onExportPressed,
                        ),
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

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.controller, required this.state});

  final FilesController controller;
  final FilesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final designReference = state.designId.isNotEmpty
        ? state.designId
        : state.entityId;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Files and LOM',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reference: $designReference',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: state.isBusy ? null : controller.refreshLom,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh LOM'),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: state.isBusy ? null : controller.saveDesign,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save Design'),
        ),
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.controller, required this.state});

  final FilesController controller;
  final FilesState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Customer Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: state.isCustomerEditing
                    ? 'Done editing customer'
                    : 'Edit customer',
                onPressed: () =>
                    controller.setCustomerEditing(!state.isCustomerEditing),
                icon: Icon(
                  state.isCustomerEditing ? Icons.check : Icons.edit_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CustomerField(
                  label: 'Customer Name',
                  value: state.customerName,
                  isEditing: state.isCustomerEditing,
                  onChanged: controller.updateCustomerName,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _CustomerField(
                  label: 'Customer Place',
                  value: state.customerPlace,
                  isEditing: state.isCustomerEditing,
                  onChanged: controller.updateCustomerPlace,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerField extends StatelessWidget {
  const _CustomerField({
    required this.label,
    required this.value,
    required this.isEditing,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool isEditing;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        if (isEditing)
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          )
        else
          Container(
            height: 48,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(value.isEmpty ? '-' : value),
          ),
      ],
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.controller,
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.filteredRows,
    required this.showAddItemForm,
    required this.onToggleAddItemForm,
    required this.descriptionController,
    required this.specificationController,
    required this.unitController,
    required this.quantityController,
    required this.rateController,
    required this.onAddCustomItem,
    required this.onEditRate,
  });

  final FilesController controller;
  final FilesState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<MapEntry<int, LomLineItem>> filteredRows;
  final bool showAddItemForm;
  final VoidCallback onToggleAddItemForm;
  final TextEditingController descriptionController;
  final TextEditingController specificationController;
  final TextEditingController unitController;
  final TextEditingController quantityController;
  final TextEditingController rateController;
  final VoidCallback onAddCustomItem;
  final Future<void> Function({
    required BuildContext context,
    required LomLineItem row,
    required int rowIndex,
  })
  onEditRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Details',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 280,
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AccordionSection(
            title: 'LOM',
            isExpanded: state.isLomExpanded,
            onToggle: () => controller.toggleAccordion('LOM'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '${state.displayRows.length} items',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onToggleAddItemForm,
                      icon: Icon(
                        showAddItemForm
                            ? Icons.remove_circle_outline
                            : Icons.add_circle_outline,
                      ),
                      label: Text(
                        showAddItemForm ? 'Hide Row Form' : 'Add Custom Row',
                      ),
                    ),
                  ],
                ),
                if (showAddItemForm) ...[
                  const SizedBox(height: 14),
                  _AddCustomItemForm(
                    descriptionController: descriptionController,
                    specificationController: specificationController,
                    unitController: unitController,
                    quantityController: quantityController,
                    rateController: rateController,
                    onSubmit: onAddCustomItem,
                  ),
                ],
                const SizedBox(height: 16),
                _LomTable(
                  state: state,
                  filteredRows: filteredRows,
                  onDelete: controller.deleteRow,
                  onEditRate: onEditRate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AccordionSection(
            title: 'CCC',
            isExpanded: state.isCccExpanded,
            onToggle: () => controller.toggleAccordion('CCC'),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                'Comprehensive cost calculations will appear here after the CCC workflow is migrated.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccordionSection extends StatelessWidget {
  const _AccordionSection({
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

class _AddCustomItemForm extends StatelessWidget {
  const _AddCustomItemForm({
    required this.descriptionController,
    required this.specificationController,
    required this.unitController,
    required this.quantityController,
    required this.rateController,
    required this.onSubmit,
  });

  final TextEditingController descriptionController;
  final TextEditingController specificationController;
  final TextEditingController unitController;
  final TextEditingController quantityController;
  final TextEditingController rateController;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: const Key('files_add_description'),
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: const Key('files_add_specification'),
                    controller: specificationController,
                    decoration: const InputDecoration(
                      labelText: 'Specification',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('files_add_unit'),
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unit',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('files_add_quantity'),
                    controller: quantityController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('files_add_rate'),
                    controller: rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Rate',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  key: const Key('files_add_submit'),
                  onPressed: onSubmit,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LomTable extends StatelessWidget {
  const _LomTable({
    required this.state,
    required this.filteredRows,
    required this.onDelete,
    required this.onEditRate,
  });

  final FilesState state;
  final List<MapEntry<int, LomLineItem>> filteredRows;
  final ValueChanged<int> onDelete;
  final Future<void> Function({
    required BuildContext context,
    required LomLineItem row,
    required int rowIndex,
  })
  onEditRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = filteredRows;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 890),
              child: Column(
                children: [
                  const _TableHeaderRow(),
                  if (rows.isEmpty)
                    Container(
                      height: 72,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: Text(
                        state.isLoading
                            ? 'Loading LOM items...'
                            : 'No LOM items available yet.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final entry in rows)
                      _TableDataRow(
                        displayIndex: entry.key + 1,
                        row: entry.value,
                        onDelete: entry.value.boolAt('isNew')
                            ? () => onDelete(entry.key)
                            : null,
                        onEditRate: () => onEditRate(
                          context: context,
                          row: entry.value,
                          rowIndex: entry.key,
                        ),
                      ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F9FC),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(6),
              ),
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Total Cost',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Rs. ${state.totalCost}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeaderRow extends StatelessWidget {
  const _TableHeaderRow();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xFFF4F6F8)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            _TableCell(width: 54, child: Text('S.No')),
            _TableCell(width: 180, child: Text('Description')),
            _TableCell(width: 210, child: Text('Specification')),
            _TableCell(width: 90, child: Text('Unit')),
            _TableCell(width: 100, child: Text('Quantity')),
            _TableCell(width: 120, child: Text('Rate')),
            _TableCell(width: 120, child: Text('Cost')),
            _TableCell(width: 60, child: SizedBox.shrink()),
          ],
        ),
      ),
    );
  }
}

class _TableDataRow extends StatelessWidget {
  const _TableDataRow({
    required this.displayIndex,
    required this.row,
    required this.onEditRate,
    this.onDelete,
  });

  final int displayIndex;
  final LomLineItem row;
  final VoidCallback onEditRate;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            _TableCell(width: 54, child: Text('$displayIndex')),
            _TableCell(width: 180, child: Text(row.stringAt('description'))),
            _TableCell(width: 210, child: Text(row.stringAt('specification'))),
            _TableCell(width: 90, child: Text(row.stringAt('unit'))),
            _TableCell(width: 100, child: Text('${row.numberAt('quantity')}')),
            _TableCell(
              width: 120,
              child: Row(
                children: [
                  Expanded(child: Text('${row.numberAt('rate')}')),
                  IconButton(
                    tooltip: 'Edit rate',
                    onPressed: onEditRate,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            _TableCell(width: 120, child: Text('${row.numberAt('cost')}')),
            _TableCell(
              width: 60,
              child: onDelete == null
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: 'Delete row',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      visualDensity: VisualDensity.compact,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.state, required this.onExportPressed});

  final FilesState state;
  final void Function(BuildContext context, String label) onExportPressed;

  static const List<String> _actions = <String>[
    'Des. Print Out',
    'GTP',
    'Core Assembly',
    'Core Blade',
    'LOM',
    'Tank',
    'ActivePart',
    'Conservator',
    'Lid',
    'MainAssembly_GAD',
    'Rating Plate',
    'Print All',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Document Actions',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${state.materials.length} material rates loaded',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final action in _actions) ...[
            OutlinedButton.icon(
              onPressed: () => onExportPressed(context, action),
              icon: const Icon(Icons.download_outlined),
              label: Align(
                alignment: Alignment.centerLeft,
                child: Text(action),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                alignment: Alignment.centerLeft,
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
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
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class _FilesEmptyState extends StatelessWidget {
  const _FilesEmptyState({required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  'Files and LOM',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  routeId.isEmpty
                      ? 'Open this workspace from a saved design after fabrication is available.'
                      : 'The selected design does not have the data needed to generate the files workspace yet.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
