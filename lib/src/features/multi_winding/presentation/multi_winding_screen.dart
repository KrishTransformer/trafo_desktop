import 'package:flutter/material.dart';

import '../../../app/app_scope.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../home/domain/models/design_summary.dart';
import '../application/multi_winding_controller.dart';
import '../data/repositories/http_multi_winding_repositories.dart';

const _pageBackground = Color(0xFFF3F6FA);
const _surface = Color(0xFFFFFFFF);
const _softSurface = Color(0xFFF7FAFC);
const _inputFill = Color(0xFFEEF1F5);
const _accentInputFill = Color(0xFFD7F3FC);
const _border = Color(0x1F0F172A);
const _strongBorder = Color(0x2E0F172A);
const _text = Color(0xFF111827);
const _mutedText = Color(0xFF5F6B7A);
const _blue = Color(0xFF1D4ED8);
const _hvOrange = Color(0xFFFF5B1E);
const _corseAccent = Color(0xFF475569);
const _fineAccent = Color(0xFF0F766E);
const _outerAccent = Color(0xFFB45309);

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
      builder: (context, _) => ColoredBox(
        color: _pageBackground,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _WorkspaceTopBar(
                selectedTab: _tab,
                isCalculating: controller.state.isCalculating,
                onTabChanged: (tab) => setState(() => _tab = tab),
                onReset: controller.reset,
                onCalculate: controller.calculate,
              ),
              const SizedBox(height: 6),
              Expanded(
                child: switch (_tab) {
                  0 => _InputsTab(controller: controller),
                  1 => _WindingsTab(controller: controller),
                  _ => _DimensionsTab(controller: controller),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceTopBar extends StatelessWidget {
  const _WorkspaceTopBar({
    required this.selectedTab,
    required this.isCalculating,
    required this.onTabChanged,
    required this.onReset,
    required this.onCalculate,
  });

  final int selectedTab;
  final bool isCalculating;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onReset;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) => _Surface(
    padding: const EdgeInsets.all(8),
    shadow: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final tabs = _TabStrip(
          selectedTab: selectedTab,
          onChanged: onTabChanged,
        );
        final actions = _TopActions(
          isCalculating: isCalculating,
          onReset: onReset,
          onCalculate: onCalculate,
        );
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [tabs, const SizedBox(height: 8), actions],
          );
        }
        return Row(
          children: [
            Expanded(child: tabs),
            const SizedBox(width: 14),
            SizedBox(width: 238, child: actions),
          ],
        );
      },
    ),
  );
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.selectedTab, required this.onChanged});

  final int selectedTab;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Inputs', 'Windings', 'Dimensions & Cost'];
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0x0A0F172A),
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index == labels.length - 1 ? 0 : 4,
                ),
                child: Material(
                  color: selectedTab == index ? _blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    key: ValueKey('multi-winding-tab-$index'),
                    borderRadius: BorderRadius.circular(6),
                    onTap: () => onChanged(index),
                    child: Center(
                      child: Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selectedTab == index
                              ? Colors.white
                              : _mutedText,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.isCalculating,
    required this.onReset,
    required this.onCalculate,
  });

  final bool isCalculating;
  final VoidCallback onReset;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: isCalculating ? null : onReset,
          icon: const Icon(Icons.restart_alt, size: 18),
          label: const Text('Reset'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
            foregroundColor: _text,
            side: const BorderSide(color: _strongBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton.icon(
          onPressed: isCalculating ? null : onCalculate,
          icon: isCalculating
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.calculate_outlined, size: 18),
          label: const Text('Calculate'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
            backgroundColor: _text,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
      ),
    ],
  );
}

class _InputsTab extends StatelessWidget {
  const _InputsTab({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      children: [
        _Surface(
          padding: const EdgeInsets.all(14),
          shadow: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final main = _MainInputs(controller: controller);
              final side = _CoreAndLosses(controller: controller);
              if (constraints.maxWidth < 1020) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [main, const SizedBox(height: 14), side],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: main),
                  const SizedBox(width: 16),
                  Expanded(child: side),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final tank = _TankPanel(controller: controller);
            final cooling = _CoolingPanel(controller: controller);
            if (constraints.maxWidth < 900) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [tank, const SizedBox(height: 12), cooling],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tank),
                const SizedBox(width: 12),
                Expanded(child: cooling),
              ],
            );
          },
        ),
        if (design.readPath('calculationResponse') != null) ...[
          const SizedBox(height: 12),
          _CalculationSummary(controller: controller),
        ],
      ],
    );
  }
}

