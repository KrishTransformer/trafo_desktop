import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_scope.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/presentation/app_form_styles.dart';
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
  bool _isMoreInfoExpanded = false;

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

            return Theme(
              data: _compactTwoWindingTheme(theme),
              child: LoadingOverlay(
                isLoading: state.isBusy,
                child: ColoredBox(
                  color: _twoWindingPageBackground,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1680),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 1100;
                            final sideColumn = Column(
                              children: [
                                _ClearanceCard(
                                  state: state,
                                  controller: controller,
                                ),
                                const SizedBox(height: 5),
                                _WorkspaceHeader(
                                  canOpenCore: canOpenCore,
                                  onReset: controller.reset,
                                  onOpenCore: canOpenCore
                                      ? () => context.go(
                                          RoutePaths.coreDesign(
                                            state.metadata.entityId,
                                          ),
                                          extra: _buildCoreLaunchSummary(state),
                                        )
                                      : null,
                                  onCalculate: controller.calculate,
                                  isCalculating: state.isCalculating,
                                ),
                                const SizedBox(height: 18),
                                _MoreInfoCard(
                                  selectedTabIndex: _selectedDetailsTab,
                                  onTabSelected: (index) => setState(
                                    () => _selectedDetailsTab = index,
                                  ),
                                  isExpanded: _isMoreInfoExpanded,
                                  onExpansionChanged: () => setState(
                                    () => _isMoreInfoExpanded =
                                        !_isMoreInfoExpanded,
                                  ),
                                  state: state,
                                  controller: controller,
                                ),
                                const SizedBox(height: 18),
                                _CommentsCard(
                                  persistentComments: persistentComments,
                                  hoveredComment: hoveredComment,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: _PartOneColumn(
                                          state: state,
                                          controller: controller,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _PartTwoColumn(
                                          state: state,
                                          controller: controller,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(child: sideColumn),
                                    ],
                                  );
                            return Scrollbar(
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                primary: true,
                                padding: const EdgeInsets.only(right: 4),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Two Winding Design',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Configure transformer inputs, winding details, and calculated dimensions.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF5F6B7A),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    content,
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canOpenCore)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onOpenCore,
              icon: const Icon(Icons.donut_large_outlined),
              label: const Text('Open Core'),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: const Color(0xFF1E293B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: onReset,
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: isCalculating ? null : onCalculate,
                child: isCalculating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Calculate',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PartOneColumn extends StatelessWidget {
  const _PartOneColumn({required this.state, required this.controller});

  final TwoWindingState state;
  final TwoWindingController controller;

  Widget field(String label, String path, {bool readOnly = false}) =>
      _textField(
        label: label,
        value: state.design.stringAt(path),
        readOnly: readOnly,
        onChanged: readOnly
            ? null
            : (value) => controller.setField(path, value),
      );

  @override
  Widget build(BuildContext context) {
    final isDryType = state.design.boolAt('dryType');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionCard(
          title: '',
          child: Column(
            children: [
              _ResponsiveThreeColumn(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _dropdownField(
                    context,
                    label: '',
                    semanticLabel: 'Core Shape',
                    value: state.design.stringAt('eTransBodyType'),
                    items: const ['RECTANGULAR', 'CIRCULAR'],
                    onChanged: (value) =>
                        controller.setField('eTransBodyType', value),
                  ),
                  _dropdownField(
                    context,
                    label: '',
                    semanticLabel: 'Insulation Type',
                    value: isDryType ? 'Dry Type' : 'Oil Type',
                    items: const ['Oil Type', 'Dry Type'],
                    onChanged: (value) =>
                        controller.setField('dryType', value == 'Dry Type'),
                  ),
                  _dropdownField(
                    context,
                    label: '',
                    semanticLabel: 'Cost Type',
                    value: state.design.stringAt('eTransCostType'),
                    items: const ['ECONOMIC', 'ENERGY_EFFICIENT'],
                    onChanged: (value) =>
                        controller.setField('eTransCostType', value),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        const SizedBox(height: 25),
                        field('kVA', 'kVA'),
                        const SizedBox(height: 5),
                        field('Frequency', 'frequency'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: _WindingInputColumn(
                      title: 'INNER',
                      prefix: 'lv',
                      accent: _twoWindingLvAccent,
                      state: state,
                      controller: controller,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: _WindingInputColumn(
                      title: 'OUTER',
                      prefix: 'hv',
                      accent: _twoWindingHvAccent,
                      state: state,
                      controller: controller,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ResponsiveThreeColumn(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _dropdownField(
                    context,
                    label: 'Connection',
                    value: state.design.stringAt('vectorGroup'),
                    items: const ['Dyn11', 'Dd0', 'Yyn0', 'Yd11', 'Ii0'],
                    onChanged: (value) =>
                        controller.setField('vectorGroup', value),
                  ),
                  if (state.design.stringAt('vectorGroup') == 'Ii0') ...[
                    _dropdownField(
                      context,
                      label: 'LV Limbs',
                      value: state.design.stringAt('lVLimbs'),
                      items: const ['Series', 'Parallel'],
                      onChanged: (value) =>
                          controller.setField('lVLimbs', value),
                    ),
                    _dropdownField(
                      context,
                      label: 'HV Limbs',
                      value: state.design.stringAt('hVLimbs'),
                      items: const ['Series', 'Parallel'],
                      onChanged: (value) =>
                          controller.setField('hVLimbs', value),
                    ),
                  ],
                  _dropdownField(
                    context,
                    label: 'Tap Changer',
                    value: state.design.boolAt('isOLTC') ? 'OLTC' : 'OCTC',
                    items: const ['OCTC', 'OLTC'],
                    onChanged: (value) =>
                        controller.setField('isOLTC', value == 'OLTC'),
                  ),
                  if (isDryType)
                    _dropdownField(
                      context,
                      label: 'Dry Temp Class',
                      value: state.design.stringAt(
                        'dryTempClass',
                        fallback: 'CLASS_B',
                      ),
                      items: const ['CLASS_B', 'CLASS_F', 'CLASS_H'],
                      onChanged: (value) =>
                          controller.setField('dryTempClass', value),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _ResponsiveThreeColumn(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _hoverTextField(
                    label: 'Tap Step %',
                    value: state.design.stringAt('tapStepsPercent'),
                    onChanged: (value) =>
                        controller.setField('tapStepsPercent', value),
                    onHoverStart: () =>
                        controller.showComment('tapStepComment'),
                    onHoverEnd: controller.clearComment,
                  ),
                  field('-ve', 'tapStepsNegative'),
                  field('+ve', 'tapStepsPositive'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        _SectionCard(
          title: '',
          child: Column(
            children: [
              _ResponsiveThreeColumn(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _lockableTextField(
                    label: 'Core Diameter',
                    value: state.design.stringAt('core.coreDia'),
                    isLocked: state.design.boolAt(
                      'lockedAttributes.coreLock.coreDia',
                    ),
                    onToggleLock: () =>
                        controller.toggleLock('coreLock.coreDia'),
                    onChanged: (value) =>
                        controller.setField('core.coreDia', value),
                  ),
                  _lockableTextField(
                    label: 'Limb Ht.',
                    value: state.design.stringAt('core.limbHt'),
                    isLocked: state.design.boolAt(
                      'lockedAttributes.coreLock.limbHt',
                    ),
                    onToggleLock: () =>
                        controller.toggleLock('coreLock.limbHt'),
                    onChanged: (value) =>
                        controller.setField('core.limbHt', value),
                  ),
                  field('Cen Dist', 'core.cenDist'),
                  field('Net Core Area', 'core.area'),
                  _dropdownField(
                    context,
                    label: 'Core Type',
                    value: state.design.stringAt('core.coreType'),
                    items: const ['PRIME', 'STEP_LAP'],
                    onChanged: (value) =>
                        controller.setField('core.coreType', value),
                  ),
                  _hoverTextField(
                    label: 'W/Kg',
                    value: state.design.stringAt('hvFormulas.specificLoss'),
                    onChanged: (value) =>
                        controller.setField('hvFormulas.specificLoss', value),
                    onHoverStart: () =>
                        controller.showComment('wattPerKgComment'),
                    onHoverEnd: controller.clearComment,
                  ),
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

                  field('Build Factor', 'buildFactor'),
                  field('Flux Density', 'fluxDensity'),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Volts per Turn: ${state.design.stringAt('voltsPerTurn', fallback: '0')}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        _SectionCard(
          title: '',
          child: Column(
            children: [
              _ResponsiveThreeColumn(
                spacing: 10,
                runSpacing: 10,
                children: [
                  field('Tank Loss', 'tank.tankLoss'),
                  field('Load Loss', 'loadLoss'),
                  field('Core Loss', 'coreLoss'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: field('Limit EZ', 'limitEz')),
                  const SizedBox(width: 10),
                  Expanded(child: field('EZ', 'ez')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        _SectionCard(
          title: isDryType ? 'Enclosure Details' : 'Tank Details',
          child: _ResponsiveThreeColumn(
            spacing: 10,
            runSpacing: 10,
            maxColumns: 4,
            children: [
              field(isDryType ? 'Length' : 'Tank Length', 'tank.tankLength'),
              field(isDryType ? 'Width' : 'Tank Width', 'tank.tankWidth'),
              field(isDryType ? 'Height' : 'Tank Height', 'tank.tankHeight'),
              if (!isDryType) field('Tank Capacity', 'tank.tankCapacity'),
            ],
          ),
        ),
      ],
    );
  }
}

class _WindingInputColumn extends StatelessWidget {
  const _WindingInputColumn({
    required this.title,
    required this.prefix,
    required this.accent,
    required this.state,
    required this.controller,
  });
  final String title;
  final String prefix;
  final Color accent;
  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    final isLv = prefix == 'lv';
    final materialPath = isLv ? 'lVConductorMaterial' : 'hVConductorMaterial';
    final material = state.design.stringAt(materialPath, fallback: 'Cu');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 25,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ),
        _LabeledInput(
          label: isLv ? 'LV CurrDen' : 'HV CurrDen',
          value: state.design.stringAt('${prefix}CurrentDensity'),
          onChanged: (value) =>
              controller.setField('${prefix}CurrentDensity', value),
          suffixIcon: _FieldChoice(
            label: material,
            tooltip: '${isLv ? 'LV' : 'HV'} conductor material',
            onTap: () => controller.setField(
              materialPath,
              material == 'Cu' ? 'Al' : 'Cu',
            ),
          ),
        ),
        const SizedBox(height: 5),
        _LabeledInput(
          label: isLv ? 'Volts-LV-Wdg' : 'Volts-HV-Wdg',
          value: state.design.stringAt(isLv ? 'lowVoltage' : 'highVoltage'),
          onChanged: (value) =>
              controller.setField(isLv ? 'lowVoltage' : 'highVoltage', value),
          suffixIcon: PopupMenuButton<String>(
            tooltip: '${isLv ? 'LV' : 'HV'} winding type',
            padding: EdgeInsets.zero,
            onSelected: (value) =>
                controller.setField('${prefix}WindingType', value),
            itemBuilder: (_) => [
              for (final value
                  in isLv
                      ? ['HELICAL', 'DISC', 'FOIL', 'LAYERDISC']
                      : ['HELICAL', 'DISC', 'XOVER'])
                PopupMenuItem(value: value, child: Text(_optionLabel(value))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _optionLabel(state.design.stringAt('${prefix}WindingType')),
                    style: const TextStyle(
                      fontSize: 10,
                      color: _twoWindingLvAccent,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldChoice extends StatelessWidget {
  const _FieldChoice({
    required this.label,
    required this.tooltip,
    required this.onTap,
  });
  final String label;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _twoWindingLvAccent,
            ),
          ),
        ),
      ),
    ),
  );
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
      title: '',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Inner Winding LV',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _twoWindingLvAccent,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Expanded(child: SizedBox()),
              Expanded(
                child: Text(
                  'Outer Winding HV',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _twoWindingHvAccent,
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
              label: '',
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
              label: '',
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
            label: 'Current Density (A/mm²)',
            leftPath: 'innerWindings.currentDensity',
            rightPath: 'outerWindings.currentDensity',
          ),
          _simpleMirroredField(
            label: 'Cond. Cross Sec (mm2)',
            leftPath: 'innerWindings.condCrossSec',
            rightPath: 'outerWindings.condCrossSec',
          ),
          _MirroredRow(
            label: 'Conductor Sizes (mm)',
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
            label: 'Cond. Insulation (mm)',
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
            label: 'Winding Length (mm)',
            leftPath: 'innerWindings.windingLength',
            rightPath: 'outerWindings.windingLength',
          ),
          _simpleMirroredField(
            label: 'No. of Layers',
            leftPath: 'innerWindings.noOfLayers',
            rightPath: 'outerWindings.noOfLayers',
          ),
          _MirroredRow(
            label: 'Inter Layer Insulation (mm)',
            left: _hoverTextField(
              label: '',
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
              label: '',
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
            label: 'End Clearances (mm)',
            left: _hoverTextField(
              label: '',
              value: state.design.stringAt('innerWindings.endClearances'),
              onChanged: (value) =>
                  controller.setField('innerWindings.endClearances', value),
              onHoverStart: () => controller.showComment('lvEndClrComment'),
              onHoverEnd: controller.clearComment,
            ),
            right: _hoverTextField(
              label: '',
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
            label: 'Wgt Bare / Insulated (Kg)',
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
                label: '',
                value: state.design.stringAt('innerWindings.terminal'),
                items: const <String>['Bushing', 'Cable Box'],
                onChanged: (value) =>
                    controller.setField('innerWindings.terminal', value),
              ),
              right: _dropdownField(
                context,
                label: '',
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
        label: '',
        value: state.design.stringAt(leftPath),
        onChanged: (value) => controller.setField(leftPath, value),
      ),
      right: _textField(
        label: '',
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
      title: '',
      child: _ResponsiveThreeColumn(
        spacing: 10,
        runSpacing: 10,
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
    required this.persistentComments,
    required this.hoveredComment,
  });

  final String persistentComments;
  final String hoveredComment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPersistentComments = persistentComments.trim().isNotEmpty;
    final hasHoveredComment = hoveredComment.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _twoWindingPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Comments',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0x1F0F172A),
                  style: BorderStyle.solid,
                ),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Text(
                'Hover field notes and design guidance will appear here.',
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
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.state,
    required this.controller,
  });

  final int selectedTabIndex;
  final ValueChanged<int> onTabSelected;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _twoWindingPanelDecoration(),
      child: Column(
        children: [
          InkWell(
            onTap: onExpansionChanged,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'More Info',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                ),
              ],
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 14),
            DefaultTabController(
              length: tabLabels.length,
              initialIndex: selectedTabIndex,
              child: Column(
                children: [
                  TabBar(
                    onTap: onTabSelected,
                    labelColor: const Color(0xFF111827),
                    unselectedLabelColor: const Color(0xFF5F6B7A),
                    indicatorColor: _twoWindingLvAccent,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: [
                      for (final label in tabLabels)
                        Tab(child: Text(label, textAlign: TextAlign.center)),
                    ],
                  ),
                  SizedBox(
                    height: 390,
                    child: SingleChildScrollView(
                      key: ValueKey('details-$selectedTabIndex'),
                      primary: false,
                      padding: const EdgeInsets.only(top: 16),
                      child: selectedTabIndex == 0
                          ? _TankCoolingTab(
                              state: state,
                              controller: controller,
                            )
                          : selectedTabIndex == 1
                          ? _CoilDimensionsTab(state: state)
                          : _CostingsTab(state: state, controller: controller),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        _ResponsiveThreeColumn(
          spacing: 10,
          runSpacing: 10,
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
              padding: AppFormStyles.compactPanelPadding,
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

    return Column(
      children: [
        const Text(
          'Coil Winding: Dimensions in mm',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        _ReadOnlySummary(rows: rows),
      ],
    );
  }
}

class _CostingsTab extends StatelessWidget {
  const _CostingsTab({required this.state, required this.controller});
  final TwoWindingState state;
  final TwoWindingController controller;

  @override
  Widget build(BuildContext context) {
    final isDryType = state.design.boolAt('dryType');
    final rows = [
      (
        label: 'Conductor',
        weight: 'tankAndOilFormulas.totalConductorWeight',
        rates: [('Cu', 'copperCostPerKg'), ('Al', 'aluminiumCostPerKg')],
        total: 'totalCondCost',
      ),
      (
        label: 'Core',
        weight: 'core.coreWeight',
        rates: [('', 'coreCostPerKg')],
        total: 'totalCoreCost',
      ),
      (
        label: 'Steel',
        weight: 'tankAndOilFormulas.totalSteelWeight',
        rates: [('', 'steelCostPerKg')],
        total: 'totalSteelCost',
      ),
      if (!isDryType)
        (
          label: 'Net Oil',
          weight: 'tankAndOilFormulas.totalOil',
          rates: [('', 'oilCostPerKg')],
          total: 'totalOilCost',
        ),
      (
        label: 'Insulation',
        weight: 'tankAndOilFormulas.insulationWeight',
        rates: [('', 'insulationCostPerKg')],
        total: 'totalInsCost',
      ),
      if (!isDryType)
        (
          label: 'Radiator',
          weight: 'tankAndOilFormulas.totalRadiatorWeight',
          rates: [('', 'radiatorCostPerKg')],
          total: 'totalRadiatorCost',
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _twoWindingPageBackground,
            border: Border.all(color: _twoWindingPanelBorder),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Major material cost',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 100,
                child: _textField(
                  label: '',
                  value: state.design.stringAt('cost.capitalCost'),
                  onChanged: (value) =>
                      controller.setField('cost.capitalCost', value),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cost Estimations',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(1.3),
            3: FlexColumnWidth(1.1),
          },
          border: TableBorder.all(color: _twoWindingPanelBorder),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: const BoxDecoration(color: _twoWindingPageBackground),
              children: [
                for (final label in [
                  'Material',
                  'Weight\n(kg)',
                  'Cost / kg',
                  'Total\nCost',
                ])
                  _CostCell(label, heading: true),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  _CostCell(row.label),
                  _CostCell(state.design.stringAt(row.weight)),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      children: [
                        for (final rate in row.rates)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: _LabeledInput(
                              label: '',
                              value: state.design.stringAt('cost.${rate.$2}'),
                              suffixIcon: rate.$1.isEmpty
                                  ? null
                                  : Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Center(
                                        widthFactor: 1,
                                        child: Text(
                                          rate.$1,
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                    ),
                              onChanged: (value) =>
                                  controller.setField('cost.${rate.$2}', value),
                            ),
                          ),
                      ],
                    ),
                  ),
                  _CostCell(state.design.stringAt('cost.${row.total}')),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Totals are calculated after running Calculate.',
          textAlign: TextAlign.right,
          style: TextStyle(fontSize: 11, color: Color(0xFF5F6B7A)),
        ),
      ],
    );
  }
}

class _CostCell extends StatelessWidget {
  const _CostCell(this.value, {this.heading = false});
  final String value;
  final bool heading;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
    child: Text(
      value.isEmpty ? '-' : value,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: heading ? 11 : 12,
        fontWeight: heading ? FontWeight.w700 : FontWeight.normal,
      ),
    ),
  );
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
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: left),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontSize: 12,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(child: right),
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
    final breadth = state.design.stringAt('$prefix.condBreadth');
    final height = state.design.stringAt('$prefix.condHeight');
    final diameter = state.design.stringAt('$prefix.conductorDiameter');
    final displayValue = isRound
        ? (diameter.isEmpty ? 'x' : diameter)
        : '${breadth.isEmpty ? '' : breadth} x ${height.isEmpty ? '' : height}'
              .trim();

    return _LabeledInput(
      label: '',
      value: displayValue.isEmpty ? 'x' : displayValue,
      readOnly: true,
      onTap: isLocked
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (_) => _ConductorSizeDialog(
                prefix: prefix,
                isRound: isRound,
                breadth: breadth,
                height: height,
                diameter: diameter,
                controller: controller,
              ),
            ),
      suffixIcon: _LockButton(
        isLocked: isLocked,
        subject: 'conductor sizes',
        onPressed: () => controller.toggleLock('$prefix.conductorSizes'),
      ),
    );
  }
}

class _ConductorSizeDialog extends StatefulWidget {
  const _ConductorSizeDialog({
    required this.prefix,
    required this.isRound,
    required this.breadth,
    required this.height,
    required this.diameter,
    required this.controller,
  });

  final String prefix;
  final bool isRound;
  final String breadth;
  final String height;
  final String diameter;
  final TwoWindingController controller;

  @override
  State<_ConductorSizeDialog> createState() => _ConductorSizeDialogState();
}

class _ConductorSizeDialogState extends State<_ConductorSizeDialog> {
  late bool _isRound = widget.isRound;
  late String _breadth = widget.breadth;
  late String _height = widget.height;
  late String _diameter = widget.diameter;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conductor Size'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              style: _compactSegmentedButtonStyle(),
              segments: const [
                ButtonSegment<bool>(value: true, label: Text('Round')),
                ButtonSegment<bool>(value: false, label: Text('Strip')),
              ],
              selected: <bool>{_isRound},
              onSelectionChanged: (selection) {
                setState(() => _isRound = selection.first);
              },
            ),
            const SizedBox(height: 16),
            if (_isRound)
              _textField(
                label: 'Diameter',
                value: _diameter,
                onChanged: (value) => _diameter = value,
              )
            else ...[
              _textField(
                label: 'Breadth',
                value: _breadth,
                onChanged: (value) => _breadth = value,
              ),
              const SizedBox(height: 12),
              _textField(
                label: 'Height',
                value: _height,
                onChanged: (value) => _height = value,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            widget.controller.setField(
              '${widget.prefix}.isConductorRound',
              _isRound,
            );
            widget.controller.setField(
              '${widget.prefix}.condBreadth',
              _breadth,
            );
            widget.controller.setField('${widget.prefix}.condHeight', _height);
            widget.controller.setField(
              '${widget.prefix}.conductorDiameter',
              _diameter,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Done'),
        ),
      ],
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
    final radial = state.design.stringAt('$prefix.radialParallelCond');
    final axial = state.design.stringAt('$prefix.axialParallelCond');

    return _CompactModalField(
      value: _parallelSummary(radial, axial),
      isLocked: isLocked,
      onToggleLock: () => controller.toggleLock('$prefix.noInParallel'),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => _TwoValueEditorDialog(
          title: 'No. in Parallel',
          description: 'Enter the number of radial and axial conductors.',
          firstLabel: 'No in Radial',
          secondLabel: 'No in Axial',
          firstValue: radial,
          secondValue: axial,
          onSubmit: (nextRadial, nextAxial) {
            controller.setField('$prefix.radialParallelCond', nextRadial);
            controller.setField('$prefix.axialParallelCond', nextAxial);
          },
        ),
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
    final ducts = state.design.stringAt('$prefix.ducts');
    final ductWidth = state.design.stringAt('$prefix.ductSize');

    return MouseRegion(
      onEnter: (_) => controller.showComment(hoverCommentKey),
      onExit: (_) => controller.clearComment(),
      child: _CompactModalField(
        value:
            '${ducts.isEmpty ? '' : ducts} / ${ductWidth.isEmpty ? '' : ductWidth}',
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => _TwoValueEditorDialog(
            title: 'No. of Ducts / Width',
            description: 'Enter the number of ducts and the duct width.',
            firstLabel: 'No Of Ducts',
            secondLabel: 'Duct Width',
            firstValue: ducts,
            secondValue: ductWidth,
            onSubmit: (nextDucts, nextDuctWidth) {
              controller.setField('$prefix.ducts', nextDucts);
              controller.setField('$prefix.ductSize', nextDuctWidth);
            },
          ),
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
    final isEnamel = state.design.boolAt('$prefix.isEnamel');

    return MouseRegion(
      onEnter: (_) => controller.showComment(hoverCommentKey),
      onExit: (_) => controller.clearComment(),
      child: _LabeledInput(
        label: '',
        value: state.design.stringAt('$prefix.condInsulation'),
        onChanged: (value) =>
            controller.setField('$prefix.condInsulation', value),
        suffixIcon: _FieldChoice(
          label: isEnamel ? 'SE' : 'P',
          tooltip: isEnamel ? 'Super enamel insulation' : 'Paper insulation',
          onTap: () => controller.setField('$prefix.isEnamel', !isEnamel),
        ),
      ),
    );
  }
}

class _CompactModalField extends StatelessWidget {
  const _CompactModalField({
    required this.value,
    required this.onTap,
    this.isLocked = false,
    this.onToggleLock,
  });

  final String value;
  final VoidCallback onTap;
  final bool isLocked;
  final VoidCallback? onToggleLock;

  @override
  Widget build(BuildContext context) {
    return _LabeledInput(
      label: '',
      value: value,
      readOnly: true,
      onTap: isLocked ? null : onTap,
      suffixIcon: onToggleLock == null
          ? null
          : _LockButton(isLocked: isLocked, onPressed: onToggleLock!),
    );
  }
}

class _TwoValueEditorDialog extends StatefulWidget {
  const _TwoValueEditorDialog({
    required this.title,
    required this.description,
    required this.firstLabel,
    required this.secondLabel,
    required this.firstValue,
    required this.secondValue,
    required this.onSubmit,
  });

  final String title;
  final String description;
  final String firstLabel;
  final String secondLabel;
  final String firstValue;
  final String secondValue;
  final void Function(String firstValue, String secondValue) onSubmit;

  @override
  State<_TwoValueEditorDialog> createState() => _TwoValueEditorDialogState();
}

class _TwoValueEditorDialogState extends State<_TwoValueEditorDialog> {
  late String _firstValue = widget.firstValue;
  late String _secondValue = widget.secondValue;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.description),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _textField(
                    label: widget.firstLabel,
                    value: _firstValue,
                    onChanged: (value) => _firstValue = value,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _textField(
                    label: widget.secondLabel,
                    value: _secondValue,
                    onChanged: (value) => _secondValue = value,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            widget.onSubmit(_firstValue, _secondValue);
            Navigator.of(context).pop();
          },
          child: const Text('Done'),
        ),
      ],
    );
  }
}

String _parallelSummary(String radial, String axial) {
  final radialValue = double.tryParse(radial);
  final axialValue = double.tryParse(axial);
  final product = radialValue == null || axialValue == null
      ? '0'
      : (radialValue * axialValue).toStringAsFixed(
          (radialValue * axialValue).truncateToDouble() ==
                  radialValue * axialValue
              ? 0
              : 2,
        );
  return 'R$radial x A$axial=$product';
}

class _ResponsiveThreeColumn extends StatelessWidget {
  const _ResponsiveThreeColumn({
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
    this.maxColumns = 3,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumFieldWidth = maxColumns == 4 ? 76.0 : 90.0;
        final columns =
            ((constraints.maxWidth + spacing) / (minimumFieldWidth + spacing))
                .floor()
                .clamp(1, maxColumns)
                .toInt();
        final fieldWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: [
              for (final child in children)
                SizedBox(width: fieldWidth, child: child),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: _twoWindingPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
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
      padding: AppFormStyles.panelPadding,
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

const _twoWindingControlHeight = 30.0;
const _twoWindingControlFontSize = 12.0;
const _twoWindingControlIconSize = 16.0;
const _twoWindingPageBackground = Color(0xFFF3F6FA);
const _twoWindingInputFill = Color(0xFFEEF1F5);
const _twoWindingPanelBorder = Color(0x1F0F172A);
const _twoWindingLvAccent = Color(0xFF0081FF);
const _twoWindingHvAccent = Color(0xFFFF5B1E);

ThemeData _compactTwoWindingTheme(ThemeData theme) {
  return theme.copyWith(
    visualDensity: VisualDensity.compact,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _twoWindingLvAccent,
      brightness: Brightness.light,
    ),
    textTheme: theme.textTheme.apply(
      bodyColor: const Color(0xFF111827),
      displayColor: const Color(0xFF111827),
    ),
  );
}

BoxDecoration _twoWindingPanelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    border: Border.all(color: _twoWindingPanelBorder),
    borderRadius: BorderRadius.circular(10),
    boxShadow: const [
      BoxShadow(color: Color(0x140F172A), offset: Offset(0, 8), blurRadius: 20),
    ],
  );
}

TextStyle? _twoWindingControlTextStyle(BuildContext context) {
  final theme = Theme.of(context);
  return theme.textTheme.bodySmall?.copyWith(
    fontSize: _twoWindingControlFontSize,
    height: 1.0,
    color: theme.colorScheme.onSurface,
  );
}

Widget _twoWindingFieldLabel(BuildContext context, String label) {
  if (label.isEmpty) {
    return const SizedBox.shrink();
  }

  return Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1.1,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

InputDecoration _twoWindingDecoration(
  BuildContext context, {
  String? labelText,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  final theme = Theme.of(context);
  final hintStyle = theme.textTheme.bodySmall?.copyWith(
    fontSize: _twoWindingControlFontSize,
    height: 1.0,
    color: theme.colorScheme.onSurfaceVariant,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(5),
    borderSide: const BorderSide(color: _twoWindingPanelBorder),
  );

  return InputDecoration(
    hintText: hintText ?? labelText,
    hintStyle: hintStyle,
    prefixIcon: prefixIcon,
    prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 30),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 30),
    contentPadding: const EdgeInsets.symmetric(horizontal: 5),
    constraints: const BoxConstraints.tightFor(
      height: _twoWindingControlHeight,
    ),
    filled: true,
    fillColor: _twoWindingInputFill,
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(5),
      borderSide: const BorderSide(color: Color(0xFF2196F3)),
    ),
    isDense: false,
  );
}

ButtonStyle _compactSegmentedButtonStyle() {
  return ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
  );
}

// Keep editing state stable across controller notifications. Only external value
// changes (reset, calculation, dependent defaults) replace the displayed text.
class _LabeledInput extends StatefulWidget {
  const _LabeledInput({
    required this.label,
    required this.value,
    this.onChanged,
    this.readOnly = false,
    this.suffixIcon,
    this.onTap,
    super.key,
  });
  final String label;
  final String value;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final Widget? suffixIcon;
  final VoidCallback? onTap;

  @override
  State<_LabeledInput> createState() => _LabeledInputState();
}

class _LabeledInputState extends State<_LabeledInput> {
  late final TextEditingController _text = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(_LabeledInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.value) {
      final offset = _text.selection.baseOffset.clamp(0, widget.value.length);
      _text.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: offset),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.label.isNotEmpty) ...[
        _twoWindingFieldLabel(context, widget.label),
        const SizedBox(height: 3),
      ],
      SizedBox(
        height: _twoWindingControlHeight,
        child: Semantics(
          label: widget.label,
          child: TextFormField(
            controller: _text,
            textAlignVertical: TextAlignVertical.center,
            readOnly: widget.readOnly || widget.onChanged == null,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            style: _twoWindingControlTextStyle(context),
            decoration: _twoWindingDecoration(
              context,
              suffixIcon: widget.suffixIcon,
            ).copyWith(fillColor: _twoWindingInputFill),
          ),
        ),
      ),
    ],
  );
}

Widget _textField({
  required String label,
  required String value,
  required ValueChanged<String>? onChanged,
  bool readOnly = false,
}) => _LabeledInput(
  key: ValueKey(label),
  label: label,
  value: value,
  onChanged: onChanged,
  readOnly: readOnly,
);

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
}) => _LabeledInput(
  key: ValueKey(label),
  label: label,
  value: value,
  onChanged: onChanged,
  readOnly: isLocked,
  suffixIcon: _LockButton(isLocked: isLocked, onPressed: onToggleLock),
);

class _LockButton extends StatelessWidget {
  const _LockButton({
    required this.isLocked,
    required this.onPressed,
    this.subject = '',
  });
  final bool isLocked;
  final VoidCallback onPressed;
  final String subject;
  @override
  Widget build(BuildContext context) => IconButton(
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(
      width: 28,
      height: _twoWindingControlHeight,
    ),
    tooltip:
        '${isLocked ? 'Unlock' : 'Lock'}${subject.isEmpty ? '' : ' $subject'}',
    color: isLocked ? _twoWindingLvAccent : const Color(0xFF5F6B7A),
    onPressed: onPressed,
    icon: Icon(
      isLocked ? Icons.lock : Icons.lock_open,
      size: _twoWindingControlIconSize,
    ),
  );
}

String _optionLabel(String value) =>
    const <String, String>{
      'RECTANGULAR': 'Rectangular Core',
      'CIRCULAR': 'Circular Core',
      'ECONOMIC': 'Economic',
      'ENERGY_EFFICIENT': 'Energy Efficient',
      'CLASS_B': 'Class B',
      'CLASS_F': 'Class F',
      'CLASS_H': 'Class H',
      'HELICAL': 'Helical',
      'DISC': 'Disc',
      'FOIL': 'Foil',
      'LAYERDISC': 'Layer-Disc',
      'XOVER': 'X-Over',
      'PRIME': 'Prime',
      'STEP_LAP': 'Step Lap',
      'RADIATOR': 'Radiator',
      'PIPES': 'Pipes',
      'CORRUGATION': 'Corrugation',
    }[value] ??
    value;

Widget _dropdownField(
  BuildContext context, {
  required String label,
  String? semanticLabel,
  required String value,
  required List<String> items,
  required ValueChanged<String> onChanged,
}) {
  final effectiveValue = items.contains(value) ? value : items.first;

  return Semantics(
    label: semanticLabel ?? label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          _twoWindingFieldLabel(context, label),
          const SizedBox(height: 3),
        ],
        SizedBox(
          height: _twoWindingControlHeight,
          child: DropdownButtonFormField<String>(
            key: ValueKey<String>(
              'dropdown-${semanticLabel ?? label}-$effectiveValue',
            ),
            initialValue: effectiveValue,
            isExpanded: true,
            iconEnabledColor: const Color(0xFF5F6B7A),
            style: _twoWindingControlTextStyle(context)?.copyWith(
              color: const Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
            decoration: _twoWindingDecoration(context),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      _optionLabel(item),
                      overflow: TextOverflow.ellipsis,
                      style: _twoWindingControlTextStyle(context)?.copyWith(
                        color: const Color(0xFF111827),
                        fontWeight: FontWeight.w700,
                      ),
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
        ),
      ],
    ),
  );
}
