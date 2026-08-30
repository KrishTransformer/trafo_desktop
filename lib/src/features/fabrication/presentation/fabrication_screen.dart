import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_scope.dart';
import '../../../core/presentation/app_error_dialog.dart';
import '../../../core/presentation/loading_overlay.dart';
import '../../home/domain/models/design_summary.dart';
import '../application/fabrication_controller.dart';
import '../application/fabrication_state.dart';
import 'glb_model_viewer.dart';
import '../data/repositories/http_drawings_status_repository.dart';
import '../data/repositories/http_fabrication_cad_repository.dart';
import '../data/repositories/http_fabrication_calculation_repository.dart';
import '../data/repositories/http_fabrication_design_repository.dart';

class FabricationScreen extends StatefulWidget {
  const FabricationScreen({
    required this.routeDesignId,
    this.initialDesignSummary,
    this.controller,
    super.key,
  });

  final String routeDesignId;
  final DesignSummary? initialDesignSummary;
  final FabricationController? controller;

  @override
  State<FabricationScreen> createState() => _FabricationScreenState();
}

class _FabricationScreenState extends State<FabricationScreen> {
  FabricationController? _controller;
  bool _ownsController = false;
  String _lastErrorMessage = '';
  int _activeDetailTab = 0;
  int _activeAccessoriesTab = 0;

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
    _controller?.closeStatusDrawer();
    _controller?.removeListener(_handleControllerChange);
    if (_ownsController) {
      _controller?.dispose();
    }
    super.dispose();
  }

  FabricationController _buildControllerFromScope(BuildContext context) {
    final dependencies = AppScope.of(context);
    return FabricationController(
      routeId: widget.routeDesignId,
      calculationRepository: HttpFabricationCalculationRepository(
        dependencies.apiClient,
      ),
      designRepository: HttpFabricationDesignRepository(dependencies.apiClient),
      cadRepository: HttpFabricationCadRepository(dependencies.apiClient),
      drawingsStatusRepository: HttpDrawingsStatusRepository(
        dependencies.apiClient,
      ),
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
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: state.hasDesignContext
                        ? _WorkspaceView(
                            controller: controller,
                            state: state,
                            activeDetailTab: _activeDetailTab,
                            activeAccessoriesTab: _activeAccessoriesTab,
                            onDetailTabChanged: (value) {
                              setState(() {
                                _activeDetailTab = value;
                              });
                            },
                            onAccessoriesTabChanged: (value) {
                              setState(() {
                                _activeAccessoriesTab = value;
                              });
                            },
                          )
                        : _FabricationEmptyState(routeId: widget.routeDesignId),
                  ),
                  _StatusDrawer(
                    state: state,
                    onClose: controller.closeStatusDrawer,
                    onRefresh: () => controller.refreshStatuses(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WorkspaceView extends StatelessWidget {
  const _WorkspaceView({
    required this.controller,
    required this.state,
    required this.activeDetailTab,
    required this.activeAccessoriesTab,
    required this.onDetailTabChanged,
    required this.onAccessoriesTabChanged,
  });

  final FabricationController controller;
  final FabricationState state;
  final int activeDetailTab;
  final int activeAccessoriesTab;
  final ValueChanged<int> onDetailTabChanged;
  final ValueChanged<int> onAccessoriesTabChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WorkspaceHeader(controller: controller, state: state),
        const SizedBox(height: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1180;
              final firstColumn = Column(
                children: [
                  _ReferencePanel(state: state),
                  const SizedBox(height: 16),
                  _TankPanel(controller: controller, state: state),
                  const SizedBox(height: 16),
                  _RadiatorPanel(controller: controller, state: state),
                ],
              );
              final secondColumn = Column(
                children: [
                  _LidConservatorPanel(controller: controller, state: state),
                  const SizedBox(height: 16),
                  _DetailTabsPanel(
                    controller: controller,
                    state: state,
                    activeTab: activeDetailTab,
                    onTabChanged: onDetailTabChanged,
                  ),
                ],
              );
              final thirdColumn = Column(
                children: [
                  _AccessoriesPanel(
                    controller: controller,
                    state: state,
                    activeTab: activeAccessoriesTab,
                    onTabChanged: onAccessoriesTabChanged,
                  ),
                  const SizedBox(height: 16),
                  _PreviewPanel(controller: controller, state: state),
                  const SizedBox(height: 16),
                  _ActionPanel(controller: controller, state: state),
                ],
              );
              final content = stacked
                  ? Column(
                      children: [
                        firstColumn,
                        const SizedBox(height: 16),
                        secondColumn,
                        const SizedBox(height: 16),
                        thirdColumn,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 380, child: firstColumn),
                        const SizedBox(width: 20),
                        SizedBox(width: 390, child: secondColumn),
                        const SizedBox(width: 20),
                        SizedBox(width: 470, child: thirdColumn),
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
                            constraints: const BoxConstraints(minWidth: 1360),
                            child: content,
                          ),
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
  const _WorkspaceHeader({required this.controller, required this.state});

  final FabricationController controller;
  final FabricationState state;

  @override
  Widget build(BuildContext context) {
    final statusLabel = state.latestStatus?.status ?? 'Idle';
    final statusColor = switch (statusLabel.toLowerCase()) {
      'success' => const Color(0xFF0A7D2B),
      'failed' => const Color(0xFFB3261E),
      _ => const Color(0xFF946300),
    };

    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.end,
        children: [
          _Pill(
            icon: Icons.timeline_outlined,
            label: '${state.drawingsStatuses.length} status entries',
          ),
          _Pill(
            icon: Icons.sync_outlined,
            label: statusLabel,
            foregroundColor: statusColor,
          ),
          const _Pill(
            icon: Icons.keyboard_command_key_outlined,
            label: 'Ctrl/Cmd + Enter',
          ),
        ],
      ),
    );
  }
}

class _ReferencePanel extends StatelessWidget {
  const _ReferencePanel({required this.state});

  final FabricationState state;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Design Reference',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryChip(
                label: 'kVA',
                value: state.formData.stringAt('restOfVariables.kVA'),
              ),
              _SummaryChip(
                label: 'LV Line',
                value: state.formData.stringAt('lvb.lvb_Volt'),
              ),
              _SummaryChip(
                label: 'HV Line',
                value: state.formData.stringAt('hvb.hvb_Volt'),
              ),
              _SummaryChip(
                label: 'Vector',
                value: state.twoWindingDesign?.stringAt('vectorGroup') ?? '',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Core Details',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _MetricRow(
            label: 'Core Dia',
            value: state.formData.stringAt('fabricationCore.core_Dia'),
          ),
          _MetricRow(
            label: 'Limb Ht.',
            value: state.formData.stringAt('restOfVariables.limb_H'),
          ),
          _MetricRow(
            label: 'Cen. Dist',
            value: state.formData.stringAt('restOfVariables.limb_CC'),
          ),
          _MetricRow(
            label: 'Limb Nos',
            value: state.formData.stringAt('restOfVariables.limb_Nos'),
          ),
        ],
      ),
    );
  }
}

