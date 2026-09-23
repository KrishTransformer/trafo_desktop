import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../app/shell/desktop_navigation_shell.dart';
import '../../../core/presentation/app_form_styles.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../../core/presentation/loading_overlay.dart';
import '../../design_workspace/data/repositories/http_core_calculation_repository.dart';
import '../../design_workspace/data/repositories/http_core_design_repository.dart';
import '../../design_workspace/domain/models/core_calculation_result.dart';
import '../../design_workspace/domain/models/core_stack_step.dart';
import '../../design_workspace/domain/models/two_winding_design.dart';
import '../../home/domain/models/design_summary.dart';
import '../../multi_winding/domain/models/multi_winding_design.dart';
import '../application/core_model_controller.dart';
import '../application/core_model_state.dart';

class CoreModelScreen extends StatefulWidget {
  const CoreModelScreen({
    required this.routeDesignId,
    this.initialDesignSummary,
    super.key,
  });

  final String routeDesignId;
  final DesignSummary? initialDesignSummary;

  @override
  State<CoreModelScreen> createState() => _CoreModelScreenState();
}

class _CoreModelScreenState extends State<CoreModelScreen> {
  CoreModelController? _controller;
  String _lastErrorMessage = '';
  String _lastRememberedCoreSignature = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final dependencies = AppScope.of(context);
    final controller = CoreModelController(
      routeId: widget.routeDesignId,
      calculationRepository: HttpCoreCalculationRepository(
        dependencies.apiClient,
      ),
      designRepository: HttpCoreDesignRepository(dependencies.apiClient),
    );
    controller.addListener(_handleControllerChange);
    controller.initialize(initialSummary: widget.initialDesignSummary);
    _controller = controller;
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChange);
    _controller?.dispose();
    super.dispose();
  }

  void _handleControllerChange() {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    _rememberCalculatedCore(controller.state);

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

  void _rememberCalculatedCore(CoreModelState state) {
    final result = state.result;
    if (result == null || state.entityId.isEmpty) {
      return;
    }

    final signature = '${state.entityId}:${identityHashCode(result)}';
    if (signature == _lastRememberedCoreSignature) {
      return;
    }

    final base =
        DesignNavigationMemory.summaryFor(state.entityId) ??
        widget.initialDesignSummary;
    DesignNavigationMemory.rememberSummary(
      DesignSummary(
        id: state.entityId,
        designId: state.designId.isNotEmpty
            ? state.designId
            : base?.designId ?? state.entityId,
        designType:
            base?.designType ??
            (state.multiWindingDesign != null ? 'multi' : 'two'),
        twoWindings: state.twoWindingDesign?.toJson() ?? base?.twoWindings,
        multiWindings:
            state.multiWindingDesign?.toJson() ?? base?.multiWindings,
        core: result.toJson(),
        fabrication: base?.fabrication,
        lom: base?.lom,
        createdAt: base?.createdAt,
        updatedAt: base?.updatedAt,
        ownerId: base?.ownerId,
      ),
    );
    _lastRememberedCoreSignature = signature;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          controller.calculate();
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): () {
          controller.calculate();
        },
      },
      child: Focus(
        autofocus: true,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final state = controller.state;
            return LoadingOverlay(
              isLoading: state.isBusy,
              child: Padding(
                padding: AppFormStyles.pagePadding,
                child: state.hasDesignContext
                    ? _WorkspaceView(controller: controller, state: state)
                    : _CoreModelEmptyState(routeId: widget.routeDesignId),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceView extends StatelessWidget {
  const _WorkspaceView({required this.controller, required this.state});

  final CoreModelController controller;
  final CoreModelState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _WorkspaceHeader(),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 980;
              final controls = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InputCard(controller: controller, state: state),
                  const SizedBox(height: 18),
                  _MetricsCard(controller: controller, state: state),
                  const SizedBox(height: 18),
                  _StepsWorkspaceCard(controller: controller, state: state),
                  const SizedBox(height: 18),
                  _ActionRow(controller: controller, state: state),
                ],
              );
              final content = DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color.fromRGBO(15, 23, 42, 0.08),
                      blurRadius: 28,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Padding(
                  padding: stacked
                      ? AppFormStyles.compactPanelPadding
                      : AppFormStyles.panelPadding,
                  child: stacked
                      ? Column(
                          children: [
                            controls,
                            const SizedBox(height: 18),
                            _DiagramCard(controller: controller, state: state),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 458, child: controls),
                            const SizedBox(width: 24),
                            Expanded(
                              child: _DiagramCard(
                                controller: controller,
                                state: state,
                              ),
                            ),
                          ],
                        ),
                ),
              );
              return Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  primary: true,
                  padding: const EdgeInsets.only(right: 4),
                  child: stacked
                      ? content
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(width: 1280, child: content),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Ctrl/Cmd + Enter',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({required this.controller, required this.state});

  final CoreModelController controller;
  final CoreModelState state;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Core Inputs',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _readOnlyField(
            label: 'Core Diameter',
            value: controller.displayValue(state.request.coreDiameter),
          ),
          _textField(
            label: 'Minimum Step Width',
            value: controller.displayValue(
              state.request.minimumStepWidth,
              fallback: '',
            ),
            onChanged: controller.setMinimumStepWidth,
          ),
          _textField(
            label: 'Number Of Steps',
            value: controller.displayValue(state.request.numberOfSteps),
            onChanged: controller.setNumberOfSteps,
          ),
          _textField(
            label: 'Fixture Step Width',
            value: controller.displayValue(
              state.request.fixtureStepWidth,
              fallback: '',
            ),
            onChanged: controller.setFixtureStepWidth,
          ),
          _dropdownField(
            context,
            label: 'Blade Type',
            value: state.request.eCoreBladeType,
            items: const <String>['CRUSI_3', 'BLADE_3', 'BLADE_4', 'CRUSI_4'],
            onChanged: controller.setBladeType,
          ),
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.controller, required this.state});

  final CoreModelController controller;
  final CoreModelState state;

  @override
  Widget build(BuildContext context) {
    final result = state.result;
    final coreAreaText = controller.displayValue(result?.coreArea);
    final designedCoreAreaText = controller.displayValue(
      result?.designedCoreArea,
    );
    final netFactor = _netFactor(
      designedCoreArea: result?.designedCoreArea,
      coreArea: result?.coreArea,
    );

    return Container(
      padding: AppFormStyles.panelPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Core Summary',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          _SummaryRow(label: 'Gross Core Area', value: '$coreAreaText sqmm'),
          _SummaryRow(
            label: 'Total Weight',
            value: '${controller.displayValue(result?.coreWeight)} kg',
          ),
          _SummaryRow(
            label: 'Flux Density',
            value:
                '${controller.displayValue(controller.revisedFluxDensityText())} T',
          ),
          _SummaryRow(
            label: 'Designed Core Area',
            value: '$designedCoreAreaText sqmm',
          ),
          _SummaryRow(label: 'Net Factor', value: netFactor),
        ],
      ),
    );
  }

  String _netFactor({
    required Object? designedCoreArea,
    required Object? coreArea,
  }) {
    final designed = double.tryParse(designedCoreArea?.toString() ?? '');
    final gross = double.tryParse(coreArea?.toString() ?? '');
    if (designed == null || gross == null || gross == 0) {
      return '-';
    }
    return (designed / gross).toStringAsFixed(3);
  }
}

