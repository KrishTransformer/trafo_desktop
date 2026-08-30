import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../home/domain/models/design_summary.dart';
import '../application/multi_winding_controller.dart';
import '../data/repositories/http_multi_winding_repositories.dart';

class MultiWindingScreen extends StatefulWidget {
  const MultiWindingScreen({
    required this.routeDesignId,
    this.initialDesignSummary,
    super.key,
  });

  final String routeDesignId;
  final DesignSummary? initialDesignSummary;

  @override
  State<MultiWindingScreen> createState() => _MultiWindingScreenState();
}

class _MultiWindingScreenState extends State<MultiWindingScreen> {
  MultiWindingController? _controller;
  var _tab = 0;
  String _lastError = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final apiClient = AppScope.of(context).apiClient;
    _controller = MultiWindingController(
      calculationRepository: HttpMultiWindingCalculationRepository(apiClient),
      designRepository: HttpMultiWindingDesignRepository(apiClient),
    )..initialize(initialSummary: widget.initialDesignSummary);
    _controller!.addListener(_onChanged);
  }

  void _onChanged() {
    final error = _controller!.state.errorMessage;
    if (error.isEmpty || error == _lastError) return;
    _lastError = error;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await AppErrorDialog.show(context, message: error);
      _lastError = '';
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final isCompact = MediaQuery.sizeOf(context).width < 640;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: state.isCalculating ? null : controller.reset,
                      child: const Text('Reset'),
                    ),
                    FilledButton.icon(
                      onPressed: state.isCalculating
                          ? null
                          : controller.calculate,
                      icon: state.isCalculating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.calculate_outlined),
                      label: const Text('Calculate'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  const ButtonSegment(value: 0, label: Text('Inputs')),
                  ButtonSegment(value: 1, label: Text(isCompact ? 'Wind.' : 'Windings')),
                  ButtonSegment(value: 2, label: Text(isCompact ? 'Dims' : 'Dimensions & Cost')),
                  ButtonSegment(value: 3, label: Text(isCompact ? 'Out' : 'Outputs')),
                ],
                selected: <int>{_tab},
                onSelectionChanged: (value) => setState(() => _tab = value.first),
              ),
              const SizedBox(height: 12),
              Expanded(child: switch (_tab) {
                0 => _InputsTab(controller: controller),
                1 => _WindingsTab(controller: controller),
                2 => _DimensionsTab(controller: controller),
                3 => _ResultsTab(controller: controller),
                _ => _ResultsTab(controller: controller),
              }),
            ],
          ),
        );
      },
    );
  }
}

