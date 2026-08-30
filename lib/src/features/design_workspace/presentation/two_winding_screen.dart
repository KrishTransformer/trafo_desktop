import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_scope.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../../core/presentation/loading_overlay.dart';
import '../../home/domain/models/design_summary.dart';
import '../application/two_winding_controller.dart';
import '../application/two_winding_state.dart';
import '../data/repositories/http_two_winding_calculation_repository.dart';
import '../data/repositories/http_two_winding_design_repository.dart';

class TwoWindingScreen extends StatefulWidget {
  const TwoWindingScreen({
    required this.routeDesignId,
    this.initialDesignSummary,
    super.key,
  });

  final String routeDesignId;
  final DesignSummary? initialDesignSummary;

  @override
  State<TwoWindingScreen> createState() => _TwoWindingScreenState();
}

class _TwoWindingScreenState extends State<TwoWindingScreen> {
  TwoWindingController? _controller;
  String _lastErrorMessage = '';
  int _selectedDetailsTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_controller != null) {
      return;
    }

    final dependencies = AppScope.of(context);
    final controller = TwoWindingController(
      routeId: widget.routeDesignId,
      calculationRepository: HttpTwoWindingCalculationRepository(
        dependencies.apiClient,
      ),
      designRepository: HttpTwoWindingDesignRepository(dependencies.apiClient),
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
            final theme = Theme.of(context);
            final canOpenCore = state.metadata.entityId.isNotEmpty;
            final persistentComments = controller.buildPersistentComments();
            final hoveredComment = state.activeComment;

            return LoadingOverlay(
              isLoading: state.isBusy,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WorkspaceHeader(
                      canOpenCore: canOpenCore,
                      onReset: controller.reset,
                      onOpenCore: canOpenCore
                          ? () => context.go(
                              RoutePaths.coreDesign(state.metadata.entityId),
                              extra: _buildCoreLaunchSummary(state),
                            )
                          : null,
                      onCalculate: () {
                        controller.calculate();
                      },
                      isCalculating: state.isCalculating,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 1180;
                          final sideColumn = Column(
                            children: [
                              _ClearanceCard(
                                state: state,
                                controller: controller,
                              ),
                              const SizedBox(height: 16),
                              _CommentsCard(
                                theme: theme,
                                persistentComments: persistentComments,
                                hoveredComment: hoveredComment,
                              ),
                              const SizedBox(height: 16),
                              _MoreInfoCard(
                                selectedTabIndex: _selectedDetailsTab,
                                onTabSelected: (index) =>
                                    setState(() => _selectedDetailsTab = index),
                                state: state,
                                controller: controller,
                              ),
                            ],
                          );
                          final content = stacked
                              ? Column(
                                  children: [
                                    _PartOneColumn(
                                      state: state,
                                      controller: controller,
                                    ),
                                    const SizedBox(height: 16),
                                    _PartTwoColumn(
                                      state: state,
                                      controller: controller,
                                    ),
                                    const SizedBox(height: 16),
                                    sideColumn,
                                  ],
                                )
                              : Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 400,
                                      child: _PartOneColumn(
                                        state: state,
                                        controller: controller,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    SizedBox(
                                      width: 460,
                                      child: _PartTwoColumn(
                                        state: state,
                                        controller: controller,
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    SizedBox(width: 400, child: sideColumn),
                                  ],
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
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minWidth: 1320,
                                        ),
                                        child: content,
                                      ),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  DesignSummary _buildCoreLaunchSummary(TwoWindingState state) {
    return DesignSummary(
      id: state.metadata.entityId,
      designId: state.metadata.designId,
      twoWindings: state.design.toJson(),
      core: widget.initialDesignSummary?.core,
      fabrication: widget.initialDesignSummary?.fabrication,
      lom: widget.initialDesignSummary?.lom,
      createdAt: state.metadata.createdAt,
      updatedAt: widget.initialDesignSummary?.updatedAt,
      ownerId: widget.initialDesignSummary?.ownerId,
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.canOpenCore,
    required this.onReset,
    required this.onOpenCore,
    required this.onCalculate,
    required this.isCalculating,
  });

  final bool canOpenCore;
  final VoidCallback onReset;
  final VoidCallback? onOpenCore;
  final VoidCallback onCalculate;
  final bool isCalculating;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: canOpenCore ? onOpenCore : null,
            icon: const Icon(Icons.donut_large_outlined),
            label: const Text('Open Core'),
          ),
          OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
          FilledButton.icon(
            onPressed: isCalculating ? null : onCalculate,
            icon: isCalculating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.calculate_outlined),
            label: Text(isCalculating ? 'Calculating' : 'Calculate'),
          ),
        ],
      ),
    );
  }
}

class _PartOneColumn extends StatelessWidget {
  const _PartOneColumn({required this.state, required this.controller});

  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    final isDryType = state.design.boolAt('dryType');