class _TankPanel extends StatelessWidget {
  const _TankPanel({required this.controller, required this.state});

  final FabricationController controller;
  final FabricationState state;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Tank Details',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _textField(
            label: 'Length',
            value: state.formData.stringAt('tank.tank_L'),
            onChanged: (value) => controller.updateField('tank.tank_L', value),
          ),
          _textField(
            label: 'Width',
            value: state.formData.stringAt('tank.tank_W'),
            onChanged: (value) => controller.updateField('tank.tank_W', value),
          ),
          _textField(
            label: 'Height',
            value: state.formData.stringAt('tank.tank_H'),
            onChanged: (value) => controller.updateField('tank.tank_H', value),
          ),
          _textField(
            label: 'Sheet Thick',
            value: state.formData.stringAt('tank.tank_Thick'),
            onChanged: (value) =>
                controller.updateField('tank.tank_Thick', value),
          ),
          _textField(
            label: 'Bot. Sheet Thk',
            value: state.formData.stringAt('tank.tank_Bot_Thick'),
            onChanged: (value) =>
                controller.updateField('tank.tank_Bot_Thick', value),
          ),
          _textField(
            label: 'Curb Thick',
            value: state.formData.stringAt('tank.tank_Flg_Thick'),
            onChanged: (value) =>
                controller.updateField('tank.tank_Flg_Thick', value),
          ),
          _dropdownField(
            context,
            label: 'Build Type',
            value: state.formData.stringAt(
              'tank.tank_Build_Type',
              fallback: 'single',
            ),
            items: const ['single', 'l-joint'],
            onChanged: (value) =>
                controller.updateField('tank.tank_Build_Type', value),
          ),
        ],
      ),
    );
  }
}