class _StepsWorkspaceCard extends StatelessWidget {
  const _StepsWorkspaceCard({required this.controller, required this.state});

  final CoreModelController controller;
  final CoreModelState state;

  @override
  Widget build(BuildContext context) {
    final steps = state.result?.bldStacks ?? const <CoreStackStep>[];

    return _SectionCard(
      title: 'Step Stacking',
      child: steps.isEmpty
          ? const SizedBox(
              height: 212,
              child: _EmptyPanel(
                message:
                    'Calculate the core model to populate the stacking rows.',
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 360;
                final table = Container(
                  constraints: const BoxConstraints(minHeight: 208),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Expanded(child: Text('Step No')),
                            Expanded(child: Text('Width')),
                            Expanded(child: Text('Stack')),
                          ],
                        ),
                      ),
                      for (final step in steps)
                        InkWell(
                          key: ValueKey<String>(
                            'core-step-row-${controller.displayValue(step.stepNo)}',
                          ),
                          onTap: () => controller.selectStep(step.stepNo),
                          child: Container(
                            color:
                                state.selectedStepNo?.toString() ==
                                    step.stepNo?.toString()
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    controller.displayValue(step.stepNo),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    controller.displayValue(step.width),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    controller.displayValue(step.stack),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
                final editor = SizedBox(
                  width: stacked ? double.infinity : 138,
                  child: state.selectedStepNo == null
                      ? const _EmptyPanel(message: 'Select a row to edit.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Selected Step',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              controller.displayValue(state.selectedStepNo),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 12),
                            _narrowTextField(
                              label: 'Width',
                              value: state.editedWidth,
                              onChanged: controller.updateEditedWidth,
                            ),
                            const SizedBox(height: 12),
                            _narrowTextField(
                              label: 'Stack',
                              value: state.editedStack,
                              onChanged: controller.updateEditedStack,
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: state.isLoading
                                  ? null
                                  : controller.saveSelectedStep,
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                );
                return stacked
                    ? Column(
                        children: [table, const SizedBox(height: 16), editor],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: table),
                          const SizedBox(width: 16),
                          editor,
                        ],
                      );
              },
            ),
    );
  }
}