class _InputsTab extends StatelessWidget {
  const _InputsTab({required this.controller});
  final MultiWindingController controller;
  @override
  Widget build(BuildContext context) {
    final d = controller.state.design;
    return ListView(children: [
      _FormSection(title: 'Ratings, connection & taps', extra: _ConfigurationField(controller: controller), fields: [
        _Field('kVA', d.textAt('kVA'), (v) => controller.update('kVA', v)),
        _Field('Primary voltage', d.textAt('primaryVoltage'), (v) => controller.update('primaryVoltage', v)),
        _Field('Secondary voltage', d.textAt('secondaryVoltage'), (v) => controller.update('secondaryVoltage', v)),
        _Field('Frequency', d.textAt('frequency'), (v) => controller.update('frequency', v)),
        _ChoiceField('Connection', d.textAt('vectorGroup'), const ['Dyn11', 'Dd0', 'Yyn0', 'Yd11'], (v) => controller.update('vectorGroup', v)),
        _Field('Tap steps %', d.textAt('tapStepsPercent'), (v) => controller.update('tapStepsPercent', v)),
        _Field('Positive taps', d.textAt('tapStepsPositive'), (v) => controller.update('tapStepsPositive', v)),
        _Field('Negative taps', d.textAt('tapStepsNegative'), (v) => controller.update('tapStepsNegative', v)),
        _ChoiceField('Tap changer', d.readPath('isOLTC') == true ? 'OLTC' : 'OCTC', const ['OCTC', 'OLTC'], (v) => controller.update('isOLTC', v == 'OLTC')),
      ]),
      const SizedBox(height: 12),
      _FormSection(title: 'Core & losses', fields: [
        _Field('Build factor', d.textAt('buildFactor'), (v) => controller.update('buildFactor', v)),
        _Field('Flux density', d.textAt('fluxDensity'), (v) => controller.update('fluxDensity', v)),
        _Field('Core diameter', d.textAt('core.coreDia'), (v) => controller.update('core.coreDia', v), locked: d.readPath('lockedAttributes.coreLock.coreDia') == true, onLock: () => controller.toggleCoreLock('coreDia')),
        _Field('Limb height', d.textAt('core.limbHt'), (v) => controller.update('core.limbHt', v), locked: d.readPath('lockedAttributes.coreLock.limbHt') == true, onLock: () => controller.toggleCoreLock('limbHt')),
        _Field('Centre distance', d.textAt('core.cenDist'), (v) => controller.update('core.cenDist', v)),
        _Field('Net core area', d.textAt('core.area'), (v) => controller.update('core.area', v)),
        _ChoiceField('Core material', d.textAt('core.coreMaterial'), const ['NipM4', 'NipM5', 'NipM6', 'AksAK'], (v) => controller.update('core.coreMaterial', v)),
        _ChoiceField('Core type', d.textAt('core.coreType'), const ['PRIME', 'STEP_LAP'], (v) => controller.update('core.coreType', v)),
        _Field('Core loss', d.textAt('coreLoss'), (v) => controller.update('coreLoss', v)),
        _Field('Limit W', d.textAt('limitW'), (v) => controller.update('limitW', v)),
        _Field('Limit EZ', d.textAt('limitEz'), (v) => controller.update('limitEz', v)),
        _Field('EZ', d.textAt('ez'), (v) => controller.update('ez', v)),
        _Field('Volts / turn', d.textAt('performance.voltsPerTurn'), (v) => controller.update('performance.voltsPerTurn', v)),
      ]),
      const SizedBox(height: 12),
      _FormSection(title: 'Tank & cooling', fields: [
        _Field('Winding to tank gap', d.textAt('tank.wdgToTankGap'), (v) => controller.update('tank.wdgToTankGap', v)),
        _Field('Connection gap', d.textAt('tank.connectionGap'), (v) => controller.update('tank.connectionGap', v)),
        _Field('Top yoke to cover', d.textAt('tank.topYokeToCoverGap'), (v) => controller.update('tank.topYokeToCoverGap', v)),
        _Field('Tank length', d.textAt('tank.tankLength'), (v) => controller.update('tank.tankLength', v)),
        _Field('Tank width', d.textAt('tank.tankWidth'), (v) => controller.update('tank.tankWidth', v)),
        _Field('Tank height', d.textAt('tank.tankHeight'), (v) => controller.update('tank.tankHeight', v)),
        _ChoiceField('Cooling method', d.textAt('eRadiatorType'), const ['RADIATOR', 'PIPES', 'CORRUGATION'], (v) => controller.update('eRadiatorType', v)),
        _Field('Winding temperature', d.textAt('windingTemp'), (v) => controller.update('windingTemp', v)),
        _Field('Oil temperature', d.textAt('topOilTemp'), (v) => controller.update('topOilTemp', v)),
        _Field('Ambient temperature', d.textAt('ambientTemp'), (v) => controller.update('ambientTemp', v)),
      ]),
    ]);
  }
}

class _ConfigurationField extends StatelessWidget {
  const _ConfigurationField({required this.controller});
  final MultiWindingController controller;
  @override
  Widget build(BuildContext context) {
    const values = ['2_WDG_LV_HV_MAIN', '3_WDG_LV_HV_MAIN_OUTER', '4_WDG_LV_HV_MAIN_CORSE_OUTER', '4_WDG_LV_HV_MAIN_FINE_OUTER', '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER'];
    final value = controller.state.design.textAt('windingConfiguration');
    final screenWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(width: screenWidth < 640 ? screenWidth - 72 : 310, child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, isExpanded: true, decoration: const InputDecoration(labelText: 'Winding configuration', border: OutlineInputBorder()), items: values.map((v) => DropdownMenuItem(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) controller.update('windingConfiguration', v); }));
  }
}