class _RadiatorPanel extends StatelessWidget {
  const _RadiatorPanel({required this.controller, required this.state});

  final FabricationController controller;
  final FabricationState state;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Radiator Details',
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _dropdownField(
                context,
                label: 'Rad. Type',
                value: state.formData.stringAt(
                  'radiator.radiator_Type',
                  fallback: 'psr',
                ),
                items: const ['psr', 'psr-offset'],
                onChanged: (value) =>
                    controller.updateField('radiator.radiator_Type', value),
              ),
              _textField(
                label: 'Rad. Hgt.',
                value: state.formData.stringAt('radiator.radiator_CC'),
                onChanged: (value) =>
                    controller.updateField('radiator.radiator_CC', value),
              ),
              _textField(
                label: 'Rad. Width',
                value: state.formData.stringAt('radiator.radiator_W'),
                onChanged: (value) =>
                    controller.updateField('radiator.radiator_W', value),
              ),
              _textField(
                label: 'No. of Fins',
                value: state.formData.stringAt('radiator.radiator_Fin_Nos'),
                onChanged: (value) =>
                    controller.updateField('radiator.radiator_Fin_Nos', value),
              ),
              _textField(
                label: 'Total Radiators',
                value: state.formData.stringAt('radiator.radiator_Nos'),
                onChanged: (value) =>
                    controller.updateField('radiator.radiator_Nos', value),
              ),
              _textField(
                label: 'Left Side',
                value: state.formData.stringAt('radiator.radiator_Left_Nos'),
                onChanged: (value) =>
                    controller.updateField('radiator.radiator_Left_Nos', value),
              ),
              _textField(
                label: 'Right Side',
                value: state.formData.stringAt('radiator.radiator_Right_Nos'),
                onChanged: (value) => controller.updateField(
                  'radiator.radiator_Right_Nos',
                  value,
                ),
              ),
              _textField(
                label: 'Rad. Min. Gap',
                value: state.formData.stringAt('radiator.radiator_Min_Gap'),
                onChanged: (value) =>
                    controller.updateField('radiator.radiator_Min_Gap', value),
              ),
              _textField(
                label: 'Fin Thickness',
                value: state.formData.stringAt('radiator.radiator_Fin_Thick'),
                onChanged: (value) => controller.updateField(
                  'radiator.radiator_Fin_Thick',
                  value,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LidConservatorPanel extends StatelessWidget {
  const _LidConservatorPanel({required this.controller, required this.state});

  final FabricationController controller;
  final FabricationState state;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Lid and Conservator Details',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _textField(
            label: 'Lid Cover Thickness',
            value: state.formData.stringAt('lid.lid_Thick'),
            onChanged: (value) =>
                controller.updateField('lid.lid_Thick', value),
          ),
          _textField(
            label: 'Bolt Hole Diameter',
            value: state.formData.stringAt('lid.lid_Bolt_Hole_Dia'),
            onChanged: (value) =>
                controller.updateField('lid.lid_Bolt_Hole_Dia', value),
          ),
          _textField(
            label: 'Lid Slope',
            value: state.formData.stringAt('lid.lid_Slope_Ang'),
            onChanged: (value) =>
                controller.updateField('lid.lid_Slope_Ang', value),
          ),
          _textField(
            label: 'Volume',
            value: state.formData.stringAt('cons.cons_Vol'),
            onChanged: (value) =>
                controller.updateField('cons.cons_Vol', value),
          ),
          _textField(
            label: 'Diameter',
            value: state.formData.stringAt('cons.cons_Dia'),
            onChanged: (value) =>
                controller.updateField('cons.cons_Dia', value),
          ),
          _textField(
            label: 'Length',
            value: state.formData.stringAt('cons.cons_L'),
            onChanged: (value) => controller.updateField('cons.cons_L', value),
          ),
          _textField(
            label: 'Sheet Thickness',
            value: state.formData.stringAt('cons.cons_Thick'),
            onChanged: (value) =>
                controller.updateField('cons.cons_Thick', value),
          ),
          _dropdownField(
            context,
            label: 'Mounting Position',
            value: state.formData.stringAt('cons.cons_Pos', fallback: 'left'),
            items: const ['left', 'lv side'],
            onChanged: (value) =>
                controller.updateField('cons.cons_Pos', value),
          ),
          _dropdownField(
            context,
            label: 'Mounting Type',
            value: state.formData.stringAt(
              'cons.cons_Mounting',
              fallback: 'lid mounted',
            ),
            items: const ['lid mounted'],
            onChanged: (value) =>
                controller.updateField('cons.cons_Mounting', value),
          ),
        ],
      ),
    );
  }
}