class _DiagramCard extends StatelessWidget {
  const _DiagramCard({required this.controller, required this.state});

  final CoreModelController controller;
  final CoreModelState state;

  @override
  Widget build(BuildContext context) {
    final steps = state.result?.bldStacks ?? const <CoreStackStep>[];

    final compact = MediaQuery.sizeOf(context).width < 720;
    return SizedBox(
      height: compact ? 430 : 640,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: AppFormStyles.panelPadding,
          child: steps.isEmpty
              ? SizedBox(
                  height: compact ? 390 : 600,
                  child: _EmptyPanel(
                    message:
                        'The diagram appears after a successful core calculation.',
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Circular Diagram',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: compact ? 350 : 560,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: Padding(
                          padding: AppFormStyles.panelPadding,
                          child: CustomPaint(
                            painter: _CoreDiagramPainter(
                              steps: steps,
                              selectedStepNo: state.selectedStepNo,
                              coreDiameter: state.request.coreDiameter,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.controller, required this.state});

  final CoreModelController controller;
  final CoreModelState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: state.result == null
              ? null
              : () => _showPreviewDialog(context),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Print Preview'),
        ),
        FilledButton.icon(
          onPressed: state.isLoading ? null : controller.calculate,
          icon: state.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.calculate_outlined),
          label: Text(state.isLoading ? 'Calculating' : 'Calculate'),
        ),
      ],
    );
  }

  Future<void> _showPreviewDialog(BuildContext context) async {
    final result = state.result;
    if (result == null) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        final size = MediaQuery.sizeOf(context);
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: size.width * 0.9,
            height: size.height * 0.92,
            child: _CorePrintPreview(
              controller: controller,
              state: state,
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
        );
      },
    );
  }
}

class _CorePrintPreview extends StatelessWidget {
  const _CorePrintPreview({
    required this.controller,
    required this.state,
    required this.onClose,
  });

  final CoreModelController controller;
  final CoreModelState state;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final data = _CorePreviewData(
      controller: controller,
      state: state,
      result: state.result!,
    );
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 10, 0),
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                IconButton(
                  tooltip: 'Close',
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PreviewHeader(data: data),
                    const SizedBox(height: 30),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        children: [
                          for (final section in data.sections) ...[
                            _PreviewStackingSection(section: section),
                            const SizedBox(height: 30),
                          ],
                          Text(
                            'Total Weight: ${data.totalWeightText} kg',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHeader extends StatelessWidget {
  const _PreviewHeader({required this.data});

  final _CorePreviewData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          Text(
            'CORE Details for Transformer',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Voltage : ${data.voltagePrimary}V / ${data.voltageSecondary}V,    Frequency : ${data.frequency}Hz',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Core Size : ${data.coreSize},    kVA : ${data.kva}',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PreviewStackingSection extends StatelessWidget {
  const _PreviewStackingSection({required this.section});

  final _PreviewSection section;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        final image = _PreviewImage(assetPath: section.assetPath);
        final table = _PreviewTable(section: section);
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 320, child: image),
              const SizedBox(height: 20),
              table,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: constraints.maxWidth * 0.22,
              height: 430,
              child: image,
            ),
            const SizedBox(width: 30),
            Expanded(child: table),
          ],
        );
      },
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: const Center(child: Icon(Icons.image_not_supported_outlined)),
        );
      },
    );
  }
}