class _WindingsTab extends StatelessWidget {
  const _WindingsTab({required this.controller});
  final MultiWindingController controller;
  static const labels = {'lv': 'LV', 'hvMain': 'HV Main', 'corse': 'Corse', 'fine': 'Fine', 'outer': 'Outer'};
  static const prefixes = {'lv': 'lv', 'hvMain': 'hv', 'corse': 'corse', 'fine': 'fine', 'outer': 'outer'};
  static const locks = {'lv': 'lvWindings', 'hvMain': 'hvWindings', 'corse': 'corseWindings', 'fine': 'fineWindings', 'outer': 'outerWindings'};
  @override
  Widget build(BuildContext context) {
    final d = controller.state.design;
    return ListView(children: controller.activeWindings.map((id) {
      final prefix = prefixes[id]!;
      final group = locks[id]!;
      return _FormSection(title: labels[id]!, fields: [
        _Field('Winding type', d.textAt('${prefix}WindingType'), (v) => controller.update('${prefix}WindingType', v)),
        _ChoiceField('Conductor material', d.textAt('${prefix == 'lv' ? 'lV' : prefix == 'hv' ? 'hV' : prefix}ConductorMaterial'), const ['Cu', 'Al'], (v) => controller.update('${prefix == 'lv' ? 'lV' : prefix == 'hv' ? 'hV' : prefix}ConductorMaterial', v)),
        _Field('Current density', d.textAt('${prefix}CurrentDensity'), (v) => controller.update('${prefix}CurrentDensity', v)),
        _Field('Turns / phase', d.textAt('part2Windings.$id.turnsPerPhase'), (v) => controller.update('part2Windings.$id.turnsPerPhase', v), locked: d.readPath('lockedAttributes.$group.turnsPerPhase') == true, onLock: () => controller.toggleWindingLock(id, 'turnsPerPhase')),
        _Field('Phase current', d.textAt('part2Windings.$id.phaseCurrent'), (v) => controller.update('part2Windings.$id.phaseCurrent', v)),
        _Field('Conductor cross section', d.textAt('part2Windings.$id.condCrossSec'), (v) => controller.update('part2Windings.$id.condCrossSec', v)),
        _Field('Conductor breadth', d.textAt('part2Windings.$id.condBreadth'), (v) => controller.update('part2Windings.$id.condBreadth', v), locked: d.readPath('lockedAttributes.$group.conductorSizes') == true, onLock: () => controller.toggleWindingLock(id, 'conductorSizes')),
        _Field('Conductor height', d.textAt('part2Windings.$id.condHeight'), (v) => controller.update('part2Windings.$id.condHeight', v)),
        _Field('Conductor diameter', d.textAt('part2Windings.$id.conductorDiameter'), (v) => controller.update('part2Windings.$id.conductorDiameter', v)),
        _Field('Radial parallel', d.textAt('part2Windings.$id.radialParallelCond'), (v) => controller.update('part2Windings.$id.radialParallelCond', v), locked: d.readPath('lockedAttributes.$group.noInParallel') == true, onLock: () => controller.toggleWindingLock(id, 'noInParallel')),
        _Field('Axial parallel', d.textAt('part2Windings.$id.axialParallelCond'), (v) => controller.update('part2Windings.$id.axialParallelCond', v)),
        _Field('Conductor insulation', d.textAt('part2Windings.$id.condInsulation'), (v) => controller.update('part2Windings.$id.condInsulation', v)),
        _Field('Inter-layer insulation', d.textAt('part2Windings.$id.interLayerInsulation'), (v) => controller.update('part2Windings.$id.interLayerInsulation', v)),
        _Field('End clearances', d.textAt('part2Windings.$id.endClearances'), (v) => controller.update('part2Windings.$id.endClearances', v)),
        _Field('Number of layers', d.textAt('part2Windings.$id.noOfLayers'), (v) => controller.update('part2Windings.$id.noOfLayers', v)),
        _Field('Ducts', d.textAt('part2Windings.$id.ducts'), (v) => controller.update('part2Windings.$id.ducts', v)),
        _Field('Duct size', d.textAt('part2Windings.$id.ductSize'), (v) => controller.update('part2Windings.$id.ductSize', v)),
        _Field('Disc duct size', d.textAt('part2Windings.$id.discDuctSize'), (v) => controller.update('part2Windings.$id.discDuctSize', v)),
        _Field('Turns / layer', d.textAt('part2Windings.$id.turnsLayers'), (v) => controller.update('part2Windings.$id.turnsLayers', v)),
        _Field('Winding length', d.textAt('part2Windings.$id.windingLength'), (v) => controller.update('part2Windings.$id.windingLength', v)),
        _Field('Eddy / stray loss', d.textAt('part2Windings.$id.eddyStrayLoss'), (v) => controller.update('part2Windings.$id.eddyStrayLoss', v)),
        _Field('Temperature gradient', d.textAt('part2Windings.$id.tempGradDegC'), (v) => controller.update('part2Windings.$id.tempGradDegC', v)),
        _Field('Bare / insulated weight', d.textAt('part2Windings.$id.weightBareInsulated'), (v) => controller.update('part2Windings.$id.weightBareInsulated', v)),
        _Field('Load loss', d.textAt('part2Windings.$id.loadLoss'), (v) => controller.update('part2Windings.$id.loadLoss', v)),
        _SwitchField('Round conductor', d.readPath('part2Windings.$id.isConductorRound') == true, (v) => controller.update('part2Windings.$id.isConductorRound', v)),
        _SwitchField('Enamel conductor', d.readPath('part2Windings.$id.isEnamel') == true, (v) => controller.update('part2Windings.$id.isEnamel', v)),
      ]);
    }).toList());
  }
}