class _MainInputs extends StatelessWidget {
  const _MainInputs({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Transformer Inputs'),
        const SizedBox(height: 10),
        _ConfigurationField(controller: controller),
        const SizedBox(height: 10),
        _FieldWrap(
          children: [
            _Field(
              label: 'kVA',
              value: design.textAt('kVA'),
              path: 'kVA',
              onChanged: (value) => controller.update('kVA', value),
            ),
            _Field(
              label: 'Secondary Voltage',
              value: design.textAt('primaryVoltage'),
              path: 'primaryVoltage',
              onChanged: (value) => controller.update('primaryVoltage', value),
            ),
            _Field(
              label: 'Primary Voltage',
              value: design.textAt('secondaryVoltage'),
              path: 'secondaryVoltage',
              onChanged: (value) =>
                  controller.update('secondaryVoltage', value),
            ),
            _Field(
              label: 'Frequency',
              value: design.textAt('frequency'),
              path: 'frequency',
              highlighted: true,
              onChanged: (value) => controller.update('frequency', value),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _FieldWrap(
          children: [
            _ChoiceField(
              label: 'Connection',
              value: design.textAt('vectorGroup'),
              values: const ['Dyn11', 'Dd0', 'Yyn0', 'Yd11'],
              path: 'vectorGroup',
              onChanged: (value) => controller.update('vectorGroup', value),
            ),
            _Field(
              label: 'Tap Steps %',
              value: design.textAt('tapStepsPercent'),
              path: 'tapStepsPercent',
              onChanged: (value) => controller.update('tapStepsPercent', value),
            ),
            _Field(
              label: '+ ve',
              value: design.textAt('tapStepsPositive'),
              path: 'tapStepsPositive',
              onChanged: (value) =>
                  controller.update('tapStepsPositive', value),
            ),
            _Field(
              label: '- ve',
              value: design.textAt('tapStepsNegative'),
              path: 'tapStepsNegative',
              onChanged: (value) =>
                  controller.update('tapStepsNegative', value),
            ),
            _ChoiceField(
              label: 'Tap Changer',
              value: design.readPath('isOLTC') == true ? 'OLTC' : 'OCTC',
              values: const ['OCTC', 'OLTC'],
              path: 'isOLTC',
              onChanged: (value) =>
                  controller.update('isOLTC', value == 'OLTC'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _WindingOverview(controller: controller),
      ],
    );
  }
}

class _CoreAndLosses extends StatelessWidget {
  const _CoreAndLosses({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InsetPanel(
          title: 'Core Details',
          child: _ResponsiveGrid(
            minCellWidth: 128,
            children: [
              _Field(
                label: 'Build Factor',
                value: design.textAt('buildFactor'),
                path: 'buildFactor',
                fluid: true,
                onChanged: (value) => controller.update('buildFactor', value),
              ),
              _Field(
                label: 'Flux Density',
                value: design.textAt('fluxDensity'),
                path: 'fluxDensity',
                fluid: true,
                onChanged: (value) => controller.update('fluxDensity', value),
              ),
              _Field(
                label: 'Core Diameter',
                value: design.textAt('core.coreDia'),
                path: 'core.coreDia',
                highlighted: true,
                fluid: true,
                locked:
                    design.readPath('lockedAttributes.coreLock.coreDia') ==
                    true,
                onLock: () => controller.toggleCoreLock('coreDia'),
                onChanged: (value) => controller.update('core.coreDia', value),
              ),
              _Field(
                label: 'Limb Ht.',
                value: design.textAt('core.limbHt'),
                path: 'core.limbHt',
                highlighted: true,
                fluid: true,
                locked:
                    design.readPath('lockedAttributes.coreLock.limbHt') == true,
                onLock: () => controller.toggleCoreLock('limbHt'),
                onChanged: (value) => controller.update('core.limbHt', value),
              ),
              _Field(
                label: 'Cen Dist',
                value: design.textAt('core.cenDist'),
                path: 'core.cenDist',
                fluid: true,
                onChanged: (value) => controller.update('core.cenDist', value),
              ),
              _Field(
                label: 'Net Core Area',
                value: design.textAt('core.area'),
                path: 'core.area',
                highlighted: true,
                fluid: true,
                onChanged: (value) => controller.update('core.area', value),
              ),
              _Field(
                label: 'W/Kg',
                value: design.textAt('hvFormulas.specificLoss'),
                path: 'hvFormulas.specificLoss',
                fluid: true,
                onChanged: (value) =>
                    controller.update('hvFormulas.specificLoss', value),
              ),
              _ChoiceField(
                label: 'Core Material',
                value: design.textAt('core.coreMaterial'),
                values: _coreMaterials,
                path: 'core.coreMaterial',
                fluid: true,
                onChanged: (value) =>
                    controller.update('core.coreMaterial', value),
              ),
              _ChoiceField(
                label: 'Core Type',
                value: design.textAt('core.coreType'),
                values: const ['PRIME', 'STEP_LAP'],
                path: 'core.coreType',
                fluid: true,
                onChanged: (value) => controller.update('core.coreType', value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _MetricBar(
          values: [
            (
              'Volts Per Turn',
              _firstText(design, const [
                'revisedVoltsPerTurn',
                'performance.voltsPerTurn',
              ]),
            ),
            ('Revised Flux', design.textAt('revisedFluxDensity')),
          ],
        ),
        const SizedBox(height: 10),
        _InsetPanel(
          title: 'Losses',
          child: _ResponsiveGrid(
            minCellWidth: 128,
            children: [
              _Field(
                label: 'Tank Loss',
                value: design.textAt('tank.tankLoss'),
                path: 'tank.tankLoss',
                highlighted: true,
                fluid: true,
                onChanged: (value) => controller.update('tank.tankLoss', value),
              ),
              _Field(
                label: 'Load Loss',
                value: design.textAt('loadLoss'),
                path: 'loadLoss',
                fluid: true,
                onChanged: (value) => controller.update('loadLoss', value),
              ),
              _Field(
                label: 'Core Loss',
                value: design.textAt('coreLoss'),
                path: 'coreLoss',
                fluid: true,
                onChanged: (value) => controller.update('coreLoss', value),
              ),
              _Field(
                label: 'Limit W',
                value: design.textAt('limitW'),
                path: 'limitW',
                highlighted: true,
                fluid: true,
                onChanged: (value) => controller.update('limitW', value),
              ),
              _Field(
                label: 'Limit EZ',
                value: design.textAt('limitEz'),
                path: 'limitEz',
                highlighted: true,
                fluid: true,
                onChanged: (value) => controller.update('limitEz', value),
              ),
              _Field(
                label: 'EZ',
                value: design.textAt('ez'),
                path: 'ez',
                fluid: true,
                onChanged: (value) => controller.update('ez', value),
              ),
              _Field(
                label: 'Losses at 50%',
                value: design.textAt('lossesAt50Percent'),
                path: 'lossesAt50Percent',
                fluid: true,
                onChanged: (value) =>
                    controller.update('lossesAt50Percent', value),
              ),
              _Field(
                label: 'Losses at 100%',
                value: design.textAt('lossesAt100Percent'),
                path: 'lossesAt100Percent',
                fluid: true,
                onChanged: (value) =>
                    controller.update('lossesAt100Percent', value),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WindingOverview extends StatelessWidget {
  const _WindingOverview({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final windings = _activeWindingSpecs(controller);
    final design = controller.state.design;
    return _MatrixFrame(
      minWidth: 126 + (windings.length * 154),
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: <int, TableColumnWidth>{
          0: const FixedColumnWidth(126),
          for (var index = 0; index < windings.length; index++)
            index + 1: const FlexColumnWidth(),
        },
        children: [
          _headerRow(windings),
          _matrixRow(
            label: 'Voltage',
            windings: windings,
            builder: (winding) => _MatrixField(
              value: design.textAt(winding.voltagePath),
              path: winding.voltagePath,
              onChanged: (value) =>
                  controller.update(winding.voltagePath, value),
            ),
          ),
          _matrixRow(
            label: 'Winding Type',
            windings: windings,
            builder: (winding) => _MatrixChoiceField(
              value: design.textAt(winding.typePath),
              values: winding.id == 'lv' ? _lvWindingTypes : _hvWindingTypes,
              path: winding.typePath,
              onChanged: (value) => controller.update(winding.typePath, value),
            ),
          ),
          _matrixRow(
            label: 'Current Density',
            windings: windings,
            builder: (winding) => _DensityMaterialCell(
              density: design.textAt(winding.currentDensityPath),
              material: design.textAt(winding.materialPath),
              densityPath: winding.currentDensityPath,
              materialPath: winding.materialPath,
              controller: controller,
            ),
          ),
          _matrixRow(
            label: 'Cond. Size',
            windings: windings,
            highlighted: true,
            builder: (winding) =>
                _ConductorSizeCell(controller: controller, winding: winding),
          ),
          _matrixRow(
            label: 'Load Loss',
            windings: windings,
            builder: (winding) {
              final path = 'part2Windings.${winding.id}.loadLoss';
              return _MatrixField(
                value: design.textAt(path),
                path: path,
                onChanged: (value) => controller.update(path, value),
              );
            },
          ),
          _matrixRow(
            label: 'Temp. Grad.',
            windings: windings,
            isLast: true,
            builder: (winding) {
              final path = 'part2Windings.${winding.id}.tempGradDegC';
              return _MatrixField(
                value: design.textAt(path),
                path: path,
                onChanged: (value) => controller.update(path, value),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TankPanel extends StatelessWidget {
  const _TankPanel({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    return _InsetPanel(
      title: 'Tank Details',
      surface: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResponsiveGrid(
            minCellWidth: 148,
            children: [
              _Field(
                label: 'Wdg-Tank Gap',
                value: design.textAt('tank.wdgToTankGap'),
                path: 'tank.wdgToTankGap',
                highlighted: true,
                fluid: true,
                onChanged: (value) =>
                    controller.update('tank.wdgToTankGap', value),
              ),
              _Field(
                label: 'Connection Gap',
                value: design.textAt('tank.connectionGap'),
                path: 'tank.connectionGap',
                highlighted: true,
                fluid: true,
                onChanged: (value) =>
                    controller.update('tank.connectionGap', value),
              ),
              _Field(
                label: 'Top Yoke - Cover',
                value: design.textAt('tank.topYokeToCoverGap'),
                path: 'tank.topYokeToCoverGap',
                highlighted: true,
                fluid: true,
                onChanged: (value) =>
                    controller.update('tank.topYokeToCoverGap', value),
              ),
              _Field(
                label: 'Tank Length',
                value: design.textAt('tank.tankLength'),
                path: 'tank.tankLength',
                fluid: true,
                onChanged: (value) =>
                    controller.update('tank.tankLength', value),
              ),
              _Field(
                label: 'Tank Width',
                value: design.textAt('tank.tankWidth'),
                path: 'tank.tankWidth',
                fluid: true,
                onChanged: (value) =>
                    controller.update('tank.tankWidth', value),
              ),
              _Field(
                label: 'Tank Height',
                value: design.textAt('tank.tankHeight'),
                path: 'tank.tankHeight',
                fluid: true,
                onChanged: (value) =>
                    controller.update('tank.tankHeight', value),
              ),
              _Field(
                label: 'Tank Capacity',
                value: design.textAt('tank.tankCapacity'),
                path: 'tank.tankCapacity',
                fluid: true,
                onChanged: (value) =>
                    controller.update('tank.tankCapacity', value),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _DetailSummary(
            entries: [
              ('Tank (L x B x H)', design.textAt('tank.tankDimension')),
              ('Overall Dimensions', design.textAt('tank.overallDimension')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoolingPanel extends StatelessWidget {
  const _CoolingPanel({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    final coolingStatement = design.textAt(
      'tankAndOilFormulas.coolingStatement',
    );
    return _InsetPanel(
      title: 'Cooling Details',
      surface: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResponsiveGrid(
            minCellWidth: 148,
            children: [
              _ChoiceField(
                label: 'Cooling Method',
                value: design.textAt('eRadiatorType'),
                values: const ['RADIATOR', 'PIPES', 'CORRUGATION'],
                path: 'eRadiatorType',
                fluid: true,
                onChanged: (value) => controller.update('eRadiatorType', value),
              ),
              _Field(
                label: 'Winding Temp',
                value: design.textAt('windingTemp'),
                path: 'windingTemp',
                highlighted: true,
                fluid: true,
                onChanged: (value) => controller.update('windingTemp', value),
              ),
              _Field(
                label: 'Oil Temp',
                value: design.textAt('topOilTemp'),
                path: 'topOilTemp',
                highlighted: true,
                fluid: true,
                onChanged: (value) => controller.update('topOilTemp', value),
              ),
              _Field(
                label: 'Amb. Temp',
                value: design.textAt('ambientTemp'),
                path: 'ambientTemp',
                highlighted: true,
                fluid: true,
                onChanged: (value) => controller.update('ambientTemp', value),
              ),
              _Field(
                label: 'Radiator Width',
                value: _firstText(design, const [
                  'radiatorWidth',
                  'tankAndOilFormulas.radiatorWidth',
                ]),
                path: 'radiatorWidth',
                fluid: true,
                onChanged: (value) => controller.update('radiatorWidth', value),
              ),
              _Field(
                label: 'Conservator Dia',
                value: design.textAt('tankAndOilFormulas.conservatorDia'),
                path: 'tankAndOilFormulas.conservatorDia',
                fluid: true,
                onChanged: (value) => controller.update(
                  'tankAndOilFormulas.conservatorDia',
                  value,
                ),
              ),
              _Field(
                label: 'Conservator Length',
                value: design.textAt('tankAndOilFormulas.conservatorLength'),
                path: 'tankAndOilFormulas.conservatorLength',
                fluid: true,
                onChanged: (value) => controller.update(
                  'tankAndOilFormulas.conservatorLength',
                  value,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              coolingStatement.isEmpty ? '-' : coolingStatement,
              style: const TextStyle(
                color: _mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculationSummary extends StatelessWidget {
  const _CalculationSummary({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    return _Surface(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeading('Calculation Summary'),
          const SizedBox(height: 10),
          _MetricGrid(
            values: [
              ('No-load Loss', design.textAt('performance.noLoadLoss')),
              ('Load Loss', design.textAt('performance.loadLoss')),
              ('Impedance', design.textAt('performance.impedance')),
              (
                'No-load Current %',
                design.textAt('performance.nlCurrentPercentage'),
              ),
              ('Top Oil Temperature', design.textAt('topOilTemp')),
              ('kW55', design.textAt('performance.kW55')),
              ('Core Weight', design.textAt('core.coreWeight')),
              (
                'Transformer Weight',
                design.textAt('tankAndOilFormulas.transformerWeight'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfigurationField extends StatelessWidget {
  const _ConfigurationField({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final value = controller.state.design.textAt('windingConfiguration');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 410),
      child: _ChoiceField(
        label: 'Winding Configuration',
        value: value,
        values: _windingConfigurations.keys.toList(),
        displayValues: _windingConfigurations,
        path: 'windingConfiguration',
        width: 410,
        onChanged: (selected) =>
            controller.update('windingConfiguration', selected),
      ),
    );
  }
}

class _WindingsTab extends StatelessWidget {
  const _WindingsTab({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    final windings = _activeWindingSpecs(controller);
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      children: [
        _Surface(
          padding: const EdgeInsets.all(14),
          shadow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeading('Winding Details'),
              const SizedBox(height: 12),
              _MatrixFrame(
                minWidth: 148 + (windings.length * 166),
                child: Table(
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: <int, TableColumnWidth>{
                    0: const FixedColumnWidth(148),
                    for (var index = 0; index < windings.length; index++)
                      index + 1: const FlexColumnWidth(),
                  },
                  children: [
                    _headerRow(windings),
                    for (var index = 0; index < _windingRows.length; index++)
                      _matrixRow(
                        label: _windingRows[index].label,
                        windings: windings,
                        highlighted: _windingRows[index].highlighted,
                        isLast: index == _windingRows.length - 1,
                        builder: (winding) {
                          final row = _windingRows[index];
                          final basePath = 'part2Windings.${winding.id}';
                          if (row.key == 'conductorSizes') {
                            return _ConductorSizeCell(
                              controller: controller,
                              winding: winding,
                            );
                          }
                          if (row.key == 'condInsulation') {
                            return _InsulationCell(
                              controller: controller,
                              winding: winding,
                            );
                          }
                          if (row.key == 'noInParallel') {
                            return _ParallelCell(
                              controller: controller,
                              winding: winding,
                            );
                          }
                          if (row.key == 'noOfDuctsWidth') {
                            return _DuctCell(
                              controller: controller,
                              winding: winding,
                            );
                          }
                          final path = '$basePath.${row.key}';
                          final hasLock = row.key == 'turnsPerPhase';
                          final locked =
                              hasLock &&
                              design.readPath(
                                    'lockedAttributes.${winding.lockGroup}.turnsPerPhase',
                                  ) ==
                                  true;
                          return _MatrixField(
                            value: design.textAt(path),
                            path: path,
                            highlighted: row.highlighted,
                            locked: locked,
                            onLock: hasLock
                                ? () => controller.toggleWindingLock(
                                    winding.id,
                                    'turnsPerPhase',
                                  )
                                : null,
                            onChanged: (value) =>
                                controller.update(path, value),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DimensionsTab extends StatelessWidget {
  const _DimensionsTab({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(top: 4, bottom: 12),
    children: [
      _Surface(
        padding: const EdgeInsets.all(14),
        shadow: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final dimensions = _DimensionsPane(controller: controller);
            final costs = _CostPane(controller: controller);
            if (constraints.maxWidth < 1120) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [dimensions, const SizedBox(height: 18), costs],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: dimensions),
                const SizedBox(width: 18),
                Expanded(child: costs),
              ],
            );
          },
        ),
      ),
    ],
  );
}

class _DimensionsPane extends StatelessWidget {
  const _DimensionsPane({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    final windings = _activeWindingSpecs(controller);
    final gaps = _gapFields(windings);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Coil Winding Dimensions'),
        const SizedBox(height: 10),
        _FieldWrap(
          children: [
            for (final gap in gaps)
              _Field(
                label: gap.$1,
                value: design.textAt(gap.$2),
                path: gap.$2,
                highlighted: true,
                onChanged: (value) => controller.update(gap.$2, value),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _MatrixFrame(
          minWidth: 118 + (windings.length * 132),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: <int, TableColumnWidth>{
              0: const FixedColumnWidth(118),
              for (var index = 0; index < windings.length; index++)
                index + 1: const FlexColumnWidth(),
            },
            children: [
              _headerRow(windings),
              for (
                var rowIndex = 0;
                rowIndex < _dimensionRows.length;
                rowIndex++
              )
                _matrixRow(
                  label: _dimensionRows[rowIndex].$1,
                  windings: windings,
                  isLast: rowIndex == _dimensionRows.length - 1,
                  builder: (winding) {
                    final path = winding.dimensionPath(
                      _dimensionRows[rowIndex].$2,
                    );
                    return _MatrixField(
                      value: design.textAt(path),
                      path: path,
                      onChanged: (value) => controller.update(path, value),
                    );
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailSummary(
          entries: [
            ('Core Dia', design.textAt('core.coreDia')),
            (
              'Active Part Size',
              design.textAt('coilDimensions.activePartSize'),
            ),
          ],
          horizontal: true,
        ),
      ],
    );
  }
}

class _CostPane extends StatelessWidget {
  const _CostPane({required this.controller});

  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    final windings = _activeWindingSpecs(controller);
    final rows = <_CostRow>[
      for (final winding in windings)
        _CostRow(
          'Conductor ${winding.label} '
              '(${design.textAt(winding.materialPath).isEmpty ? 'Cu' : design.textAt(winding.materialPath)})',
          'multiCost.conductors.${winding.id}.weight',
          design.textAt(winding.materialPath) == 'Al'
              ? 'cost.aluminiumCostPerKg'
              : 'cost.copperCostPerKg',
          'multiCost.conductors.${winding.id}.totalCost',
        ),
      const _CostRow(
        'Core',
        'core.coreWeight',
        'cost.coreCostPerKg',
        'cost.totalCoreCost',
      ),
      const _CostRow(
        'Steel',
        'tankAndOilFormulas.totalSteelWeight',
        'cost.steelCostPerKg',
        'cost.totalSteelCost',
      ),
      const _CostRow(
        'Net Oil',
        'tankAndOilFormulas.totalOil',
        'cost.oilCostPerKg',
        'cost.totalOilCost',
      ),
      const _CostRow(
        'Insulation',
        'tankAndOilFormulas.insulationWeight',
        'cost.insulationCostPerKg',
        'cost.totalInsCost',
      ),
      const _CostRow(
        'Radiator',
        'tankAndOilFormulas.totalRadiatorWeight',
        'cost.radiatorCostPerKg',
        'cost.totalRadiatorCost',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading('Cost Estimations'),
        const SizedBox(height: 10),
        _Field(
          label: 'Major Material Cost',
          value: design.textAt('cost.capitalCost'),
          path: 'cost.capitalCost',
          highlighted: true,
          width: 260,
          onChanged: (value) => controller.update('cost.capitalCost', value),
        ),
        const SizedBox(height: 12),
        _MatrixFrame(
          minWidth: 690,
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: const <int, TableColumnWidth>{
              0: FlexColumnWidth(1.3),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(),
            },
            children: [
              TableRow(
                children: [
                  for (final label in const [
                    'Material',
                    'Weight',
                    'Cost / Kg',
                    'Total Cost',
                  ])
                    _TableHeaderCell(label: label),
                ],
              ),
              for (var index = 0; index < rows.length; index++)
                TableRow(
                  decoration: BoxDecoration(
                    border: index == rows.length - 1
                        ? null
                        : const Border(bottom: BorderSide(color: _border)),
                  ),
                  children: [
                    _TableLabelCell(label: rows[index].label),
                    _TableInputCell(
                      child: _MatrixField(
                        value: design.textAt(rows[index].weightPath),
                        path: rows[index].weightPath,
                        onChanged: (value) =>
                            controller.update(rows[index].weightPath, value),
                      ),
                    ),
                    _TableInputCell(
                      highlighted: true,
                      child: _MatrixField(
                        value: design.textAt(rows[index].costPath),
                        path: rows[index].costPath,
                        highlighted: true,
                        onChanged: (value) =>
                            controller.update(rows[index].costPath, value),
                      ),
                    ),
                    _TableInputCell(
                      child: _MatrixField(
                        value: design.textAt(rows[index].totalPath),
                        path: rows[index].totalPath,
                        onChanged: (value) =>
                            controller.update(rows[index].totalPath, value),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CostRow {
  const _CostRow(this.label, this.weightPath, this.costPath, this.totalPath);

  final String label;
  final String weightPath;
  final String costPath;
  final String totalPath;
}

class _WindingRow {
  const _WindingRow(this.key, this.label, {this.highlighted = false});

  final String key;
  final String label;
  final bool highlighted;
}

const _windingRows = <_WindingRow>[
  _WindingRow('turnsPerPhase', 'No. of Turns', highlighted: true),
  _WindingRow('phaseCurrent', 'Phase Current (A)'),
  _WindingRow('currentDensity', 'Current Density (A/mm2)'),
  _WindingRow('condCrossSec', 'Cond. Cross Sec (mm2)'),
  _WindingRow('conductorSizes', 'Conductor Sizes (mm)', highlighted: true),
  _WindingRow('condInsulation', 'Cond. Insulation (mm)', highlighted: true),
  _WindingRow('noInParallel', 'No. in Parallel', highlighted: true),
  _WindingRow('windingLength', 'Winding Length (mm)'),
  _WindingRow('noOfLayers', 'No. of Layers', highlighted: true),
  _WindingRow(
    'interLayerInsulation',
    'Inter Layer Insulation (mm)',
    highlighted: true,
  ),
  _WindingRow('noOfDuctsWidth', 'No. of Ducts / Width', highlighted: true),
  _WindingRow('discDuctSize', 'Disc Duct Size (mm)', highlighted: true),
  _WindingRow('turnsLayers', 'Turns / Layers'),
  _WindingRow('endClearances', 'End Clearances (mm)', highlighted: true),
  _WindingRow('eddyStrayLoss', 'Eddy (Stray) Loss (%)'),
  _WindingRow('tempGradDegC', 'Temp. Grad. deg C'),
  _WindingRow('weightBareInsulated', 'Wgt Bare / Insulated (Kg)'),
  _WindingRow('loadLoss', 'Load Loss (W)'),
];

class _WindingSpec {
  const _WindingSpec({
    required this.id,
    required this.label,
    required this.color,
    required this.voltagePath,
    required this.typePath,
    required this.currentDensityPath,
    required this.materialPath,
    required this.lockGroup,
  });

  final String id;
  final String label;
  final Color color;
  final String voltagePath;
  final String typePath;
  final String currentDensityPath;
  final String materialPath;
  final String lockGroup;

  String dimensionPath(String dimension) => switch ((id, dimension)) {
    ('lv', 'id') => 'coilDimensions.lvid',
    ('lv', 'radial') => 'coilDimensions.lvradial',
    ('lv', 'od') => 'coilDimensions.lvod',
    ('hvMain', 'id') => 'coilDimensions.hvid',
    ('hvMain', 'radial') => 'coilDimensions.hvradial',
    ('hvMain', 'od') => 'coilDimensions.hvod',
    (_, _) => 'multiCoilDimensions.$id.$dimension',
  };
}

const _windingSpecs = <_WindingSpec>[
  _WindingSpec(
    id: 'lv',
    label: 'LV',
    color: _blue,
    voltagePath: 'primaryVoltage',
    typePath: 'lvWindingType',
    currentDensityPath: 'lvCurrentDensity',
    materialPath: 'lVConductorMaterial',
    lockGroup: 'lvWindings',
  ),
  _WindingSpec(
    id: 'hvMain',
    label: 'HV-Main',
    color: _hvOrange,
    voltagePath: 'secondaryVoltage',
    typePath: 'hvWindingType',
    currentDensityPath: 'hvCurrentDensity',
    materialPath: 'hVConductorMaterial',
    lockGroup: 'hvWindings',
  ),
  _WindingSpec(
    id: 'corse',
    label: 'Corse',
    color: _corseAccent,
    voltagePath: 'corseVoltage',
    typePath: 'corseWindingType',
    currentDensityPath: 'corseCurrentDensity',
    materialPath: 'corseConductorMaterial',
    lockGroup: 'corseWindings',
  ),
  _WindingSpec(
    id: 'fine',
    label: 'Fine',
    color: _fineAccent,
    voltagePath: 'fineVoltage',
    typePath: 'fineWindingType',
    currentDensityPath: 'fineCurrentDensity',
    materialPath: 'fineConductorMaterial',
    lockGroup: 'fineWindings',
  ),
  _WindingSpec(
    id: 'outer',
    label: 'Outer',
    color: _outerAccent,
    voltagePath: 'outerVoltage',
    typePath: 'outerWindingType',
    currentDensityPath: 'outerCurrentDensity',
    materialPath: 'outerConductorMaterial',
    lockGroup: 'outerWindings',
  ),
];

List<_WindingSpec> _activeWindingSpecs(MultiWindingController controller) {
  final active = controller.activeWindings.toSet();
  return _windingSpecs.where((winding) => active.contains(winding.id)).toList();
}

const _dimensionRows = <(String, String)>[
  ('ID', 'id'),
  ('Radial x 2', 'radial'),
  ('OD', 'od'),
];

List<(String, String)> _gapFields(List<_WindingSpec> windings) {
  final fields = <(String, String)>[('Core-LV Clr', 'coilDimensions.coreGap')];
  for (var index = 1; index < windings.length; index++) {
    final left = windings[index - 1];
    final right = windings[index];
    final path = switch ((left.id, right.id)) {
      ('lv', 'hvMain') => 'coilDimensions.lvhvgap',
      ('hvMain', 'outer') => 'coilDimensions.hvhvgap',
      ('hvMain', 'corse') => 'multiCoilDimensions.gaps.hvMainToCorseGap',
      ('hvMain', 'fine') => 'multiCoilDimensions.gaps.hvMainToFineGap',
      ('corse', 'fine') => 'multiCoilDimensions.gaps.corseToFineGap',
      ('corse', 'outer') => 'multiCoilDimensions.gaps.corseToOuterGap',
      ('fine', 'outer') => 'multiCoilDimensions.gaps.fineToOuterGap',
      (_, _) =>
        'multiCoilDimensions.gaps.${left.id}To${right.id[0].toUpperCase()}${right.id.substring(1)}Gap',
    };
    fields.add(('${left.label}-${right.label} Clr', path));
  }
  return fields;
}

TableRow _headerRow(List<_WindingSpec> windings) => TableRow(
  children: [
    const _TableHeaderCell(label: 'Parameter', alignLeft: true),
    for (final winding in windings)
      _TableHeaderCell(label: winding.label, color: winding.color),
  ],
);

TableRow _matrixRow({
  required String label,
  required List<_WindingSpec> windings,
  required Widget Function(_WindingSpec winding) builder,
  bool highlighted = false,
  bool isLast = false,
}) => TableRow(
  decoration: BoxDecoration(
    border: isLast ? null : const Border(bottom: BorderSide(color: _border)),
  ),
  children: [
    _TableLabelCell(label: label),
    for (final winding in windings)
      _TableInputCell(highlighted: highlighted, child: builder(winding)),
  ],
);

class _TableHeaderCell extends StatelessWidget {
  const _TableHeaderCell({
    required this.label,
    this.color = _text,
    this.alignLeft = false,
  });

  final String label;
  final Color color;
  final bool alignLeft;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 42),
    alignment: alignLeft ? Alignment.centerLeft : Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: const BoxDecoration(
      color: _softSurface,
      border: Border(right: BorderSide(color: _border)),
    ),
    child: Text(
      label,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
    ),
  );
}

class _TableLabelCell extends StatelessWidget {
  const _TableLabelCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: const BoxDecoration(
      color: _softSurface,
      border: Border(right: BorderSide(color: _border)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: _text,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _TableInputCell extends StatelessWidget {
  const _TableInputCell({required this.child, this.highlighted = false});

  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 48),
    alignment: Alignment.center,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: highlighted ? const Color(0x140081FF) : _surface,
      border: const Border(right: BorderSide(color: _border)),
    ),
    child: child,
  );
}

class _MatrixFrame extends StatelessWidget {
  const _MatrixFrame({required this.minWidth, required this.child});

  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: _border)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tableWidth = constraints.maxWidth > minWidth
              ? constraints.maxWidth
              : minWidth;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: tableWidth, child: child),
          );
        },
      ),
    ),
  );
}

class _MatrixField extends StatelessWidget {
  const _MatrixField({
    required this.value,
    required this.path,
    required this.onChanged,
    this.highlighted = false,
    this.locked = false,
    this.onLock,
  });

  final String value;
  final String path;
  final ValueChanged<String> onChanged;
  final bool highlighted;
  final bool locked;
  final VoidCallback? onLock;

  @override
  Widget build(BuildContext context) => _SyncedTextField(
    value: value,
    path: path,
    onChanged: onChanged,
    readOnly: locked,
    fillColor: highlighted ? _accentInputFill : _inputFill,
    suffixIcon: onLock == null
        ? null
        : IconButton(
            tooltip: locked ? 'Unlock value' : 'Lock value',
            onPressed: onLock,
            icon: Icon(locked ? Icons.lock : Icons.lock_open, size: 16),
          ),
  );
}

class _MatrixChoiceField extends StatelessWidget {
  const _MatrixChoiceField({
    required this.value,
    required this.values,
    required this.path,
    required this.onChanged,
  });

  final String value;
  final List<String> values;
  final String path;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = values.contains(value) ? value : values.first;
    return DropdownButtonFormField<String>(
      key: ValueKey('$path:$selected'),
      initialValue: selected,
      isExpanded: true,
      style: const TextStyle(color: _text, fontSize: 12),
      decoration: _inputDecoration(fillColor: _inputFill),
      icon: const Icon(Icons.arrow_drop_down, size: 18),
      items: [
        for (final option in values)
          DropdownMenuItem(
            value: option,
            child: Text(option, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (selectedValue) {
        if (selectedValue != null) onChanged(selectedValue);
      },
    );
  }
}

class _DensityMaterialCell extends StatelessWidget {
  const _DensityMaterialCell({
    required this.density,
    required this.material,
    required this.densityPath,
    required this.materialPath,
    required this.controller,
  });

  final String density;
  final String material;
  final String densityPath;
  final String materialPath;
  final MultiWindingController controller;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _SyncedTextField(
        value: density,
        path: densityPath,
        onChanged: (value) => controller.update(densityPath, value),
      ),
      const SizedBox(height: 4),
      SizedBox(
        height: 28,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Cu', label: Text('Cu')),
            ButtonSegment(value: 'Al', label: Text('Al')),
          ],
          selected: {material == 'Al' ? 'Al' : 'Cu'},
          showSelectedIcon: false,
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            textStyle: const WidgetStatePropertyAll(
              TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
            visualDensity: VisualDensity.compact,
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
          onSelectionChanged: (selection) =>
              controller.update(materialPath, selection.first),
        ),
      ),
    ],
  );
}

class _ConductorSizeCell extends StatelessWidget {
  const _ConductorSizeCell({required this.controller, required this.winding});

  final MultiWindingController controller;
  final _WindingSpec winding;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    final base = 'part2Windings.${winding.id}';
    final isRound = design.readPath('$base.isConductorRound') == true;
    final diameter = design.textAt('$base.conductorDiameter');
    final breadth = design.textAt('$base.condBreadth');
    final height = design.textAt('$base.condHeight');
    final display = isRound
        ? (diameter.isEmpty ? '-' : 'Round $diameter')
        : (breadth.isEmpty && height.isEmpty ? '-' : '$breadth x $height');
    final locked =
        design.readPath(
          'lockedAttributes.${winding.lockGroup}.conductorSizes',
        ) ==
        true;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: locked ? null : () => _showConductorDialog(context),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: Text(display, overflow: TextOverflow.ellipsis),
            style: _matrixDialogButtonStyle(),
          ),
        ),
        IconButton(
          tooltip: locked ? 'Unlock conductor size' : 'Lock conductor size',
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              controller.toggleWindingLock(winding.id, 'conductorSizes'),
          icon: Icon(locked ? Icons.lock : Icons.lock_open, size: 16),
        ),
      ],
    );
  }

  Future<void> _showConductorDialog(BuildContext context) async {
    final design = controller.state.design;
    final base = 'part2Windings.${winding.id}';
    var isRound = design.readPath('$base.isConductorRound') == true;
    final breadth = TextEditingController(
      text: design.textAt('$base.condBreadth'),
    );
    final height = TextEditingController(
      text: design.textAt('$base.condHeight'),
    );
    final diameter = TextEditingController(
      text: design.textAt('$base.conductorDiameter'),
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${winding.label} Conductor Size'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Strip')),
                    ButtonSegment(value: true, label: Text('Round')),
                  ],
                  selected: {isRound},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) =>
                      setDialogState(() => isRound = selection.first),
                ),
                const SizedBox(height: 14),
                if (isRound)
                  TextField(
                    controller: diameter,
                    decoration: const InputDecoration(labelText: 'Diameter'),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: breadth,
                          decoration: const InputDecoration(
                            labelText: 'Breadth',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: height,
                          decoration: const InputDecoration(
                            labelText: 'Height',
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    final breadthValue = breadth.text;
    final heightValue = height.text;
    final diameterValue = diameter.text;
    breadth.dispose();
    height.dispose();
    diameter.dispose();
    if (accepted != true) return;
    controller.update('$base.isConductorRound', isRound);
    controller.update('$base.condBreadth', breadthValue);
    controller.update('$base.condHeight', heightValue);
    controller.update('$base.conductorDiameter', diameterValue);
  }
}

class _ParallelCell extends StatelessWidget {
  const _ParallelCell({required this.controller, required this.winding});

  final MultiWindingController controller;
  final _WindingSpec winding;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    final base = 'part2Windings.${winding.id}';
    final radial = design.textAt('$base.radialParallelCond');
    final axial = design.textAt('$base.axialParallelCond');
    final radialNumber = double.tryParse(radial);
    final axialNumber = double.tryParse(axial);
    final total = radialNumber == null || axialNumber == null
        ? ''
        : _formatNumber(radialNumber * axialNumber);
    final display = radial.isEmpty && axial.isEmpty
        ? '-'
        : 'R$radial x A$axial${total.isEmpty ? '' : ' = $total'}';
    final locked =
        design.readPath('lockedAttributes.${winding.lockGroup}.noInParallel') ==
        true;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: locked
                ? null
                : () => _showPairDialog(
                    context,
                    title: '${winding.label} Parallel Conductors',
                    firstLabel: 'No. in Radial',
                    secondLabel: 'No. in Axial',
                    firstValue: radial,
                    secondValue: axial,
                    onApply: (first, second) {
                      controller.update('$base.radialParallelCond', first);
                      controller.update('$base.axialParallelCond', second);
                    },
                  ),
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: Text(display, overflow: TextOverflow.ellipsis),
            style: _matrixDialogButtonStyle(),
          ),
        ),
        IconButton(
          tooltip: locked ? 'Unlock parallel count' : 'Lock parallel count',
          visualDensity: VisualDensity.compact,
          onPressed: () =>
              controller.toggleWindingLock(winding.id, 'noInParallel'),
          icon: Icon(locked ? Icons.lock : Icons.lock_open, size: 16),
        ),
      ],
    );
  }
}

class _DuctCell extends StatelessWidget {
  const _DuctCell({required this.controller, required this.winding});

  final MultiWindingController controller;
  final _WindingSpec winding;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    final base = 'part2Windings.${winding.id}';
    final ducts = design.textAt('$base.ducts');
    final size = design.textAt('$base.ductSize');
    final display = ducts.isEmpty && size.isEmpty ? '-' : '$ducts / $size';
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _showPairDialog(
          context,
          title: '${winding.label} Ducts',
          firstLabel: 'No. of Ducts',
          secondLabel: 'Duct Width',
          firstValue: ducts,
          secondValue: size,
          onApply: (first, second) {
            controller.update('$base.ducts', first);
            controller.update('$base.ductSize', second);
          },
        ),
        icon: const Icon(Icons.edit_outlined, size: 14),
        label: Text(display, overflow: TextOverflow.ellipsis),
        style: _matrixDialogButtonStyle(),
      ),
    );
  }
}

class _InsulationCell extends StatelessWidget {
  const _InsulationCell({required this.controller, required this.winding});

  final MultiWindingController controller;
  final _WindingSpec winding;

  @override
  Widget build(BuildContext context) {
    final design = controller.state.design;
    final base = 'part2Windings.${winding.id}';
    final isEnamel = design.readPath('$base.isEnamel') == true;
    return Row(
      children: [
        Expanded(
          child: _MatrixField(
            value: design.textAt('$base.condInsulation'),
            path: '$base.condInsulation',
            highlighted: true,
            onChanged: (value) =>
                controller.update('$base.condInsulation', value),
          ),
        ),
        Tooltip(
          message: 'Enamel conductor',
          child: Checkbox(
            value: isEnamel,
            visualDensity: VisualDensity.compact,
            onChanged: (value) =>
                controller.update('$base.isEnamel', value == true),
          ),
        ),
      ],
    );
  }
}

Future<void> _showPairDialog(
  BuildContext context, {
  required String title,
  required String firstLabel,
  required String secondLabel,
  required String firstValue,
  required String secondValue,
  required void Function(String first, String second) onApply,
}) async {
  final first = TextEditingController(text: firstValue);
  final second = TextEditingController(text: secondValue);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: first,
                decoration: InputDecoration(labelText: firstLabel),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: second,
                decoration: InputDecoration(labelText: secondLabel),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Apply'),
        ),
      ],
    ),
  );
  final firstResult = first.text;
  final secondResult = second.text;
  first.dispose();
  second.dispose();
  if (accepted == true) onApply(firstResult, secondResult);
}

ButtonStyle _matrixDialogButtonStyle() => OutlinedButton.styleFrom(
  minimumSize: const Size.fromHeight(36),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  foregroundColor: _text,
  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
  side: const BorderSide(color: _strongBorder),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
);

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    required this.path,
    required this.onChanged,
    this.width = 158,
    this.fluid = false,
    this.highlighted = false,
    this.locked = false,
    this.onLock,
  });

  final String label;
  final String value;
  final String path;
  final ValueChanged<String> onChanged;
  final double width;
  final bool fluid;
  final bool highlighted;
  final bool locked;
  final VoidCallback? onLock;

  @override
  Widget build(BuildContext context) {
    final field = _SyncedTextField(
      value: value,
      path: path,
      label: label,
      onChanged: onChanged,
      readOnly: locked,
      fillColor: highlighted ? _accentInputFill : _inputFill,
      suffixIcon: onLock == null
          ? null
          : IconButton(
              tooltip: locked ? 'Unlock value' : 'Lock value',
              onPressed: onLock,
              icon: Icon(locked ? Icons.lock : Icons.lock_open, size: 16),
            ),
    );
    return SizedBox(width: fluid ? double.infinity : width, child: field);
  }
}

class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.value,
    required this.values,
    required this.path,
    required this.onChanged,
    this.displayValues,
    this.width = 158,
    this.fluid = false,
  });

  final String label;
  final String value;
  final List<String> values;
  final Map<String, String>? displayValues;
  final String path;
  final ValueChanged<String> onChanged;
  final double width;
  final bool fluid;

  @override
  Widget build(BuildContext context) {
    final selected = values.contains(value) ? value : values.first;
    return SizedBox(
      width: fluid ? double.infinity : width,
      child: DropdownButtonFormField<String>(
        key: ValueKey('$path:$selected'),
        initialValue: selected,
        isExpanded: true,
        style: const TextStyle(color: _text, fontSize: 12),
        decoration: _inputDecoration(labelText: label),
        items: [
          for (final option in values)
            DropdownMenuItem(
              value: option,
              child: Text(
                displayValues?[option] ?? option,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (selectedValue) {
          if (selectedValue != null) onChanged(selectedValue);
        },
      ),
    );
  }
}

class _SyncedTextField extends StatefulWidget {
  const _SyncedTextField({
    required this.value,
    required this.path,
    required this.onChanged,
    this.label,
    this.readOnly = false,
    this.fillColor = _inputFill,
    this.suffixIcon,
  });

  final String value;
  final String path;
  final String? label;
  final ValueChanged<String> onChanged;
  final bool readOnly;
  final Color fillColor;
  final Widget? suffixIcon;

  @override
  State<_SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<_SyncedTextField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _controller.text) return;
    _controller.value = TextEditingValue(
      text: widget.value,
      selection: TextSelection.collapsed(offset: widget.value.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    key: ValueKey(widget.path),
    controller: _controller,
    readOnly: widget.readOnly,
    onChanged: widget.onChanged,
    style: const TextStyle(color: _text, fontSize: 12, height: 1.15),
    decoration: _inputDecoration(
      labelText: widget.label,
      fillColor: widget.fillColor,
      suffixIcon: widget.suffixIcon,
    ),
  );
}

InputDecoration _inputDecoration({
  String? labelText,
  Color fillColor = _inputFill,
  Widget? suffixIcon,
}) => InputDecoration(
  labelText: labelText,
  labelStyle: const TextStyle(color: _mutedText, fontSize: 11),
  filled: true,
  fillColor: fillColor,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  suffixIcon: suffixIcon,
  suffixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 34),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(7),
    borderSide: const BorderSide(color: _strongBorder),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(7),
    borderSide: const BorderSide(color: _blue, width: 1.5),
  ),
  disabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(7),
    borderSide: const BorderSide(color: _border),
  ),
);

class _FieldWrap extends StatelessWidget {
  const _FieldWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 10, runSpacing: 8, children: children);
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children, required this.minCellWidth});

  final List<Widget> children;
  final double minCellWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 8.0;
      final count = (constraints.maxWidth / minCellWidth).floor().clamp(1, 3);
      final width = (constraints.maxWidth - (gap * (count - 1))) / count;
      return Wrap(
        spacing: gap,
        runSpacing: 7,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    required this.padding,
    this.shadow = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
      boxShadow: shadow
          ? const [
              BoxShadow(
                color: Color(0x120F172A),
                offset: Offset(0, 8),
                blurRadius: 22,
              ),
            ]
          : null,
    ),
    child: child,
  );
}

class _InsetPanel extends StatelessWidget {
  const _InsetPanel({
    required this.title,
    required this.child,
    this.surface = false,
  });

  final String title;
  final Widget child;
  final bool surface;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _softSurface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
      boxShadow: surface
          ? const [
              BoxShadow(
                color: Color(0x0D0F172A),
                offset: Offset(0, 4),
                blurRadius: 14,
              ),
            ]
          : null,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_SectionHeading(title), const SizedBox(height: 10), child],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: _text,
      fontSize: 15,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _MetricBar extends StatelessWidget {
  const _MetricBar({required this.values});

  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _softSurface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        for (var index = 0; index < values.length; index++) ...[
          if (index > 0)
            const SizedBox(
              height: 30,
              child: VerticalDivider(color: _border, width: 18),
            ),
          Expanded(
            child: _Metric(label: values[index].$1, value: values[index].$2),
          ),
        ],
      ],
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.values});

  final List<(String, String)> values;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 8.0;
      final count = (constraints.maxWidth / 160).floor().clamp(1, 6);
      final width = (constraints.maxWidth - gap * (count - 1)) / count;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final value in values)
            Container(
              width: width,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _softSurface,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: _Metric(label: value.$1, value: value.$2),
            ),
        ],
      );
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _mutedText,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value.isEmpty ? '-' : value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _text,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _DetailSummary extends StatelessWidget {
  const _DetailSummary({required this.entries, this.horizontal = false});

  final List<(String, String)> entries;
  final bool horizontal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: _surface,
      border: Border.all(color: _border),
      borderRadius: BorderRadius.circular(7),
    ),
    child: horizontal
        ? Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              for (final entry in entries) _SummaryEntry(entry: entry),
            ],
          )
        : Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                if (index > 0) const Divider(color: _border, height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entries[index].$1,
                        style: const TextStyle(
                          color: _mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        entries[index].$2.isEmpty ? '-' : entries[index].$2,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
  );
}

class _SummaryEntry extends StatelessWidget {
  const _SummaryEntry({required this.entry});

  final (String, String) entry;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        entry.$1,
        style: const TextStyle(
          color: _mutedText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        entry.$2.isEmpty ? '-' : entry.$2,
        style: const TextStyle(
          color: _text,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

String _firstText(dynamic design, List<String> paths) {
  for (final path in paths) {
    final value = design.textAt(path) as String;
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _formatNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

const _windingConfigurations = <String, String>{
  '2_WDG_LV_HV_MAIN': '2 Wdg (LV and HV-Main)',
  '3_WDG_LV_HV_MAIN_OUTER': '3 Wdg (LV, HV-Main and Outer)',
  '4_WDG_LV_HV_MAIN_CORSE_OUTER': '4 Wdg (LV, HV-Main, Corse and Outer)',
  '4_WDG_LV_HV_MAIN_FINE_OUTER': '4 Wdg (LV, HV-Main, Fine and Outer)',
  '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER':
      '5 Wdg (LV, HV-Main, Corse, Fine and Outer)',
};

const _lvWindingTypes = ['HELICAL', 'DISC', 'FOIL', 'LAYERDISC'];
const _hvWindingTypes = ['HELICAL', 'DISC', 'XOVER'];

const _coreMaterials = <String>[
  'NipZD',
  'NipMOH',
  'NipM3',
  'NipM4',
  'NipM5',
  'NipM6',
  'CRNO',
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
  'Pos23PHD080',
  'Pos23PHD085',
  'Pos23PH090',
  'Pos23PH095',
  'Pos23PH100',
  'Pos27PHD090',
  'Pos27PH095',
  'Pos27PH100',
  'Pos27PG130',
  'Pos30PG120',
  'Pos30PG130',
  'Pos30PG140',
  'Pos30PH105',
  'CRGO',
];