class _PreviewTable extends StatelessWidget {
  const _PreviewTable({required this.section});

  final _PreviewSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleRows = section.rows
        .where((row) => row.any((cell) => _cellText(cell).trim().isNotEmpty))
        .toList(growable: false);

    return Table(
      border: TableBorder.all(color: theme.colorScheme.outlineVariant),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (var index = 0; index < section.headers.length; index++)
          index: const FlexColumnWidth(),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          children: [
            for (final header in section.headers)
              _PreviewCell(text: header, isHeader: true),
          ],
        ),
        for (var index = 0; index < visibleRows.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: index.isEven
                  ? theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.35,
                    )
                  : theme.colorScheme.surface,
            ),
            children: [
              for (final cell in _cellsForRow(visibleRows[index]))
                _PreviewCell(text: _cellText(cell)),
            ],
          ),
        TableRow(
          decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
          children: [
            _PreviewCell(
              text: 'Grand Total = ${section.totalWeight.toStringAsFixed(2)}',
              isHeader: true,
              alignment: TextAlign.right,
            ),
            for (var index = 1; index < section.headers.length; index++)
              const _PreviewCell(text: '', isHeader: true),
          ],
        ),
      ],
    );
  }

  List<Object?> _cellsForRow(List<Object?> row) {
    return <Object?>[
      for (var index = 0; index < section.headers.length; index++)
        index < row.length ? row[index] : '',
    ];
  }

  String _cellText(Object? value) => value?.toString() ?? '';
}

class _CorePreviewData {
  _CorePreviewData({
    required CoreModelController controller,
    required CoreModelState state,
    required CoreCalculationResult result,
  }) {
    final design = _PreviewDesign(state);
    voltagePrimary = design.firstText(<String>['primaryVoltage', 'lowVoltage']);
    voltageSecondary = design.firstText(<String>[
      'secondaryVoltage',
      'highVoltage',
    ]);
    frequency = design.firstText(<String>['frequency']);
    kva = design.firstText(<String>['kVA']);
    coreSize = <String>[
      design.firstText(<String>['core.coreDia']),
      design.firstText(<String>['core.limbHt']),
      design.firstText(<String>[
        'core.cenDist',
        'coilDimensions.centerDistance',
      ]),
    ].where((value) => value.isNotEmpty && value != '-').join(' / ');
    if (coreSize.isEmpty) {
      coreSize = '-';
    }

    final bladeType = result.bladeType.isEmpty
        ? state.request.eCoreBladeType
        : result.bladeType;
    final isFourBlade = bladeType == 'CRUSI_4' || bladeType == 'BLADE_4';
    final isThreeBlade = bladeType == 'CRUSI_3' || bladeType == 'BLADE_3';
    final weightIndex = bladeType == 'CRUSI_3' ? 5 : 4;
    final headers = bladeType == 'CRUSI_3'
        ? const <String>[
            'Step\nNo.',
            'Len A\nmm',
            'Len B\nmm',
            'Width\nmm',
            'Stack\nmm',
            'Weight\nkg',
          ]
        : const <String>[
            'Step\nNo.',
            'Length\nmm',
            'Width\nmm',
            'Stack\nmm',
            'Weight\nkg',
          ];

    final sectionInputs = <({String path, String asset})>[
      (
        path: 'centerLimbStacking',
        asset: isFourBlade
            ? 'assets/core_preview/core4.1.png'
            : 'assets/core_preview/core1.png',
      ),
      (
        path: isThreeBlade ? 'yokeStacking' : 'sideLimbStacking',
        asset: isFourBlade
            ? 'assets/core_preview/core4.2.png'
            : 'assets/core_preview/core2.png',
      ),
      (
        path: isThreeBlade ? 'sideLimbStacking' : 'doubleNotchStacking',
        asset: isFourBlade
            ? 'assets/core_preview/core4.3.png'
            : 'assets/core_preview/core3.png',
      ),
      if (isFourBlade)
        (path: 'singleNotchStacking', asset: 'assets/core_preview/core4.4.png'),
    ];

    sections = sectionInputs
        .map((input) {
          final rows = result.tableAt(input.path);
          return _PreviewSection(
            assetPath: input.asset,
            headers: headers,
            rows: rows,
            totalWeight: _totalWeight(rows, weightIndex),
          );
        })
        .toList(growable: false);

    final totalWeight = sections.fold<double>(
      0,
      (sum, section) => sum + section.totalWeight,
    );
    totalWeightText = totalWeight == 0
        ? controller.displayValue(result.coreWeight, fallback: '0')
        : totalWeight.toStringAsFixed(2);
  }