class _DimensionsTab extends StatelessWidget {
  const _DimensionsTab({required this.controller});
  final MultiWindingController controller;
  @override
  Widget build(BuildContext context) {
    final d = controller.state.design;
    final active = controller.activeWindings;
    return ListView(children: [
      _FormSection(title: 'Coil dimensions & gaps', fields: [
      _Field('Core to LV gap', d.textAt('coilDimensions.coreGap'), (v) => controller.update('coilDimensions.coreGap', v)),
      _Field('LV to HV gap', d.textAt('coilDimensions.lvhvgap'), (v) => controller.update('coilDimensions.lvhvgap', v)),
      if (active.contains('outer') && !active.contains('corse') && !active.contains('fine')) _Field('HV to outer gap', d.textAt('coilDimensions.hvhvgap'), (v) => controller.update('coilDimensions.hvhvgap', v)),
      if (active.contains('corse')) _Field('HV to corse gap', d.textAt('multiCoilDimensions.gaps.hvMainToCorseGap'), (v) => controller.update('multiCoilDimensions.gaps.hvMainToCorseGap', v)),
      if (active.contains('corse') && active.contains('fine')) _Field('Corse to fine gap', d.textAt('multiCoilDimensions.gaps.corseToFineGap'), (v) => controller.update('multiCoilDimensions.gaps.corseToFineGap', v)),
      if (active.contains('corse') && active.contains('outer')) _Field('Corse to outer gap', d.textAt('multiCoilDimensions.gaps.corseToOuterGap'), (v) => controller.update('multiCoilDimensions.gaps.corseToOuterGap', v)),
      if (active.contains('fine') && !active.contains('corse')) _Field('HV to fine gap', d.textAt('multiCoilDimensions.gaps.hvMainToFineGap'), (v) => controller.update('multiCoilDimensions.gaps.hvMainToFineGap', v)),
      if (active.contains('fine') && active.contains('outer')) _Field('Fine to outer gap', d.textAt('multiCoilDimensions.gaps.fineToOuterGap'), (v) => controller.update('multiCoilDimensions.gaps.fineToOuterGap', v)),
      _Field('LV inside diameter', d.textAt('coilDimensions.lvid'), (v) => controller.update('coilDimensions.lvid', v)),
      _Field('LV radial build', d.textAt('coilDimensions.lvradial'), (v) => controller.update('coilDimensions.lvradial', v)),
      _Field('LV outside diameter', d.textAt('coilDimensions.lvod'), (v) => controller.update('coilDimensions.lvod', v)),
      _Field('HV inside diameter', d.textAt('coilDimensions.hvid'), (v) => controller.update('coilDimensions.hvid', v)),
      _Field('HV radial build', d.textAt('coilDimensions.hvradial'), (v) => controller.update('coilDimensions.hvradial', v)),
      _Field('HV outside diameter', d.textAt('coilDimensions.hvod'), (v) => controller.update('coilDimensions.hvod', v)),
      if (active.contains('corse')) ..._multiCoilFields(d, controller, 'corse', 'Corse'),
      if (active.contains('fine')) ..._multiCoilFields(d, controller, 'fine', 'Fine'),
      if (active.contains('outer')) ..._multiCoilFields(d, controller, 'outer', 'Outer'),
    ]),
    const SizedBox(height: 12),
    _FormSection(title: 'Material costs', fields: [
      _Field('Copper cost / kg', d.textAt('cost.copperCostPerKg'), (v) => controller.update('cost.copperCostPerKg', v)),
      _Field('Aluminium cost / kg', d.textAt('cost.aluminiumCostPerKg'), (v) => controller.update('cost.aluminiumCostPerKg', v)),
      _Field('Core cost / kg', d.textAt('cost.coreCostPerKg'), (v) => controller.update('cost.coreCostPerKg', v)),
      _Field('Steel cost / kg', d.textAt('cost.steelCostPerKg'), (v) => controller.update('cost.steelCostPerKg', v)),
      _Field('Oil cost / kg', d.textAt('cost.oilCostPerKg'), (v) => controller.update('cost.oilCostPerKg', v)),
      _Field('Insulation cost / kg', d.textAt('cost.insulationCostPerKg'), (v) => controller.update('cost.insulationCostPerKg', v)),
      _Field('Radiator cost / kg', d.textAt('cost.radiatorCostPerKg'), (v) => controller.update('cost.radiatorCostPerKg', v)),
      _Field('Major material cost', d.textAt('cost.capitalCost'), (v) => controller.update('cost.capitalCost', v)),
    ]),
    ]);
  }