class _DetailTabsPanel extends StatelessWidget {
  const _DetailTabsPanel({
    required this.controller,
    required this.state,
    required this.activeTab,
    required this.onTabChanged,
  });

  final FabricationController controller;
  final FabricationState state;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = const ['Active Part', 'Tank'];

    return _SectionPanel(
      title: 'Additional Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabStrip(
            tabs: tabs,
            activeIndex: activeTab,
            onChanged: onTabChanged,
          ),
          const SizedBox(height: 16),
          if (activeTab == 0)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _dropdownField(
                  context,
                  label: 'Frame Type',
                  value: state.formData.stringAt(
                    'fabricationCore.core_Fixture_Type',
                    fallback: 'c-channel',
                  ),
                  items: const ['c-channel'],
                  onChanged: (value) => controller.updateField(
                    'fabricationCore.core_Fixture_Type',
                    value,
                  ),
                ),
                _textField(
                  label: 'Height',
                  value: state.formData.stringAt(
                    'restOfVariables.active_Height',
                  ),
                  onChanged: (value) => controller.updateField(
                    'restOfVariables.active_Height',
                    value,
                  ),
                ),
                _textField(
                  label: 'Width',
                  value: state.formData.stringAt(
                    'restOfVariables.activePart_L',
                  ),
                  onChanged: (value) => controller.updateField(
                    'restOfVariables.activePart_L',
                    value,
                  ),
                ),
                _textField(
                  label: 'Tie Rod Diameter',
                  value: state.formData.stringAt('restOfVariables.tieRod_Dia'),
                  onChanged: (value) => controller.updateField(
                    'restOfVariables.tieRod_Dia',
                    value,
                  ),
                ),
                _switchTile(
                  title: 'Yoke Hole in Core',
                  value: state.formData.boolAt('restOfVariables.yoke_Holes'),
                  onChanged: (value) => controller.updateField(
                    'restOfVariables.yoke_Holes',
                    value,
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _dropdownField(
                  context,
                  label: 'Foundation Type',
                  value: state.formData.boolAt('bot_Chnl.isRoller')
                      ? 'with roller'
                      : 'without roller',
                  items: const ['without roller', 'with roller'],
                  onChanged: (value) => controller.updateField(
                    'bot_Chnl.isRoller',
                    value == 'with roller',
                  ),
                ),
                _dropdownField(
                  context,
                  label: 'Roller Type',
                  value: state.formData.stringAt(
                    'roller.roller_Type',
                    fallback: 'plain_roller',
                  ),
                  items: const ['plain_roller', 'flanged_roller'],
                  onChanged: (value) =>
                      controller.updateField('roller.roller_Type', value),
                ),
                _dropdownField(
                  context,
                  label: 'Bottom Channel Data',
                  value: state.formData.stringAt(
                    'fabricationCore.core_Fixture_Type',
                    fallback: 'c-channel',
                  ),
                  items: const ['c-channel'],
                  onChanged: (value) => controller.updateField(
                    'fabricationCore.core_Fixture_Type',
                    value,
                  ),
                ),
                _dropdownField(
                  context,
                  label: 'Dimensions',
                  value: state.formData.stringAt(
                    'bot_Chnl.bot_Chnl_Sec_Data',
                    fallback: '75x45x5.3-C',
                  ),
                  items: const [
                    '75x45x5.3-C',
                    '125x65x5.3-C',
                    '150x75x5.7-C',
                    '200x75x6.2-C',
                    '250x80x8.8-C',
                  ],
                  onChanged: (value) => controller.updateField(
                    'bot_Chnl.bot_Chnl_Sec_Data',
                    value,
                  ),
                ),
                _textField(
                  label: 'Roller Diameter',
                  value: state.formData.stringAt(
                    'bot_Chnl.bot_Chnl_Roller_Dia',
                  ),
                  onChanged: (value) => controller.updateField(
                    'bot_Chnl.bot_Chnl_Roller_Dia',
                    value,
                  ),
                ),
                _textField(
                  label: 'Roller Gauge',
                  value: state.formData.stringAt('roller.roller_Guage'),
                  onChanged: (value) =>
                      controller.updateField('roller.roller_Guage', value),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _AccessoriesPanel extends StatelessWidget {
  const _AccessoriesPanel({
    required this.controller,
    required this.state,
    required this.activeTab,
    required this.onTabChanged,
  });

  final FabricationController controller;
  final FabricationState state;
  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      'Accessories (1)',
      'Accessories (2)',
      'Terminals',
      'Stiffeners',
      'Misc',
    ];

    return _SectionPanel(
      title: 'Accessories / Fittings',
      child: Column(
        children: [
          _TabStrip(
            tabs: tabs,
            activeIndex: activeTab,
            onChanged: onTabChanged,
          ),
          const SizedBox(height: 16),
          switch (activeTab) {
            0 => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _switchTile(
                  title: 'Fill Valve',
                  value: state.formData.boolAt('fill_Vlv.fill_Vlv'),
                  onChanged: (value) =>
                      controller.updateField('fill_Vlv.fill_Vlv', value),
                ),
                _switchTile(
                  title: 'Drain Valve',
                  value: state.formData.boolAt('drain_Vlv.drain_Vlv'),
                  onChanged: (value) =>
                      controller.updateField('drain_Vlv.drain_Vlv', value),
                ),
                _switchTile(
                  title: 'Sample Valve',
                  value: state.formData.boolAt('smpl_Vlv.smpl_Vlv'),
                  onChanged: (value) =>
                      controller.updateField('smpl_Vlv.smpl_Vlv', value),
                ),
                _textField(
                  label: 'Fill Valve Nos',
                  value: state.formData.stringAt('fill_Vlv.fill_Vlv_Nos'),
                  onChanged: (value) =>
                      controller.updateField('fill_Vlv.fill_Vlv_Nos', value),
                ),
                _textField(
                  label: 'Drain Valve Nos',
                  value: state.formData.stringAt('drain_Vlv.drain_Vlv_Nos'),
                  onChanged: (value) =>
                      controller.updateField('drain_Vlv.drain_Vlv_Nos', value),
                ),
                _textField(
                  label: 'Sample Valve Nos',
                  value: state.formData.stringAt('smpl_Vlv.smpl_Vlv_Nos'),
                  onChanged: (value) =>
                      controller.updateField('smpl_Vlv.smpl_Vlv_Nos', value),
                ),
                _textField(
                  label: 'Radiator Valve',
                  value: state.formData.stringAt('radiator.radiator_Vlv'),
                  onChanged: (value) =>
                      controller.updateField('radiator.radiator_Vlv', value),
                ),
              ],
            ),
            1 => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _switchTile(
                  title: 'MOG',
                  value: state.formData.boolAt('mog.mog'),
                  onChanged: (value) =>
                      controller.updateField('mog.mog', value),
                ),
                _switchTile(
                  title: 'Lid Lift Lug',
                  value: state.formData.boolAt('lid_LiftLug.lid_LiftLug'),
                  onChanged: (value) =>
                      controller.updateField('lid_LiftLug.lid_LiftLug', value),
                ),
                _switchTile(
                  title: 'Buchholz Relay',
                  value: state.formData.boolAt('gorPipe.buchholz_Relay'),
                  onChanged: (value) =>
                      controller.updateField('gorPipe.buchholz_Relay', value),
                ),
                _switchTile(
                  title: 'Single Valve',
                  value: state.formData.boolAt('gorPipe.single_Valve'),
                  onChanged: (value) =>
                      controller.updateField('gorPipe.single_Valve', value),
                ),
                _switchTile(
                  title: 'Valve Type 1',
                  value: state.formData.boolAt('gorPipe.valve_Type1'),
                  onChanged: (value) =>
                      controller.updateField('gorPipe.valve_Type1', value),
                ),
                _textField(
                  label: 'MOG Tilt Angle',
                  value: state.formData.stringAt('mog.mog_Tlt_Ang'),
                  onChanged: (value) =>
                      controller.updateField('mog.mog_Tlt_Ang', value),
                ),
                _textField(
                  label: 'Lift Lug Thick',
                  value: state.formData.stringAt(
                    'lid_LiftLug.lid_LiftLug_Thick',
                  ),
                  onChanged: (value) => controller.updateField(
                    'lid_LiftLug.lid_LiftLug_Thick',
                    value,
                  ),
                ),
              ],
            ),
            2 => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _textField(
                  label: 'HV Volt',
                  value: state.formData.stringAt('hvb.hvb_Volt'),
                  onChanged: (value) =>
                      controller.updateField('hvb.hvb_Volt', value),
                ),
                _textField(
                  label: 'HV Amp',
                  value: state.formData.stringAt('hvb.hvb_Amp'),
                  onChanged: (value) =>
                      controller.updateField('hvb.hvb_Amp', value),
                ),
                _textField(
                  label: 'LV Volt',
                  value: state.formData.stringAt('lvb.lvb_Volt'),
                  onChanged: (value) =>
                      controller.updateField('lvb.lvb_Volt', value),
                ),
                _textField(
                  label: 'LV Amp',
                  value: state.formData.stringAt('lvb.lvb_Amp'),
                  onChanged: (value) =>
                      controller.updateField('lvb.lvb_Amp', value),
                ),
                _switchTile(
                  title: 'HV Cable Box',
                  value: state.formData.boolAt('hvcb.hvcb'),
                  onChanged: (value) =>
                      controller.updateField('hvcb.hvcb', value),
                ),
                _switchTile(
                  title: 'LV Cable Box',
                  value: state.formData.boolAt('lvcb.lvcb'),
                  onChanged: (value) =>
                      controller.updateField('lvcb.lvcb', value),
                ),
                _readOnlyField(
                  label: 'HV Position',
                  value: state.formData.stringAt('hvb.hvb_Pos'),
                ),
                _readOnlyField(
                  label: 'LV Position',
                  value: state.formData.stringAt('lvb.lvb_Pos'),
                ),
              ],
            ),
            3 => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _textField(
                  label: 'Horizontal Nos',
                  value: state.formData.stringAt('stiffner.stiffner_Hori_Nos'),
                  onChanged: (value) => controller.updateField(
                    'stiffner.stiffner_Hori_Nos',
                    value,
                  ),
                ),
                _textField(
                  label: 'Horizontal Pitch',
                  value: state.formData.stringAt(
                    'stiffner.stiffner_Hori_Pitch',
                  ),
                  onChanged: (value) => controller.updateField(
                    'stiffner.stiffner_Hori_Pitch',
                    value,
                  ),
                ),
                _textField(
                  label: 'Vertical Nos',
                  value: state.formData.stringAt('stiffner.stiffner_Vert_Nos'),
                  onChanged: (value) => controller.updateField(
                    'stiffner.stiffner_Vert_Nos',
                    value,
                  ),
                ),
                _textField(
                  label: 'Vertical Pitch',
                  value: state.formData.stringAt(
                    'stiffner.stiffner_Vert_Pitch',
                  ),
                  onChanged: (value) => controller.updateField(
                    'stiffner.stiffner_Vert_Pitch',
                    value,
                  ),
                ),
              ],
            ),
            _ => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _switchTile(
                  title: 'Thermo Pocket 1',
                  value: state.formData.boolAt('thermoPkt.thermoPkt1'),
                  onChanged: (value) =>
                      controller.updateField('thermoPkt.thermoPkt1', value),
                ),
                _switchTile(
                  title: 'Thermo Pocket 2',
                  value: state.formData.boolAt('thermoPkt.thermoPkt2'),
                  onChanged: (value) =>
                      controller.updateField('thermoPkt.thermoPkt2', value),
                ),
                _switchTile(
                  title: 'Expansion Vent',
                  value: state.formData.boolAt('exp_Vent.exp_Vent'),
                  onChanged: (value) =>
                      controller.updateField('exp_Vent.exp_Vent', value),
                ),
                _switchTile(
                  title: 'Expansion Vent With OI',
                  value: state.formData.boolAt('exp_Vent.exp_Vent_With_OI'),
                  onChanged: (value) => controller.updateField(
                    'exp_Vent.exp_Vent_With_OI',
                    value,
                  ),
                ),
                _textField(
                  label: 'Expansion Vent ID',
                  value: state.formData.stringAt('exp_Vent.exp_Vent_ID'),
                  onChanged: (value) =>
                      controller.updateField('exp_Vent.exp_Vent_ID', value),
                ),
                _textField(
                  label: 'PRV',
                  value: state.formData.stringAt('restOfVariables.prv'),
                  onChanged: (value) =>
                      controller.updateField('restOfVariables.prv', value),
                ),
                _textField(
                  label: 'Marshalling Box',
                  value: state.formData.stringAt('restOfVariables.mbox'),
                  onChanged: (value) =>
                      controller.updateField('restOfVariables.mbox', value),
                ),
                _textField(
                  label: 'Marshalling Inst. Nos',
                  value: state.formData.stringAt(
                    'restOfVariables.mbox_Inst_Nos',
                  ),
                  onChanged: (value) => controller.updateField(
                    'restOfVariables.mbox_Inst_Nos',
                    value,
                  ),
                ),
                _textField(
                  label: 'Thermo Syphon',
                  value: state.formData.stringAt('restOfVariables.thrmo_Syphn'),
                  onChanged: (value) => controller.updateField(
                    'restOfVariables.thrmo_Syphn',
                    value,
                  ),
                ),
              ],
            ),
          },
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.controller, required this.state});

  final FabricationController controller;
  final FabricationState state;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: '3D Preview',
      trailing: TextButton.icon(
        onPressed: () => _showPreviewDialog(context),
        icon: const Icon(Icons.open_in_full_outlined),
        label: const Text('Maximize'),
      ),
      child: SizedBox(
        height: 280,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: _PreviewContent(state: state),
          ),
        ),
      ),
    );
  }

  Future<void> _showPreviewDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Fabrication 3D Preview'),
          content: SizedBox(
            width: 900,
            height: 520,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _PreviewContent(state: state, expanded: true),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.state, this.expanded = false});

  final FabricationState state;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    if (state.hasCadModel) {
      return GlbModelViewer(
        key: ValueKey<int>(identityHashCode(state.cadModel!.bytes)),
        bytes: state.cadModel!.bytes,
      );
    }

    if (state.drawingsStatuses.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Latest CAD activity',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final entry in state.drawingsStatuses.take(expanded ? 8 : 4))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_statusIcon(entry.status), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.message,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _timeLabel(entry.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
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

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: expanded ? 520 : 260),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.precision_manufacturing_outlined, size: 44),
            const SizedBox(height: 12),
            Text(
              'No CAD model loaded yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Run fabrication calculation and start Generate 3D to populate the model and status timeline.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.controller, required this.state});

  final FabricationController controller;
  final FabricationState state;

  @override
  Widget build(BuildContext context) {
    return _SectionPanel(
      title: 'Actions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: state.isLoading ? null : controller.calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Calculate'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _primaryAction(context),
            icon: Icon(
              state.cadPrimaryAction == FabricationCadAction.showStatus
                  ? Icons.list_alt_outlined
                  : Icons.view_in_ar_outlined,
            ),
            label: Text(
              state.cadPrimaryAction == FabricationCadAction.showStatus
                  ? 'Show Status'
                  : 'Generate 3D',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => controller.refreshStatuses(),
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('Refresh Status'),
          ),
          const SizedBox(height: 16),
          _MetricRow(
            label: 'Primary Action',
            value: state.cadPrimaryAction == FabricationCadAction.showStatus
                ? 'Show Status'
                : 'Generate 3D',
          ),
          _MetricRow(
            label: 'Pending Entries',
            value: '${state.drawingsStatuses.length}',
          ),
          _MetricRow(
            label: 'Model Ready',
            value: state.hasCadModel ? 'Yes' : 'No',
          ),
          if (state.latestStatus != null)
            _MetricRow(
              label: 'Latest Message',
              value: state.latestStatus!.message,
            ),
        ],
      ),
    );
  }

  VoidCallback? _primaryAction(BuildContext context) {
    if (state.cadPrimaryAction == FabricationCadAction.showStatus) {
      return () {
        controller.openStatusDrawer();
        controller.refreshStatuses();
      };
    }

    if (!state.canGenerate3D) {
      return null;
    }

    return () async {
      final generated = await controller.generate3D();
      if (!generated || !context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'CAD drawings generation is in progress. Check the status timeline in a few minutes.',
          ),
        ),
      );
    };
  }
}