  late final String voltagePrimary;
  late final String voltageSecondary;
  late final String frequency;
  late final String kva;
  late final String coreSize;
  late final List<_PreviewSection> sections;
  late final String totalWeightText;

  double _totalWeight(List<List<Object?>> rows, int weightIndex) {
    return rows.fold<double>(0, (sum, row) {
      if (weightIndex >= row.length) {
        return sum;
      }
      return sum + (double.tryParse(row[weightIndex]?.toString() ?? '') ?? 0);
    });
  }
}

class _PreviewDesign {
  const _PreviewDesign(this.state);

  final CoreModelState state;

  String firstText(List<String> paths) {
    for (final path in paths) {
      final value =
          _readTwo(state.twoWindingDesign, path) ??
          _readMulti(state.multiWindingDesign, path);
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '-';
  }

  Object? _readTwo(TwoWindingDesign? design, String path) =>
      design?.readPath(path);

  Object? _readMulti(MultiWindingDesign? design, String path) =>
      design?.readPath(path);
}

class _PreviewSection {
  const _PreviewSection({
    required this.assetPath,
    required this.headers,
    required this.rows,
    required this.totalWeight,
  });

  final String assetPath;
  final List<String> headers;
  final List<List<Object?>> rows;
  final double totalWeight;
}

class _CoreModelEmptyState extends StatelessWidget {
  const _CoreModelEmptyState({required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: AppFormStyles.panelPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Core Model',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  routeId.isEmpty
                      ? 'Open the core model from a saved design to carry forward the current transformer and entity context.'
                      : 'This route currently expects a loaded design summary from the design workspace or design list.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                const _EmptyPanel(
                  message:
                      'Open this workspace from a saved design so the core request can inherit the current design and entity context.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoreDiagramPainter extends CustomPainter {
  _CoreDiagramPainter({
    required this.steps,
    required this.selectedStepNo,
    required this.coreDiameter,
  });

  final List<CoreStackStep> steps;
  final Object? selectedStepNo;
  final Object? coreDiameter;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 28;
    final totalStack = steps.fold<double>(
      0,
      (sum, step) => sum + (_toDouble(step.stack) ?? 0),
    );
    final maxWidth = steps.fold<double>(
      0,
      (maxValue, step) => math.max(maxValue, _toDouble(step.width) ?? 0),
    );
    final coreDiameterValue = _toDouble(coreDiameter) ?? 0;
    if (totalStack <= 0 || maxWidth <= 0 || coreDiameterValue <= 0) {
      return;
    }

    final unitWidth = radius / (maxWidth / 2);
    final unitHeight = radius / (totalStack / 2);
    final circleRadius = math.min(radius, unitWidth * (coreDiameterValue / 2));

    final circlePaint = Paint()
      ..color = const Color(0xFF183D54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final bgGridPaint = Paint()
      ..color = const Color(0xFFC5E2DF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      bgGridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      bgGridPaint,
    );

    var yAxis = 0.0;
    double previousHeight = 0.0;
    final scaledSteps = steps
        .map((step) {
          yAxis += previousHeight;
          previousHeight = ((_toDouble(step.stack) ?? 0) / 2) * unitHeight;
          return _ScaledStep(
            stepNo: step.stepNo,
            width: ((_toDouble(step.width) ?? 0) / 2) * unitWidth,
            height: previousHeight,
            yAxis: yAxis,
          );
        })
        .toList(growable: false);

    for (final transform in const [
      _QuarterTransform(-1, -1),
      _QuarterTransform(1, -1),
      _QuarterTransform(-1, 1),
      _QuarterTransform(1, 1),
    ]) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(transform.scaleX.toDouble(), transform.scaleY.toDouble());
      canvas.clipRect(Rect.fromLTWH(0, 0, radius, radius));
      canvas.drawCircle(Offset.zero, circleRadius, circlePaint);

      for (final step in scaledSteps) {
        final isSelected =
            step.stepNo?.toString() == selectedStepNo?.toString();
        final fillPaint = Paint()
          ..color = isSelected
              ? const Color(0xFFD8ECE9)
              : const Color(0xFFFBFFFE)
          ..style = PaintingStyle.fill;
        final strokePaint = Paint()
          ..color = const Color(0xFF183D54)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        final rect = Rect.fromLTWH(0, step.yAxis, step.width, step.height);
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CoreDiagramPainter oldDelegate) {
    return oldDelegate.steps != steps ||
        oldDelegate.selectedStepNo?.toString() != selectedStepNo?.toString();
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: AppFormStyles.panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PreviewCell extends StatelessWidget {
  const _PreviewCell({
    required this.text,
    this.isHeader = false,
    this.alignment = TextAlign.left,
  });

  final String text;
  final bool isHeader;
  final TextAlign alignment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        textAlign: alignment,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _QuarterTransform {
  const _QuarterTransform(this.scaleX, this.scaleY);

  final int scaleX;
  final int scaleY;
}

class _ScaledStep {
  const _ScaledStep({
    required this.stepNo,
    required this.width,
    required this.height,
    required this.yAxis,
  });

  final Object? stepNo;
  final double width;
  final double height;
  final double yAxis;
}

Widget _textField({
  required String label,
  required String value,
  required ValueChanged<String>? onChanged,
  bool readOnly = false,
}) {
  return SizedBox(
    width: 164,
    height: AppFormStyles.controlHeight,
    child: Builder(
      builder: (context) => TextFormField(
        key: ValueKey<String>('core-field-$label-$value-$readOnly'),
        initialValue: value,
        readOnly: readOnly || onChanged == null,
        onChanged: onChanged,
        style: AppFormStyles.controlTextStyle(context),
        decoration: AppFormStyles.decoration(context, labelText: label),
      ),
    ),
  );
}

Widget _narrowTextField({
  required String label,
  required String value,
  required ValueChanged<String>? onChanged,
}) {
  return SizedBox(
    width: 138,
    height: AppFormStyles.controlHeight,
    child: Builder(
      builder: (context) => TextFormField(
        key: ValueKey<String>('core-narrow-field-$label-$value'),
        initialValue: value,
        onChanged: onChanged,
        style: AppFormStyles.controlTextStyle(context),
        decoration: AppFormStyles.decoration(context, labelText: label),
      ),
    ),
  );
}

Widget _readOnlyField({required String label, required String value}) {
  return _textField(
    label: label,
    value: value,
    onChanged: null,
    readOnly: true,
  );
}

Widget _dropdownField(
  BuildContext context, {
  required String label,
  required String value,
  required List<String> items,
  required ValueChanged<String> onChanged,
}) {
  final effectiveValue = items.contains(value) ? value : items.first;

  return SizedBox(
    width: 164,
    height: AppFormStyles.controlHeight,
    child: DropdownButtonFormField<String>(
      key: ValueKey<String>('core-dropdown-$label-$effectiveValue'),
      initialValue: effectiveValue,
      isExpanded: true,
      style: AppFormStyles.controlTextStyle(context),
      decoration: AppFormStyles.decoration(context, labelText: label),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
                style: AppFormStyles.controlTextStyle(context),
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (nextValue) {
        if (nextValue != null) {
          onChanged(nextValue);
        }
      },
    ),
  );
}