    return Column(
      children: [
        _SectionCard(
          title: 'Transformer Setup',
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _dropdownField(
                    context,
                    label: 'Body Type',
                    value: state.design.stringAt('eTransBodyType'),
                    items: const <String>['RECTANGULAR', 'CIRCULAR'],
                    onChanged: (value) =>
                        controller.setField('eTransBodyType', value),
                  ),
                  _dropdownField(
                    context,
                    label: 'Type',
                    value: isDryType ? 'Dry Type' : 'Oil Type',
                    items: const <String>['Oil Type', 'Dry Type'],
                    onChanged: (value) =>
                        controller.setField('dryType', value == 'Dry Type'),
                  ),
                  if (isDryType)
                    _dropdownField(
                      context,
                      label: 'Dry Temp Class',
                      value: state.design.stringAt(
                        'dryTempClass',
                        fallback: 'CLASS_B',
                      ),
                      items: const <String>['CLASS_B', 'CLASS_F', 'CLASS_H'],
                      onChanged: (value) =>
                          controller.setField('dryTempClass', value),
                    )
                  else
                    _dropdownField(
                      context,
                      label: 'Cost Type',
                      value: state.design.stringAt('eTransCostType'),
                      items: const <String>['ECONOMIC', 'ENERGY_EFFICIENT'],
                      onChanged: (value) =>
                          controller.setField('eTransCostType', value),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _textField(
                    label: 'kVA',
                    value: state.design.stringAt('kVA'),
                    onChanged: (value) => controller.setField('kVA', value),
                  ),
                  _textField(
                    label: 'Frequency',
                    value: state.design.stringAt('frequency'),
                    onChanged: (value) =>
                        controller.setField('frequency', value),
                  ),
                  _dropdownField(
                    context,
                    label: 'Vector Group',
                    value: state.design.stringAt('vectorGroup'),
                    items: const <String>['Dyn11', 'Dd0', 'Yyn0', 'Yd11'],
                    onChanged: (value) =>
                        controller.setField('vectorGroup', value),
                  ),
                  _dropdownField(
                    context,
                    label: 'LV Limbs',
                    value: state.design.stringAt('lVLimbs'),
                    items: const <String>['Series', 'Parallel'],
                    onChanged: (value) => controller.setField('lVLimbs', value),
                  ),
                  _dropdownField(
                    context,
                    label: 'HV Limbs',
                    value: state.design.stringAt('hVLimbs'),
                    items: const <String>['Series', 'Parallel'],
                    onChanged: (value) => controller.setField('hVLimbs', value),
                  ),
                  _textField(
                    label: 'Build Factor',
                    value: state.design.stringAt('buildFactor'),
                    onChanged: (value) =>
                        controller.setField('buildFactor', value),
                  ),
                  _textField(
                    label: 'Flux Density',
                    value: state.design.stringAt('fluxDensity'),
                    onChanged: (value) =>
                        controller.setField('fluxDensity', value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _VoltagePanel(
                      title: 'Low Voltage / IW',
                      accent: const Color(0xFF0081FF),
                      voltageValue: state.design.stringAt('lowVoltage'),
                      windingValue: state.design.stringAt('lvWindingType'),
                      onVoltageChanged: (value) =>
                          controller.setField('lowVoltage', value),
                      onWindingChanged: (value) =>
                          controller.setField('lvWindingType', value),
                      windingItems: const <String>[
                        'HELICAL',
                        'DISC',
                        'FOIL',
                        'LAYERDISC',
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _VoltagePanel(
                      title: 'High Voltage / OW',
                      accent: const Color(0xFFFF5B1E),
                      voltageValue: state.design.stringAt('highVoltage'),
                      windingValue: state.design.stringAt('hvWindingType'),
                      onVoltageChanged: (value) =>
                          controller.setField('highVoltage', value),
                      onWindingChanged: (value) =>
                          controller.setField('hvWindingType', value),
                      windingItems: const <String>['HELICAL', 'DISC', 'XOVER'],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MaterialDensityPanel(
                      title: 'LV Current Density',
                      accent: const Color(0xFF0081FF),
                      value: state.design.stringAt('lvCurrentDensity'),
                      materialValue: state.design.stringAt(
                        'lVConductorMaterial',
                      ),
                      onValueChanged: (value) =>
                          controller.setField('lvCurrentDensity', value),
                      onMaterialChanged: (value) =>
                          controller.setField('lVConductorMaterial', value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MaterialDensityPanel(
                      title: 'HV Current Density',
                      accent: const Color(0xFFFF5B1E),
                      value: state.design.stringAt('hvCurrentDensity'),
                      materialValue: state.design.stringAt(
                        'hVConductorMaterial',
                      ),
                      onValueChanged: (value) =>
                          controller.setField('hvCurrentDensity', value),
                      onMaterialChanged: (value) =>
                          controller.setField('hVConductorMaterial', value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Core',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dropdownField(
                context,
                label: 'Core Material',
                value: state.design.stringAt('core.coreMaterial'),
                items: const <String>[
                  'NipZD',
                  'NipMOH',
                  'NipM3',
                  'NipM4',
                  'NipM5',
                  'NipM6',
                  'CRNO',
                  'CRGO',
                  'AksAK LC-M2',
                  'AksAK LC-M3',
                  'AksAK C-M3',
                  'AksAK C-M4',
                  'AksAK C-M5',
                  'AksAK C-M6',
                  'AksAK H-0DR',
                  'AksAK H-1DR',
                  'AksAK H-2DR',
                  'AksAK H-2C',
                ],
                onChanged: (value) =>
                    controller.setField('core.coreMaterial', value),
              ),
              _dropdownField(
                context,
                label: 'Core Type',
                value: state.design.stringAt('core.coreType'),
                items: const <String>['PRIME', 'STEP_LAP'],
                onChanged: (value) =>
                    controller.setField('core.coreType', value),
              ),
              _lockableTextField(
                label: 'Core Diameter',
                value: state.design.stringAt('core.coreDia'),
                isLocked: state.design.boolAt(
                  'lockedAttributes.coreLock.coreDia',
                ),
                onToggleLock: () => controller.toggleLock('coreLock.coreDia'),
                onChanged: (value) =>
                    controller.setField('core.coreDia', value),
              ),
              _lockableTextField(
                label: 'Limb Ht.',
                value: state.design.stringAt('core.limbHt'),
                isLocked: state.design.boolAt(
                  'lockedAttributes.coreLock.limbHt',
                ),
                onToggleLock: () => controller.toggleLock('coreLock.limbHt'),
                onChanged: (value) => controller.setField('core.limbHt', value),
              ),
              _textField(
                label: 'Cen Dist',
                value: state.design.stringAt('core.cenDist'),
                onChanged: (value) =>
                    controller.setField('core.cenDist', value),
              ),
              _textField(
                label: 'Net Core Area',
                value: state.design.stringAt('core.area'),
                onChanged: (value) => controller.setField('core.area', value),
              ),
              _hoverTextField(
                label: 'W/Kg',
                value: state.design.stringAt('hvFormulas.specificLoss'),
                onChanged: (value) =>
                    controller.setField('hvFormulas.specificLoss', value),
                onHoverStart: () => controller.showComment('wattPerKgComment'),
                onHoverEnd: controller.clearComment,
              ),
              _textField(
                label: 'Volts / Turn',
                value: state.design.stringAt('voltsPerTurn'),
                onChanged: null,
                readOnly: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Losses, Tap Settings, and Impedance',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _hoverTextField(
                label: 'Tap Steps %',
                value: state.design.stringAt('tapStepsPercent'),
                onChanged: (value) =>
                    controller.setField('tapStepsPercent', value),
                onHoverStart: () => controller.showComment('tapStepComment'),
                onHoverEnd: controller.clearComment,
              ),
              _textField(
                label: '+ ve',
                value: state.design.stringAt('tapStepsPositive'),
                onChanged: (value) =>
                    controller.setField('tapStepsPositive', value),
              ),
              _textField(
                label: '- ve',
                value: state.design.stringAt('tapStepsNegative'),
                onChanged: (value) =>
                    controller.setField('tapStepsNegative', value),
              ),
              _dropdownField(
                context,
                label: 'Tap Changer',
                value: state.design.boolAt('isOLTC') ? 'OLTC' : 'OCTC',
                items: const <String>['OCTC', 'OLTC'],
                onChanged: (value) =>
                    controller.setField('isOLTC', value == 'OLTC'),
              ),
              _textField(
                label: 'Tank Loss',
                value: state.design.stringAt('tank.tankLoss'),
                onChanged: (value) =>
                    controller.setField('tank.tankLoss', value),
              ),
              _textField(
                label: 'Load Loss',
                value: state.design.stringAt('loadLoss'),
                onChanged: (value) => controller.setField('loadLoss', value),
              ),
              _textField(
                label: 'Core Loss',
                value: state.design.stringAt('coreLoss'),
                onChanged: (value) => controller.setField('coreLoss', value),
              ),
              _textField(
                label: 'Limit EZ',
                value: state.design.stringAt('limitEz'),
                onChanged: (value) => controller.setField('limitEz', value),
              ),
              _textField(
                label: 'EZ',
                value: state.design.stringAt('ez'),
                onChanged: (value) => controller.setField('ez', value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PartTwoColumn extends StatelessWidget {
  const _PartTwoColumn({required this.state, required this.controller});

  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    final showDiscDuctSizeRow =
        state.design.stringAt('lvWindingType') == 'DISC' ||
        state.design.stringAt('hvWindingType') == 'DISC';
    final isDryType = state.design.boolAt('dryType');

    return _SectionCard(
      title: 'Windings',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Inner Winding LV',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0081FF),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: Text(
                  'Outer Winding HV',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFF5B1E),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MirroredRow(
            label: 'No. of Turns',
            left: _lockableTextField(
              label: 'LV',
              value: state.design.stringAt('innerWindings.turnsPerPhase'),
              isLocked: state.design.boolAt(
                'lockedAttributes.innerWindings.turnsPerPhase',
              ),
              onToggleLock: () =>
                  controller.toggleLock('innerWindings.turnsPerPhase'),
              onChanged: (value) =>
                  controller.setField('innerWindings.turnsPerPhase', value),
            ),
            right: _lockableTextField(
              label: 'HV',
              value: state.design.stringAt('outerWindings.turnsPerPhase'),
              isLocked: state.design.boolAt(
                'lockedAttributes.outerWindings.turnsPerPhase',
              ),
              onToggleLock: () =>
                  controller.toggleLock('outerWindings.turnsPerPhase'),
              onChanged: (value) =>
                  controller.setField('outerWindings.turnsPerPhase', value),
            ),
          ),
          _simpleMirroredField(
            label: 'Phase Current (A)',
            leftPath: 'innerWindings.phaseCurrent',
            rightPath: 'outerWindings.phaseCurrent',
          ),
          _simpleMirroredField(
            label: 'Current Density',
            leftPath: 'innerWindings.currentDensity',
            rightPath: 'outerWindings.currentDensity',
          ),
          _simpleMirroredField(
            label: 'Cond. Cross Sec',
            leftPath: 'innerWindings.condCrossSec',
            rightPath: 'outerWindings.condCrossSec',
          ),
          _MirroredRow(
            label: 'Conductor Sizes',
            left: _ConductorEditor(
              prefix: 'innerWindings',
              isLocked: state.design.boolAt(
                'lockedAttributes.innerWindings.conductorSizes',
              ),
              state: state,
              controller: controller,
            ),
            right: _ConductorEditor(
              prefix: 'outerWindings',
              isLocked: state.design.boolAt(
                'lockedAttributes.outerWindings.conductorSizes',
              ),
              state: state,
              controller: controller,
            ),
          ),
          _MirroredRow(
            label: 'Cond. Insulation',
            left: _InsulationEditor(
              prefix: 'innerWindings',
              state: state,
              controller: controller,
              hoverCommentKey: 'lvCondInsComment',
            ),
            right: _InsulationEditor(
              prefix: 'outerWindings',
              state: state,
              controller: controller,
              hoverCommentKey: 'hvCondInsComment',
            ),
          ),
          _MirroredRow(
            label: 'No. in Parallel',
            left: _ParallelEditor(
              prefix: 'innerWindings',
              isLocked: state.design.boolAt(
                'lockedAttributes.innerWindings.noInParallel',
              ),
              state: state,
              controller: controller,
            ),
            right: _ParallelEditor(
              prefix: 'outerWindings',
              isLocked: state.design.boolAt(
                'lockedAttributes.outerWindings.noInParallel',
              ),
              state: state,
              controller: controller,
            ),
          ),
          _simpleMirroredField(
            label: 'Winding Length',
            leftPath: 'innerWindings.windingLength',
            rightPath: 'outerWindings.windingLength',
          ),
          _simpleMirroredField(
            label: 'No. of Layers',
            leftPath: 'innerWindings.noOfLayers',
            rightPath: 'outerWindings.noOfLayers',
          ),
          _MirroredRow(
            label: 'Inter Layer Insulation',
            left: _hoverTextField(
              label: 'LV',
              value: state.design.stringAt(
                'innerWindings.interLayerInsulation',
              ),
              onChanged: (value) => controller.setField(
                'innerWindings.interLayerInsulation',
                value,
              ),
              onHoverStart: () =>
                  controller.showComment('lvInterLayerInsComment'),
              onHoverEnd: controller.clearComment,
            ),
            right: _hoverTextField(
              label: 'HV',
              value: state.design.stringAt(
                'outerWindings.interLayerInsulation',
              ),
              onChanged: (value) => controller.setField(
                'outerWindings.interLayerInsulation',
                value,
              ),
              onHoverStart: () =>
                  controller.showComment('hvInterLayerInsComment'),
              onHoverEnd: controller.clearComment,
            ),
          ),
          _MirroredRow(
            label: 'No. of Ducts / Width',
            left: _DuctEditor(
              prefix: 'innerWindings',
              state: state,
              controller: controller,
              hoverCommentKey: 'lvDuctWidthComment',
            ),
            right: _DuctEditor(
              prefix: 'outerWindings',
              state: state,
              controller: controller,
              hoverCommentKey: 'hvDuctWidthComment',
            ),
          ),
          if (showDiscDuctSizeRow)
            _simpleMirroredField(
              label: 'Disc Duct Size',
              leftPath: 'innerWindings.discDuctSize',
              rightPath: 'outerWindings.discDuctSize',
            ),
          _simpleMirroredField(
            label: 'Turns / Layers',
            leftPath: 'innerWindings.turnsLayers',
            rightPath: 'outerWindings.turnsLayers',
          ),
          _MirroredRow(
            label: 'End Clearances',
            left: _hoverTextField(
              label: 'LV',
              value: state.design.stringAt('innerWindings.endClearances'),
              onChanged: (value) =>
                  controller.setField('innerWindings.endClearances', value),
              onHoverStart: () => controller.showComment('lvEndClrComment'),
              onHoverEnd: controller.clearComment,
            ),
            right: _hoverTextField(
              label: 'HV',
              value: state.design.stringAt('outerWindings.endClearances'),
              onChanged: (value) =>
                  controller.setField('outerWindings.endClearances', value),
              onHoverStart: () => controller.showComment('hvEndClrComment'),
              onHoverEnd: controller.clearComment,
            ),
          ),
          _simpleMirroredField(
            label: 'Eddy (Stray) Loss %',
            leftPath: 'innerWindings.eddyStrayLoss',
            rightPath: 'outerWindings.eddyStrayLoss',
          ),
          _simpleMirroredField(
            label: 'Temp. Grad. deg C',
            leftPath: 'innerWindings.tempGradDegC',
            rightPath: 'outerWindings.tempGradDegC',
          ),
          _simpleMirroredField(
            label: 'Weight Bare / Insulated',
            leftPath: 'innerWindings.weightBareInsulated',
            rightPath: 'outerWindings.weightBareInsulated',
          ),
          _simpleMirroredField(
            label: 'Load Loss (W)',
            leftPath: 'innerWindings.loadLoss',
            rightPath: 'outerWindings.loadLoss',
          ),
          if (!isDryType)
            _MirroredRow(
              label: 'Terminal',
              left: _dropdownField(
                context,
                label: 'LV',
                value: state.design.stringAt('innerWindings.terminal'),
                items: const <String>['Bushing', 'Cable Box'],
                onChanged: (value) =>
                    controller.setField('innerWindings.terminal', value),
              ),
              right: _dropdownField(
                context,
                label: 'HV',
                value: state.design.stringAt('outerWindings.terminal'),
                items: const <String>['Bushing', 'Cable Box'],
                onChanged: (value) =>
                    controller.setField('outerWindings.terminal', value),
              ),
            ),
        ],
      ),
    );
  }

  Widget _simpleMirroredField({
    required String label,
    required String leftPath,
    required String rightPath,
  }) {
    return _MirroredRow(
      label: label,
      left: _textField(
        label: 'LV',
        value: state.design.stringAt(leftPath),
        onChanged: (value) => controller.setField(leftPath, value),
      ),
      right: _textField(
        label: 'HV',
        value: state.design.stringAt(rightPath),
        onChanged: (value) => controller.setField(rightPath, value),
      ),
    );
  }
}

class _ClearanceCard extends StatelessWidget {
  const _ClearanceCard({required this.state, required this.controller});

  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Clearances',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _hoverTextField(
            label: 'Core-LV Clr',
            value: state.design.stringAt('coilDimensions.coreGap'),
            onChanged: (value) =>
                controller.setField('coilDimensions.coreGap', value),
            onHoverStart: () => controller.showComment('coreToLvClrComment'),
            onHoverEnd: controller.clearComment,
          ),
          _hoverTextField(
            label: 'LV-HV Clr',
            value: state.design.stringAt('coilDimensions.lvhvgap'),
            onChanged: (value) =>
                controller.setField('coilDimensions.lvhvgap', value),
            onHoverStart: () => controller.showComment('lvToHvClrComment'),
            onHoverEnd: controller.clearComment,
          ),
          _hoverTextField(
            label: 'HV-HV Gap',
            value: state.design.stringAt('coilDimensions.hvhvgap'),
            onChanged: (value) =>
                controller.setField('coilDimensions.hvhvgap', value),
            onHoverStart: () => controller.showComment('hvToHvClrComment'),
            onHoverEnd: controller.clearComment,
          ),
        ],
      ),
    );
  }
}

class _CommentsCard extends StatelessWidget {
  const _CommentsCard({
    required this.theme,
    required this.persistentComments,
    required this.hoveredComment,
  });

  final ThemeData theme;
  final String persistentComments;
  final String hoveredComment;

  @override
  Widget build(BuildContext context) {
    final hasPersistentComments = persistentComments.trim().isNotEmpty;
    final hasHoveredComment = hoveredComment.trim().isNotEmpty;

    return _SectionCard(
      title: 'Comments',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasPersistentComments)
            _CommentPanel(
              title: 'Disc Winding Notes',
              message: persistentComments,
            ),
          if (hasPersistentComments && hasHoveredComment)
            const SizedBox(height: 12),
          if (hasHoveredComment)
            _CommentPanel(title: 'Hovered Field Note', message: hoveredComment),
          if (!hasPersistentComments && !hasHoveredComment)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.surfaceContainerLow,
              ),
              child: Text(
                'Hover fields like conductor insulation, duct width, and end clearances to inspect contextual notes here.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _MoreInfoCard extends StatelessWidget {
  const _MoreInfoCard({
    required this.selectedTabIndex,
    required this.onTabSelected,
    required this.state,
    required this.controller,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    final isDryType = state.design.boolAt('dryType');
    final tabLabels = <String>[
      isDryType ? 'Enclosure & Temp' : 'Tank & Cooling',
      'Coil Dimensions',
      'Costings',
    ];

    return _SectionCard(
      title: 'More Info',
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                for (var index = 0; index < tabLabels.length; index++)
                  ButtonSegment<int>(
                    value: index,
                    label: Text(tabLabels[index]),
                  ),
              ],
              selected: <int>{selectedTabIndex},
              onSelectionChanged: (selection) => onTabSelected(selection.first),
            ),
          ),
          const SizedBox(height: 16),
          if (selectedTabIndex == 0)
            _TankCoolingTab(state: state, controller: controller)
          else if (selectedTabIndex == 1)
            _CoilDimensionsTab(state: state)
          else
            _CostingsTab(state: state, controller: controller),
        ],
      ),
    );
  }
}

class _TankCoolingTab extends StatelessWidget {
  const _TankCoolingTab({required this.state, required this.controller});

  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    final isDryType = state.design.boolAt('dryType');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _textField(
              label: 'Wdg-Tank Gap',
              value: state.design.stringAt('tank.wdgToTankGap'),
              onChanged: (value) =>
                  controller.setField('tank.wdgToTankGap', value),
            ),
            _textField(
              label: 'Connection Gap',
              value: state.design.stringAt('tank.connectionGap'),
              onChanged: (value) =>
                  controller.setField('tank.connectionGap', value),
            ),
            _textField(
              label: 'Top Yoke - Cover',
              value: state.design.stringAt('tank.topYokeToCoverGap'),
              onChanged: (value) =>
                  controller.setField('tank.topYokeToCoverGap', value),
            ),
            _textField(
              label: 'Winding Temp',
              value: state.design.stringAt('windingTemp'),
              onChanged: (value) => controller.setField('windingTemp', value),
            ),
            if (!isDryType)
              _textField(
                label: 'Oil Temp',
                value: state.design.stringAt('topOilTemp'),
                onChanged: (value) => controller.setField('topOilTemp', value),
              ),
            _textField(
              label: 'Ambient Temp',
              value: state.design.stringAt('ambientTemp'),
              onChanged: (value) => controller.setField('ambientTemp', value),
            ),
            if (!isDryType)
              _dropdownField(
                context,
                label: 'Cooling Method',
                value: state.design.stringAt('eRadiatorType'),
                items: const <String>['RADIATOR', 'PIPES', 'CORRUGATION'],
                onChanged: (value) =>
                    controller.setField('eRadiatorType', value),
              ),
            if (!isDryType)
              _textField(
                label: 'Radiator Width',
                value: state.design.stringAt('radiatorWidth'),
                onChanged: (value) =>
                    controller.setField('radiatorWidth', value),
              ),
          ],
        ),
        if (!isDryType) ...[
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('CSP'),
            value: state.design.boolAt('isCSP'),
            onChanged: (value) => controller.setField('isCSP', value),
          ),
          if (state.design
              .stringAt('tankAndOilFormulas.coolingStatement')
              .isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                state.design.stringAt('tankAndOilFormulas.coolingStatement'),
              ),
            ),
        ],
        const SizedBox(height: 12),
        _ReadOnlySummary(
          rows: <MapEntry<String, String>>[
            MapEntry(
              isDryType ? 'Enclosure (L x B x H)' : 'Tank (L x B x H)',
              state.design.stringAt('tank.tankDimension', fallback: '-'),
            ),
            MapEntry(
              'Overall Dimensions',
              state.design.stringAt('tank.overallDimension', fallback: '-'),
            ),
            if (!isDryType && !state.design.boolAt('isCSP'))
              MapEntry(
                'Conservator Dia',
                state.design.stringAt(
                  'tankAndOilFormulas.conservatorDia',
                  fallback: '-',
                ),
              ),
            if (!isDryType && !state.design.boolAt('isCSP'))
              MapEntry(
                'Conservator Length',
                state.design.stringAt(
                  'tankAndOilFormulas.conservatorLength',
                  fallback: '-',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _CoilDimensionsTab extends StatelessWidget {
  const _CoilDimensionsTab({required this.state});

  final TwoWindingState state;

  @override
  Widget build(BuildContext context) {
    final rows = <MapEntry<String, String>>[
      MapEntry('Core Dia', state.design.stringAt('coilDimensions.coreDia')),
      MapEntry('Core Gap', state.design.stringAt('coilDimensions.coreGap')),
      MapEntry('LV - ID', state.design.stringAt('coilDimensions.lvid')),
      MapEntry('LV - Radial', state.design.stringAt('coilDimensions.lvradial')),
      MapEntry('LV - OD', state.design.stringAt('coilDimensions.lvod')),
      MapEntry('LV-HV Gap', state.design.stringAt('coilDimensions.lvhvgap')),
      MapEntry('HV - ID', state.design.stringAt('coilDimensions.hvid')),
      MapEntry('HV - Radial', state.design.stringAt('coilDimensions.hvradial')),
      MapEntry('HV - OD', state.design.stringAt('coilDimensions.hvod')),
      MapEntry('HV-HV Gap', state.design.stringAt('coilDimensions.hvhvgap')),
      MapEntry(
        'Active Part Size',
        state.design.stringAt('coilDimensions.activePartSize'),
      ),
    ];

    return _ReadOnlySummary(rows: rows);
  }
}

class _CostingsTab extends StatelessWidget {
  const _CostingsTab({required this.state, required this.controller});

  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    final isDryType = state.design.boolAt('dryType');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _textField(
          label: 'Major Material Cost',
          value: state.design.stringAt('cost.capitalCost'),
          onChanged: (value) => controller.setField('cost.capitalCost', value),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _textField(
              label: 'Copper Cost / Kg',
              value: state.design.stringAt('cost.copperCostPerKg'),
              onChanged: (value) =>
                  controller.setField('cost.copperCostPerKg', value),
            ),
            _textField(
              label: 'Aluminium Cost / Kg',
              value: state.design.stringAt('cost.aluminiumCostPerKg'),
              onChanged: (value) =>
                  controller.setField('cost.aluminiumCostPerKg', value),
            ),
            _textField(
              label: 'Core Cost / Kg',
              value: state.design.stringAt('cost.coreCostPerKg'),
              onChanged: (value) =>
                  controller.setField('cost.coreCostPerKg', value),
            ),
            _textField(
              label: 'Steel Cost / Kg',
              value: state.design.stringAt('cost.steelCostPerKg'),
              onChanged: (value) =>
                  controller.setField('cost.steelCostPerKg', value),
            ),
            if (!isDryType)
              _textField(
                label: 'Oil Cost / Kg',
                value: state.design.stringAt('cost.oilCostPerKg'),
                onChanged: (value) =>
                    controller.setField('cost.oilCostPerKg', value),
              ),
            _textField(
              label: 'Insulation Cost / Kg',
              value: state.design.stringAt('cost.insulationCostPerKg'),
              onChanged: (value) =>
                  controller.setField('cost.insulationCostPerKg', value),
            ),
            if (!isDryType)
              _textField(
                label: 'Radiator Cost / Kg',
                value: state.design.stringAt('cost.radiatorCostPerKg'),
                onChanged: (value) =>
                    controller.setField('cost.radiatorCostPerKg', value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _ReadOnlySummary(
          rows: <MapEntry<String, String>>[
            MapEntry(
              'Total Conductor Weight',
              state.design.stringAt(
                'tankAndOilFormulas.totalConductorWeight',
                fallback: '-',
              ),
            ),
            MapEntry(
              'Core Weight',
              state.design.stringAt('core.coreWeight', fallback: '-'),
            ),
            MapEntry(
              'Total Steel Weight',
              state.design.stringAt(
                'tankAndOilFormulas.totalSteelWeight',
                fallback: '-',
              ),
            ),
            if (!isDryType)
              MapEntry(
                'Net Oil',
                state.design.stringAt(
                  'tankAndOilFormulas.totalOil',
                  fallback: '-',
                ),
              ),
            MapEntry(
              'Insulation Weight',
              state.design.stringAt(
                'tankAndOilFormulas.insulationWeight',
                fallback: '-',
              ),
            ),
            if (!isDryType)
              MapEntry(
                'Radiator Weight',
                state.design.stringAt(
                  'tankAndOilFormulas.totalRadiatorWeight',
                  fallback: '-',
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MirroredRow extends StatelessWidget {
  const _MirroredRow({
    required this.label,
    required this.left,
    required this.right,
  });

  final String label;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 12),
              Expanded(child: right),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConductorEditor extends StatelessWidget {
  const _ConductorEditor({
    required this.prefix,
    required this.isLocked,
    required this.state,
    required this.controller,
  });

  final String prefix;
  final bool isLocked;
  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    final isRound = state.design.boolAt('$prefix.isConductorRound');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: true, label: Text('Round')),
                    ButtonSegment<bool>(value: false, label: Text('Strip')),
                  ],
                  selected: <bool>{isRound},
                  onSelectionChanged: isLocked
                      ? null
                      : (selection) => controller.setField(
                          '$prefix.isConductorRound',
                          selection.first,
                        ),
                ),
              ),
              IconButton(
                tooltip: isLocked ? 'Unlock' : 'Lock',
                onPressed: () =>
                    controller.toggleLock('$prefix.conductorSizes'),
                icon: Icon(isLocked ? Icons.lock : Icons.lock_open, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'Breadth',
            value: state.design.stringAt('$prefix.condBreadth'),
            onChanged: isLocked
                ? null
                : (value) => controller.setField('$prefix.condBreadth', value),
            readOnly: isLocked,
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'Height',
            value: state.design.stringAt('$prefix.condHeight'),
            onChanged: isLocked
                ? null
                : (value) => controller.setField('$prefix.condHeight', value),
            readOnly: isLocked,
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'Diameter',
            value: state.design.stringAt('$prefix.conductorDiameter'),
            onChanged: isLocked
                ? null
                : (value) =>
                      controller.setField('$prefix.conductorDiameter', value),
            readOnly: isLocked,
          ),
        ],
      ),
    );
  }
}

class _ParallelEditor extends StatelessWidget {
  const _ParallelEditor({
    required this.prefix,
    required this.isLocked,
    required this.state,
    required this.controller,
  });

  final String prefix;
  final bool isLocked;
  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _textField(
                  label: 'Total',
                  value: state.design.stringAt('$prefix.noInParallel'),
                  onChanged: isLocked
                      ? null
                      : (value) =>
                            controller.setField('$prefix.noInParallel', value),
                  readOnly: isLocked,
                ),
              ),
              IconButton(
                tooltip: isLocked ? 'Unlock' : 'Lock',
                onPressed: () => controller.toggleLock('$prefix.noInParallel'),
                icon: Icon(isLocked ? Icons.lock : Icons.lock_open, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'Radial',
            value: state.design.stringAt('$prefix.radialParallelCond'),
            onChanged: isLocked
                ? null
                : (value) =>
                      controller.setField('$prefix.radialParallelCond', value),
            readOnly: isLocked,
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'Axial',
            value: state.design.stringAt('$prefix.axialParallelCond'),
            onChanged: isLocked
                ? null
                : (value) =>
                      controller.setField('$prefix.axialParallelCond', value),
            readOnly: isLocked,
          ),
        ],
      ),
    );
  }
}

class _DuctEditor extends StatelessWidget {
  const _DuctEditor({
    required this.prefix,
    required this.state,
    required this.controller,
    required this.hoverCommentKey,
  });

  final String prefix;
  final TwoWindingState state;
  final TwoWindingController controller;
  final String hoverCommentKey;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => controller.showComment(hoverCommentKey),
      onExit: (_) => controller.clearComment(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            _textField(
              label: 'No Of Ducts',
              value: state.design.stringAt('$prefix.ducts'),
              onChanged: (value) => controller.setField('$prefix.ducts', value),
            ),
            const SizedBox(height: 8),
            _textField(
              label: 'Duct Width',
              value: state.design.stringAt('$prefix.ductSize'),
              onChanged: (value) =>
                  controller.setField('$prefix.ductSize', value),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsulationEditor extends StatelessWidget {
  const _InsulationEditor({
    required this.prefix,
    required this.state,
    required this.controller,
    required this.hoverCommentKey,
  });

  final String prefix;
  final TwoWindingState state;
  final TwoWindingController controller;
  final String hoverCommentKey;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => controller.showComment(hoverCommentKey),
      onExit: (_) => controller.clearComment(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            _textField(
              label: 'Insulation',
              value: state.design.stringAt('$prefix.condInsulation'),
              onChanged: (value) =>
                  controller.setField('$prefix.condInsulation', value),
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Enamel'),
              value: state.design.boolAt('$prefix.isEnamel'),
              onChanged: (value) =>
                  controller.setField('$prefix.isEnamel', value),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaterialDensityPanel extends StatelessWidget {
  const _MaterialDensityPanel({
    required this.title,
    required this.accent,
    required this.value,
    required this.materialValue,
    required this.onValueChanged,
    required this.onMaterialChanged,
  });

  final String title;
  final Color accent;
  final String value;
  final String materialValue;
  final ValueChanged<String> onValueChanged;
  final ValueChanged<String> onMaterialChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _textField(label: 'Value', value: value, onChanged: onValueChanged),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment<String>(value: 'Cu', label: Text('Cu')),
              ButtonSegment<String>(value: 'Al', label: Text('Al')),
            ],
            selected: <String>{materialValue.isEmpty ? 'Cu' : materialValue},
            onSelectionChanged: (selection) =>
                onMaterialChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

class _VoltagePanel extends StatelessWidget {
  const _VoltagePanel({
    required this.title,
    required this.accent,
    required this.voltageValue,
    required this.windingValue,
    required this.onVoltageChanged,
    required this.onWindingChanged,
    required this.windingItems,
  });

  final String title;
  final Color accent;
  final String voltageValue;
  final String windingValue;
  final ValueChanged<String> onVoltageChanged;
  final ValueChanged<String> onWindingChanged;
  final List<String> windingItems;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _textField(
            label: 'Voltage',
            value: voltageValue,
            onChanged: onVoltageChanged,
          ),
          const SizedBox(height: 8),
          _dropdownField(
            context,
            label: 'Winding Type',
            value: windingValue,
            items: windingItems,
            onChanged: onWindingChanged,
          ),
        ],
      ),
    );
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
        padding: const EdgeInsets.all(16),
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

class _CommentPanel extends StatelessWidget {
  const _CommentPanel({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ReadOnlySummary extends StatelessWidget {
  const _ReadOnlySummary({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.key,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    row.value.isEmpty ? '-' : row.value,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Widget _textField({
  required String label,
  required String value,
  required ValueChanged<String>? onChanged,
  bool readOnly = false,
}) {
  return SizedBox(
    width: 176,
    child: TextFormField(
      key: ValueKey<String>('field-$label-$value-$readOnly'),
      initialValue: value,
      readOnly: readOnly || onChanged == null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

Widget _hoverTextField({
  required String label,
  required String value,
  required ValueChanged<String>? onChanged,
  required VoidCallback onHoverStart,
  required VoidCallback onHoverEnd,
  bool readOnly = false,
}) {
  return MouseRegion(
    onEnter: (_) => onHoverStart(),
    onExit: (_) => onHoverEnd(),
    child: _textField(
      label: label,
      value: value,
      onChanged: onChanged,
      readOnly: readOnly,
    ),
  );
}

Widget _lockableTextField({
  required String label,
  required String value,
  required bool isLocked,
  required VoidCallback onToggleLock,
  required ValueChanged<String>? onChanged,
}) {
  return SizedBox(
    width: 176,
    child: TextFormField(
      key: ValueKey<String>('lock-field-$label-$value-$isLocked'),
      initialValue: value,
      readOnly: isLocked || onChanged == null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          tooltip: isLocked ? 'Unlock' : 'Lock',
          onPressed: onToggleLock,
          icon: Icon(isLocked ? Icons.lock : Icons.lock_open, size: 18),
        ),
      ),
    ),
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
    width: 176,
    child: DropdownButtonFormField<String>(
      key: ValueKey<String>('dropdown-$label-$effectiveValue'),
      initialValue: effectiveValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
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