class _StatusDrawer extends StatelessWidget {
  const _StatusDrawer({
    required this.state,
    required this.onClose,
    required this.onRefresh,
  });

  final FabricationState state;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final isOpen = state.isStatusDrawerOpen;
    final duration = _durationLabel(state.drawingsStatuses);
    final latest = state.latestStatus;

    return IgnorePointer(
      ignoring: !isOpen,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: isOpen ? 1 : 0,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                child: const ColoredBox(
                  color: Color.fromRGBO(15, 23, 42, 0.24),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                offset: isOpen ? Offset.zero : const Offset(1, 0),
                child: SizedBox(
                  width: 430,
                  child: Material(
                    color: Colors.white,
                    elevation: 24,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Fabrication 3D Generation Status',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                IconButton(
                                  onPressed: onClose,
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _MetricRow(label: 'Duration', value: duration),
                            _MetricRow(
                              label: 'Current Status',
                              value: latest == null
                                  ? 'No status entries'
                                  : latest.message.contains('Process finished!')
                                  ? 'Success'
                                  : 'Processing',
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: onRefresh,
                                icon: const Icon(Icons.refresh_outlined),
                                label: const Text('Refresh'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: state.drawingsStatuses.isEmpty
                                  ? const Center(
                                      child: Text(
                                        'No status entries are available for this design yet.',
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: state.drawingsStatuses.length,
                                      separatorBuilder: (_, index) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final entry =
                                            state.drawingsStatuses[index];
                                        return ListTile(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 0,
                                                vertical: 4,
                                              ),
                                          leading: Icon(
                                            _statusIcon(entry.status),
                                          ),
                                          title: Text(entry.message),
                                          subtitle: Text(
                                            _timeLabel(entry.createdAt),
                                          ),
                                          trailing: Text(entry.status),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _durationLabel(List<dynamic> entries) {
    if (entries.length < 2) {
      return '0.00 sec';
    }

    final start = DateTime.tryParse(entries.first.createdAt ?? '');
    final end = DateTime.tryParse(entries.last.createdAt ?? '');
    if (start == null || end == null) {
      return '0.00 sec';
    }

    final difference = end.difference(start);
    if (difference.inSeconds < 60) {
      return '${difference.inMilliseconds / 1000} sec';
    }

    return '${difference.inMinutes} min ${difference.inSeconds % 60} sec';
  }
}

class _FabricationEmptyState extends StatelessWidget {
  const _FabricationEmptyState({required this.routeId});

  final String routeId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fabrication',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  routeId.isEmpty
                      ? 'Open fabrication from a saved design so the current transformer data and design entity context are available.'
                      : 'This route currently expects a loaded design summary from the design workspace or design list.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                const Text(
                  'The fabrication workflow depends on seeded two-winding values, optional core results, persisted fabrication state, and CAD status tracking.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionPanel extends StatelessWidget {
  const _SectionPanel({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(15, 23, 42, 0.06),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) ...<Widget>[trailing!],
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayedValue = value.isEmpty ? '-' : value;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$label: $displayedValue',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.foregroundColor});

  final IconData icon;
  final String label;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final color = foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < tabs.length; index++)
          ChoiceChip(
            key: ValueKey<String>('fabrication-tab-${tabs[index]}'),
            label: Text(tabs[index]),
            selected: activeIndex == index,
            onSelected: (_) => onChanged(index),
          ),
      ],
    );
  }
}

Widget _textField({
  required String label,
  required String value,
  required ValueChanged<String>? onChanged,
}) {
  return SizedBox(
    width: 168,
    child: TextFormField(
      key: ValueKey<String>('fabrication-field-$label-$value'),
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

Widget _readOnlyField({required String label, required String value}) {
  return SizedBox(
    width: 168,
    child: TextFormField(
      key: ValueKey<String>('fabrication-readonly-$label-$value'),
      initialValue: value,
      enabled: false,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
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
    width: 168,
    child: DropdownButtonFormField<String>(
      key: ValueKey<String>('fabrication-dropdown-$label-$effectiveValue'),
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
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    ),
  );
}

Widget _switchTile({
  required String title,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return SizedBox(
    width: 168,
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
    ),
  );
}

IconData _statusIcon(String status) {
  return switch (status.toLowerCase()) {
    'success' => Icons.check_circle_outline,
    'failed' => Icons.error_outline,
    'generate_3d_requested' => Icons.pending_outlined,
    _ => Icons.radio_button_unchecked,
  };
}

String _timeLabel(String? isoString) {
  final value = DateTime.tryParse(isoString ?? '');
  if (value == null) {
    return '-';
  }

  final local = value.toLocal();
  String pad(int number) => number.toString().padLeft(2, '0');
  return '${pad(local.hour)}:${pad(local.minute)}:${pad(local.second)}';
}