  List<Widget> _multiCoilFields(dynamic design, MultiWindingController controller, String id, String label) => [
    _Field('$label inside diameter', design.textAt('multiCoilDimensions.$id.id'), (v) => controller.update('multiCoilDimensions.$id.id', v)),
    _Field('$label radial build', design.textAt('multiCoilDimensions.$id.radial'), (v) => controller.update('multiCoilDimensions.$id.radial', v)),
    _Field('$label outside diameter', design.textAt('multiCoilDimensions.$id.od'), (v) => controller.update('multiCoilDimensions.$id.od', v)),
  ];
}

class _ResultsTab extends StatelessWidget {
  const _ResultsTab({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    if (design.readPath('calculationResponse') == null) {
      return const Center(
        child: Text('Calculate the design to view electrical, weight, and cost results.'),
      );
    }
    return ListView(
      children: [
        _ResultSection(
          title: 'Electrical performance',
          values: <_ResultValue>[
            _ResultValue('No-load loss', design.textAt('performance.noLoadLoss')),
            _ResultValue('Load loss', design.textAt('performance.loadLoss')),
            _ResultValue('Impedance', design.textAt('performance.impedance')),
            _ResultValue('No-load current %', design.textAt('performance.nlCurrentPercentage')),
            _ResultValue('Volts / turn', design.textAt('performance.voltsPerTurn')),
          ],
        ),
        const SizedBox(height: 12),
        _ResultSection(
          title: 'Weights',
          values: <_ResultValue>[
            _ResultValue('Core', design.textAt('core.coreWeight')),
            _ResultValue('Steel', design.textAt('tankAndOilFormulas.totalSteelWeight')),
            _ResultValue('Net oil', design.textAt('tankAndOilFormulas.totalOil')),
            _ResultValue('Insulation', design.textAt('tankAndOilFormulas.insulationWeight')),
            _ResultValue('Radiator', design.textAt('tankAndOilFormulas.totalRadiatorWeight')),
            _ResultValue('Transformer', design.textAt('tankAndOilFormulas.transformerWeight')),
          ],
        ),
        const SizedBox(height: 12),
        _ResultSection(
          title: 'Conductor estimates',
          values: [
            for (final winding in controller.activeWindings) ...[
              _ResultValue('${_windingLabel(winding)} weight', design.textAt('multiCost.conductors.$winding.weight')),
              _ResultValue('${_windingLabel(winding)} cost', design.textAt('multiCost.conductors.$winding.totalCost')),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _ResultSection(
          title: 'Material cost totals',
          values: <_ResultValue>[
            _ResultValue('Conductor', design.textAt('cost.totalCondCost')),
            _ResultValue('Core', design.textAt('cost.totalCoreCost')),
            _ResultValue('Steel', design.textAt('cost.totalSteelCost')),
            _ResultValue('Oil', design.textAt('cost.totalOilCost')),
            _ResultValue('Insulation', design.textAt('cost.totalInsCost')),
            _ResultValue('Radiator', design.textAt('cost.totalRadiatorCost')),
            _ResultValue('Major material total', design.textAt('cost.capitalCost')),
          ],
        ),
      ],
    );
  }

  String _windingLabel(String winding) => switch (winding) {
    'lv' => 'LV',
    'hvMain' => 'HV Main',
    'corse' => 'Corse',
    'fine' => 'Fine',
    _ => 'Outer',
  };
}

class _ResultValue {
  const _ResultValue(this.label, this.value);

  final String label;
  final String value;
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.values});

  final String title;
  final List<_ResultValue> values;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final result in values)
                SizedBox(
                  width: _formFieldWidth(context),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(result.label, style: Theme.of(context).textTheme.labelMedium),
                          const SizedBox(height: 4),
                          Text(result.value.isEmpty ? '-' : result.value, style: Theme.of(context).textTheme.titleSmall),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

double _formFieldWidth(BuildContext context) { final width = MediaQuery.sizeOf(context).width; return width < 640 ? width - 72 : 220; }
class _Field extends StatelessWidget { const _Field(this.label, this.value, this.onChanged, {this.locked = false, this.onLock}); final String label; final String value; final ValueChanged<String> onChanged; final bool locked; final VoidCallback? onLock; @override Widget build(BuildContext context) => SizedBox(width: _formFieldWidth(context), child: TextFormField(initialValue: value, readOnly: locked, onChanged: onChanged, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: onLock == null ? null : IconButton(onPressed: onLock, icon: Icon(locked ? Icons.lock : Icons.lock_open))))); }
class _ChoiceField extends StatelessWidget { const _ChoiceField(this.label, this.value, this.values, this.onChanged); final String label; final String value; final List<String> values; final ValueChanged<String> onChanged; @override Widget build(BuildContext context) => SizedBox(width: _formFieldWidth(context), child: DropdownButtonFormField<String>(value: values.contains(value) ? value : values.first, isExpanded: true, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), items: values.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) { if (value != null) onChanged(value); })); }
class _SwitchField extends StatelessWidget { const _SwitchField(this.label, this.value, this.onChanged); final String label; final bool value; final ValueChanged<bool> onChanged; @override Widget build(BuildContext context) => SizedBox(width: _formFieldWidth(context), child: InputDecorator(decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), child: Switch(value: value, onChanged: onChanged))); }
class _FormSection extends StatelessWidget { const _FormSection({required this.title, required this.fields, this.extra}); final String title; final List<Widget> fields; final Widget? extra; @override Widget build(BuildContext context) { final compact = MediaQuery.sizeOf(context).width < 640; return Card(child: Padding(padding: EdgeInsets.all(compact ? 12 : 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 14), Wrap(spacing: 12, runSpacing: 12, children: [if (extra != null) extra!, ...fields])]))); } }
