import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../design_workspace/domain/models/core_calculation_result.dart';
import '../../design_workspace/domain/models/core_stack_step.dart';
import '../../design_workspace/domain/models/two_winding_design.dart';
import '../../fabrication/domain/models/fabrication_calculation_result.dart';
import '../../multi_winding/domain/models/multi_winding_design.dart';
import 'files_state.dart';

enum FilesExportAction {
  designPrintOut('Des. Print Out'),
  gtp('GTP'),
  coreAssembly('Core Assembly'),
  coreBlade('Core Blade'),
  lom('LOM'),
  tank('Tank'),
  activePart('ActivePart'),
  conservator('Conservator'),
  lid('Lid'),
  mainAssemblyGad('MainAssembly_GAD'),
  ratingPlate('Rating Plate'),
  printAll('Print All');

  const FilesExportAction(this.label);

  final String label;

  static FilesExportAction fromLabel(String label) {
    return FilesExportAction.values.firstWhere(
      (action) => action.label == label,
      orElse: () => throw ArgumentError.value(label, 'label'),
    );
  }
}

abstract interface class FilesDocumentOpener {
  Future<void> openDocument({
    required String fileName,
    required Uint8List bytes,
  });

  Future<void> openUrl(Uri uri);
}

class UrlLauncherFilesDocumentOpener implements FilesDocumentOpener {
  @override
  Future<void> openDocument({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await openUrl(file.uri);
  }

  @override
  Future<void> openUrl(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Unable to open ${uri.toString()}');
    }
  }
}

class FilesExportService {
  FilesExportService({FilesDocumentOpener? opener, Uri? deliveryBaseUri})
    : _opener = opener ?? UrlLauncherFilesDocumentOpener(),
      _deliveryBaseUri =
          deliveryBaseUri ?? Uri.parse('https://design.trafointel.com');

  final FilesDocumentOpener _opener;
  final Uri _deliveryBaseUri;

  Future<void> exportByLabel({
    required String label,
    required FilesState state,
  }) async {
    await exportAction(
      action: FilesExportAction.fromLabel(label),
      state: state,
    );
  }

  Future<void> exportAction({
    required FilesExportAction action,
    required FilesState state,
  }) async {
    if (action == FilesExportAction.printAll) {
      for (final nextAction in FilesExportAction.values) {
        if (nextAction == FilesExportAction.printAll) {
          continue;
        }
        await exportAction(action: nextAction, state: state);
      }
      return;
    }

    final hostedUri = hostedUriForAction(action: action, state: state);
    if (hostedUri != null) {
      await _opener.openUrl(hostedUri);
      return;
    }

    final fileName = _fileNameForAction(action: action, state: state);
    final bytes = await _buildDocumentBytes(action: action, state: state);
    await _opener.openDocument(fileName: fileName, bytes: bytes);
  }

  Uri? hostedUriForAction({
    required FilesExportAction action,
    required FilesState state,
  }) {
    final designId = _designReference(state);
    if (designId.isEmpty) {
      return null;
    }

    final suffix = switch (action) {
      FilesExportAction.tank => '_Tank_GAD.pdf',
      FilesExportAction.activePart => '_ActivePart_GAD.pdf',
      FilesExportAction.conservator => '_Conservator.pdf',
      FilesExportAction.lid => '_Lid.pdf',
      FilesExportAction.mainAssemblyGad => '_MainAssembly_GAD.pdf',
      FilesExportAction.ratingPlate => '_Rating_plate.pdf',
      _ => null,
    };

    if (suffix == null) {
      return null;
    }

    return _deliveryBaseUri.resolve('/000_delivery/$designId/$designId$suffix');
  }

  String _fileNameForAction({
    required FilesExportAction action,
    required FilesState state,
  }) {
    final designId = _safeFileSegment(_designReference(state));
    final suffix = switch (action) {
      FilesExportAction.designPrintOut => 'design_print_out',
      FilesExportAction.gtp => 'gtp',
      FilesExportAction.coreAssembly => 'core_assembly',
      FilesExportAction.coreBlade => 'core_blade',
      FilesExportAction.lom => 'lom',
      _ => action.name,
    };
    const extension = 'pdf';
    return '${designId}_$suffix.$extension';
  }

  Future<Uint8List> _buildDocumentBytes({
    required FilesExportAction action,
    required FilesState state,
  }) async {
    final document = pw.Document();

    final title = action.label;

    if (action == FilesExportAction.designPrintOut) {
      final theme = await _designPrintTheme();
      document.addPage(
        pw.MultiPage(
          pageFormat: state.multiWindingDesign == null
              ? PdfPageFormat.letter
              : PdfPageFormat.letter.landscape,
          margin: state.multiWindingDesign == null
              ? const pw.EdgeInsets.all(36)
              : const pw.EdgeInsets.all(30),
          theme: theme,
          build: (context) => state.multiWindingDesign == null
              ? _buildDesignPrintOut(state)
              : _buildMultiWindingDesignPrintOut(state),
        ),
      );
    } else if (action == FilesExportAction.coreAssembly ||
        action == FilesExportAction.coreBlade) {
      final corePrintImages = await _loadCorePrintImages();
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.fromLTRB(54, 60, 42, 48),
          build: (context) => action == FilesExportAction.coreAssembly
              ? _coreAssemblyPrintout(state, corePrintImages)
              : _coreBladePrintout(state, corePrintImages),
        ),
      );
    } else {
      document.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          build: (context) => [
            _buildHeader(title: title, state: state),
            pw.SizedBox(height: 14),
            ...switch (action) {
              FilesExportAction.designPrintOut => _buildDesignPrintOut(state),
              FilesExportAction.gtp => _buildGtp(state),
              FilesExportAction.coreAssembly => _buildCoreAssembly(state),
              FilesExportAction.coreBlade => _buildCoreBlade(state),
              FilesExportAction.lom => _buildLom(state),
              _ => const <pw.Widget>[],
            },
          ],
        ),
      );
    }

    return Uint8List.fromList(await document.save());
  }

  Future<pw.ThemeData> _designPrintTheme() async {
    Future<pw.Font?> loadFont(String path) async {
      final file = File(path);
      if (!await file.exists()) {
        return null;
      }
      final bytes = await file.readAsBytes();
      return pw.Font.ttf(ByteData.sublistView(bytes));
    }

    final base = Platform.isWindows
        ? await loadFont(r'C:\Windows\Fonts\arial.ttf')
        : null;
    final symbolFallback = Platform.isWindows
        ? await loadFont(r'C:\Windows\Fonts\seguisym.ttf')
        : null;
    final fallbacks = <pw.Font>[?symbolFallback];

    return pw.ThemeData.withFont(
      base: base,
      bold: base,
      fontFallback: fallbacks,
    );
  }

  Future<_CorePrintImages> _loadCorePrintImages() async {
    Future<pw.MemoryImage> load(String path) async {
      try {
        final data = await rootBundle.load(path);
        return pw.MemoryImage(data.buffer.asUint8List());
      } catch (_) {
        return pw.MemoryImage(await File(path).readAsBytes());
      }
    }

    return _CorePrintImages(
      assembly3Blade: await load('assets/core_preview/Assembly1.png'),
      assembly4Blade: await load('assets/core_preview/Assembly2.png'),
      blade3Images: [
        await load('assets/core_preview/core1.png'),
        await load('assets/core_preview/core2.png'),
        await load('assets/core_preview/core3.png'),
      ],
      blade4Images: [
        await load('assets/core_preview/core4.1.png'),
        await load('assets/core_preview/core4.2.png'),
        await load('assets/core_preview/core4.3.png'),
        await load('assets/core_preview/core4.4.png'),
      ],
    );
  }

  List<pw.Widget> _buildDesignPrintOut(FilesState state) {
    return [
      _designTable(
        [
          [
            'Customer Name: ${_blankIfMissing(state.customerName)}',
            'First Line:',
          ],
          ['Place: ${_blankIfMissing(state.customerPlace)}', ''],
          [
            'Design Ref: ${_designReference(state)}',
            'KVA: ${_blankIfMissing(state.twoWindingDesign?.readPath('kVA'))}',
          ],
        ],
        const <double>[4765, 4590],
      ),
      _gap(),
      _designTable(_coreRows(state), const <double>[2515, 2520, 2910, 2845]),
      _gap(),
      _windingDataBlock(state),
      _gap(),
      _designTable(_fabricationRowsForDesignPrint(state), const <double>[
        2697,
        2697,
        2698,
        2698,
      ]),
      _gap(),
      _generalPerformanceBlock(state),
      _gap(height: 3),
      pw.Text('Tapping:', style: const pw.TextStyle(fontSize: 9)),
      _designTable(_tappingRowsForDesignPrint(state), const <double>[
        1975,
        8815,
      ]),
      _gap(),
      _designTable(
        [
          ['Date: ${_dateLabel()}', 'Designed By:', 'Verified By:'],
        ],
        const <double>[3596, 3597, 3597],
      ),
    ];
  }

  List<pw.Widget> _buildMultiWindingDesignPrintOut(FilesState state) {
    final design = state.multiWindingDesign!;
    return [
      _designTable(
        [
          [
            'Customer Name: ${_blankIfMissing(state.customerName)}',
            'First Line:',
          ],
          ['Place: ${_blankIfMissing(state.customerPlace)}', ''],
          [
            'Design Ref: ${_designReference(state)}',
            'KVA: ${_blankIfMissing(design.readPath('kVA'))}',
          ],
        ],
        const <double>[4765, 4590],
        tableWidth: _multiDesignPrintContentWidth,
        fontSize: 7.5,
        verticalPadding: 0.4,
      ),
      _gap(height: 1),
      _designTable(
        _multiCoreRows(design, state.coreResult),
        const <double>[2515, 2520, 2910, 2845],
        tableWidth: _multiDesignPrintContentWidth,
        fontSize: 7.5,
        verticalPadding: 0.4,
      ),
      _gap(height: 1),
      _designTable(
        _multiWindingRows(design),
        const <double>[2136, 2396, 2206, 2184, 1950, 2184],
        tableWidth: _multiDesignPrintContentWidth,
        fontSize: 6.2,
        horizontalPadding: 2,
        verticalPadding: 0.15,
      ),
      _gap(height: 1),
      pw.Text('Coil Dimensions:', style: const pw.TextStyle(fontSize: 7.5)),
      _designTable(
        _multiCoilDimensionRows(design),
        const <double>[
          1339,
          1421,
          1248,
          1170,
          1014,
          1014,
          1092,
          1092,
          1248,
          1248,
          1248,
          1092,
        ],
        tableWidth: _multiDesignPrintContentWidth,
        fontSize: 5.8,
        horizontalPadding: 1.2,
        verticalPadding: 0.2,
      ),
      _gap(height: 1),
      pw.Text('TANK DETAILS', style: const pw.TextStyle(fontSize: 7.5)),
      _designTable(
        _multiFabricationRows(design, state.fabricationResult),
        const <double>[2697, 2697, 2698, 2698],
        tableWidth: _multiDesignPrintContentWidth,
        fontSize: 7.0,
        verticalPadding: 0.35,
      ),
      _gap(height: 1),
      _multiGeneralPerformanceBlock(design),
      _gap(height: 1),
      pw.Text('Taps Description :', style: const pw.TextStyle(fontSize: 7.5)),
      _designTable(
        _multiTapRows(design),
        const <double>[1975, 6001, 6419],
        tableWidth: _multiDesignPrintContentWidth,
        fontSize: 6.8,
        verticalPadding: 0.25,
      ),
    ];
  }

  List<List<Object>> _multiCoreRows(
    MultiWindingDesign design,
    CoreCalculationResult? core,
  ) {
    return [
      [
        'Frame: ${_blankIfMissing(design.readPath('core.coreDia'))}',
        'Core Factor: ${_multiValue(design, ['core.coreFactor', 'buildFactor'])}',
        'Core Type: ${_blankIfMissing(design.readPath('core.coreType'))}',
        'Grade: ${_multiValue(design, ['core.grade', 'core.wkgGrade', 'core.coreMaterial'])}',
      ],
      [
        'Area: ${_blankIfMissing(_firstAvailable([core?.coreArea, design.readPath('core.area')]))}',
        'Weight: ${_multiValue(design, ['core.coreWeight', 'tankAndOilFormulas.weightCore'], fallback: core?.coreWeight)}',
        'Flux Density: ${_multiValue(design, ['revisedFluxDensity', 'fluxDensity'])}',
        'Frequency: ${_blankIfMissing(design.readPath('frequency'))}',
      ],
      [
        'Volts/Turn: ${_multiValue(design, ['performance.voltsPerTurn', 'revisedVoltsPerTurn'])}',
        'Temperature: ${_blankIfMissing(design.readPath('windingTemp'))}',
        'Cooling: ${_blankIfMissing(design.readPath('eRadiatorType'))}',
        'Vector Group: ${_blankIfMissing(design.readPath('vectorGroup'))}',
      ],
    ];
  }

  List<List<Object>> _multiWindingRows(MultiWindingDesign design) {
    final windingIds = _multiWindingIds;
    List<Object> row(String label, String Function(String id) value) {
      return [label, for (final id in windingIds) value(id)];
    }

    return [
      [
        'WINDING DATA',
        '1.INNER',
        '2. HV Winding',
        '3. COARSE Winding',
        '4. FINE2 Winding',
        '5. OUTER Winding',
      ],
      row('Phase A / V', (id) => _multiWindingVoltage(design, id)),
      row(
        'Turns/Limb',
        (id) => _multiWindingValue(design, id, 'turnsPerPhase'),
      ),
      row('Type of WDG', (id) => _multiWindingType(design, id)),
      row('No.of Coils', (id) => _multiWindingValue(design, id, 'noOfCoils')),
      row(
        'Turns per Coil',
        (id) => _multiWindingValue(design, id, 'turnsPerCoil'),
      ),
      row('Turns/Layer', (id) => _multiWindingValue(design, id, 'turnsLayers')),
      row(
        'INSLN - Layer',
        (id) => _multiWindingValue(design, id, 'interLayerInsulation'),
      ),
      row('Oil Duct', (id) => _multiDuctLabel(design, id)),
      row(
        'Oil b/w Coils',
        (id) => _multiWindingValue(design, id, 'discDuctSize'),
      ),
      row('Cond-Size + Paper Thick.', (id) {
        final conductor = _multiConductorLabel(design, id);
        final paper = _multiWindingValue(design, id, 'condInsulation');
        if (conductor.isEmpty) return paper;
        if (paper.isEmpty) return conductor;
        return '$conductor + $paper';
      }),
      row('No.in Parallel', (id) => _multiParallelLabel(design, id)),
      row(
        'Cond. Cross-Section',
        (id) => _multiWindingValue(design, id, 'condCrossSec'),
      ),
      row(
        'Transposition',
        (id) => _multiWindingValue(design, id, 'transposition'),
      ),
      row('Radial Thickness', (id) => _multiRadialValue(design, id)),
      row(
        'Winding Length',
        (id) => _multiWindingValue(design, id, 'windingLength'),
      ),
      row('Current Density (A/mm²)', (id) {
        return _blankIfMissing(
          _readMulti(design, [
            'part2Windings.$id.currentDensity',
            _multiSpec(id).currentDensityPath,
          ]),
        );
      }),
      row(
        'Turn Length (m)',
        (id) => _multiWindingValue(design, id, 'turnLength'),
      ),
      row(
        'Wire Length (m)',
        (id) => _multiWindingValue(design, id, 'wireLength'),
      ),
      row('R @75°C Ohms/ph Nom', (id) => _multiWindingValue(design, id, 'r75')),
      row('Weight bare/Cover (kg)', (id) {
        return _blankIfMissing(
          _readMulti(design, [
            'part2Windings.$id.weightBareInsulated',
            'multiCost.conductors.$id.weight',
          ]),
        );
      }),
      row(
        'Stray Loss %',
        (id) => _multiWindingValue(design, id, 'eddyStrayLoss'),
      ),
      row('Load Loss w', (id) => _multiWindingValue(design, id, 'loadLoss')),
      row(
        'Temperature Gradient °C',
        (id) => _multiWindingValue(design, id, 'tempGradDegC'),
      ),
      row(
        'End Clearances (mm)',
        (id) => _multiWindingValue(design, id, 'endClearances'),
      ),
      row(
        'Window Height (mm)',
        (id) => _blankIfMissing(design.readPath('core.limbHt')),
      ),
      row('Ampere Turns', (id) => _multiAmpereTurnsLabel(design, id)),
    ];
  }

  List<List<Object>> _multiCoilDimensionRows(MultiWindingDesign design) {
    return [
      [
        'Diametrical',
        'Core Dia',
        'LV-ID',
        'LV-OD',
        'HV-ID',
        'HV-OD',
        'Coar-ID',
        'Coar-OD',
        'Fine2-ID',
        'Fine2-OD',
        'Outer-ID',
        'Outer-OD',
      ],
      [
        'Dia Dim',
        _multiValue(design, ['coilDimensions.coreDia', 'core.coreDia']),
        _multiValue(design, ['coilDimensions.lvid']),
        _multiValue(design, ['coilDimensions.lvod']),
        _multiValue(design, ['coilDimensions.hvid']),
        _multiValue(design, ['coilDimensions.hvod']),
        _multiValue(design, ['multiCoilDimensions.corse.id']),
        _multiValue(design, ['multiCoilDimensions.corse.od']),
        _multiValue(design, ['multiCoilDimensions.fine.id']),
        _multiValue(design, ['multiCoilDimensions.fine.od']),
        _multiValue(design, ['multiCoilDimensions.outer.id']),
        _multiValue(design, ['multiCoilDimensions.outer.od']),
      ],
      const [''],
      [
        'Radial x 2',
        '',
        _multiValue(design, ['coilDimensions.lvradial']),
        '',
        _multiValue(design, ['coilDimensions.hvradial']),
        '',
        _multiValue(design, ['multiCoilDimensions.corse.radial']),
        '',
        _multiValue(design, ['multiCoilDimensions.fine.radial']),
        '',
        _multiValue(design, ['multiCoilDimensions.outer.radial']),
        '',
      ],
      [
        'Radial Clearances',
        'Core-LV ${_multiValue(design, ['coilDimensions.coreGap'])}',
        'LvRad ${_multiValue(design, ['coilDimensions.lvradial'])}',
        'Lv-HV ${_multiValue(design, ['coilDimensions.lvhvgap'])}',
        'HvRad ${_multiValue(design, ['coilDimensions.hvradial'])}',
        'Hv-Crs ${_multiValue(design, ['multiCoilDimensions.gaps.hvMainToCorseGap'])}',
        'CrsRad ${_multiValue(design, ['multiCoilDimensions.corse.radial'])}',
        'Crs-Fin ${_multiValue(design, ['multiCoilDimensions.gaps.corseToFineGap'])}',
        'FinRad ${_multiValue(design, ['multiCoilDimensions.fine.radial'])}',
        'Fine-Out ${_multiValue(design, ['multiCoilDimensions.gaps.fineToOuterGap'])}',
        'OutRad ${_multiValue(design, ['multiCoilDimensions.outer.radial'])}',
        'LimbGap ${_multiValue(design, ['core.cenDist', 'coilDimensions.centerDistance'])}',
      ],
    ];
  }

  List<List<Object>> _multiFabricationRows(
    MultiWindingDesign design,
    FabricationCalculationResult? fabrication,
  ) {
    return [
      [
        'Side sheet: ${_multiValue(design, ['tank.tankWallThickness'], fallback: fabrication?.readPath('tank.sideSheet'))}',
        'Bot. Sheet: ${_multiValue(design, ['tank.tankBottomThickness'], fallback: fabrication?.readPath('tank.bottomSheet'))}',
        'Lid Sheet: ${_multiValue(design, ['tank.tankLidThickness'], fallback: fabrication?.readPath('lid.lid_Thick'))}',
        'Frame: ${_multiValue(design, ['tank.frameThickness'])}',
      ],
      [
        'Tank Size',
        'Length: ${_multiValue(design, ['tank.tankLength'], fallback: fabrication?.readPath('tank.length'))}',
        'Width: ${_multiValue(design, ['tank.tankWidth'], fallback: fabrication?.readPath('tank.width'))}',
        'Height: ${_multiValue(design, ['tank.tankHeight'], fallback: fabrication?.readPath('tank.height'))}',
      ],
      [
        'Radiator: ${_multiValue(design, ['tankAndOilFormulas.noOfRadiators'], fallback: fabrication?.readPath('radiator.radiator_Nos'))}',
        'Length: ${_multiValue(design, ['tankAndOilFormulas.radiatorHeight'], fallback: fabrication?.readPath('radiator.radiator_CC'))}',
        'Width: ${_multiValue(design, ['tankAndOilFormulas.radiatorWidth'], fallback: fabrication?.readPath('radiator.radiator_W'))}',
        'Sections: ${_multiValue(design, ['tankAndOilFormulas.radiatorSection', 'tankAndOilFormulas.noOfFinsPerRadiator'], fallback: fabrication?.readPath('radiator.radiator_Fin_Nos'))}',
      ],
      [
        'Conservator:',
        'Dia: ${_multiValue(design, ['tankAndOilFormulas.conservatorDia'])}',
        'Length: ${_multiValue(design, ['tankAndOilFormulas.conservatorLength'])}',
        'Volume: ${_multiValue(design, ['tankAndOilFormulas.conservatorCapacity'], fallback: fabrication?.readPath('conservator.volume'))}',
      ],
    ];
  }

  pw.Widget _multiGeneralPerformanceBlock(MultiWindingDesign design) {
    return _designTable(
      [
        [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _templateText('Generals', fontSize: 7),
              _designTable(
                [
                  [
                    _templateLines([
                      'Weights',
                      'Core & Wdg: ${_multiValue(design, ['tankAndOilFormulas.weightsOfActivePart'])}',
                      'Tank & Fitting: ${_multiValue(design, ['tankAndOilFormulas.weightOfTankAndAcc'])}',
                      'Oil: ${_multiValue(design, ['tankAndOilFormulas.oilWeight', 'tankAndOilFormulas.totalOil'])}',
                      'Total: ${_multiValue(design, ['tankAndOilFormulas.transformerWeight'])}',
                      'Over-all Dimensions: ${_multiValue(design, ['tank.overallDimension', 'tankAndOilFormulas.overallDimension'])}',
                    ], fontSize: 6.8),
                    _templateLines([
                      'Cost (Total: ${_multiValue(design, ['cost.capitalCost'])})',
                      'Oil: ${_multiValue(design, ['cost.totalOilCost'])}',
                      'Cond: ${_multiValue(design, ['cost.totalCondCost'])}',
                      'Core: ${_multiValue(design, ['cost.totalCoreCost'])}',
                      'Insulation: ${_multiValue(design, ['cost.totalInsCost'])}',
                      'Steel: ${_multiValue(design, ['cost.totalSteelCost'])}',
                      'Radiators: ${_multiValue(design, ['cost.totalRadiatorCost'])}',
                    ], fontSize: 6.8),
                  ],
                ],
                const <double>[2584, 2585],
                tableWidth: 344,
                fontSize: 6.8,
                horizontalPadding: 2,
                verticalPadding: 0.2,
              ),
            ],
          ),
          _templateLines([
            'Performance',
            'No Load Loss: ${_multiValue(design, ['performance.noLoadLoss', 'coreLoss'])}',
            'Load Loss: ${_multiValue(design, ['performance.loadLoss', 'loadLoss'])}',
            'Tank Stray Loss: ${_multiValue(design, ['tank.tankLoss'])}',
            'Resistance: ${_multiValue(design, ['performance.resistance'])}',
            'Reactance: ${_multiValue(design, ['performance.reactance'])}',
            'Impedance: ${_multiValue(design, ['performance.impedance', 'ez'])}',
            'No Load Current (%): ${_multiValue(design, ['performance.nlCurrentPercentage'])}',
          ], fontSize: 7),
        ],
      ],
      const <double>[5395, 5395],
      tableWidth: _multiDesignPrintContentWidth,
      fontSize: 7,
      horizontalPadding: 2,
      verticalPadding: 0.35,
    );
  }

  List<List<Object>> _multiTapRows(MultiWindingDesign design) {
    return [
      ['Tapping Details', _multiTapSummary(design), ''],
      [
        'HV Taps',
        _multiValue(design, ['hvTaps', 'tapDetails.hv']),
        '',
      ],
      [
        'Corse Taps',
        _multiValue(design, ['corseTaps', 'tapDetails.corse']),
        '',
      ],
      [
        'Fine Taps',
        _multiValue(design, ['fineTaps', 'tapDetails.fine']),
        '',
      ],
      [
        'Edge Taps',
        _multiValue(design, ['edgeTaps', 'tapDetails.edge']),
        '',
      ],
      [
        'Test Voltage',
        'HV: ${_multiValue(design, ['hvTestVoltage'])}',
        'LV: ${_multiValue(design, ['lvTestVoltage'])}',
      ],
    ];
  }

  List<_DesignPrintField> _performanceRows(FilesState state) {
    final design = state.twoWindingDesign;
    return [
      _DesignPrintField(
        'No Load Loss:',
        _readDesign(design, ['hvFormulas.coreLoss', 'coreLoss']),
      ),
      _DesignPrintField(
        'Load Loss:',
        _readDesign(design, [
          'hvFormulas.totalLoadLoss',
          'lossesAt100Percent',
          'loadLoss',
        ]),
      ),
      _DesignPrintField(
        'Tank Stray Loss:',
        _readDesign(design, ['hvFormulas.tankLoss', 'tankLoss']),
      ),
      _DesignPrintField(
        'Resistance:',
        _readDesign(design, ['commonFormulas.er', 'resistance']),
      ),
      _DesignPrintField(
        'Reactance:',
        _readDesign(design, ['commonFormulas.ex', 'reactance']),
      ),
      _DesignPrintField(
        'Impedance:',
        _readDesign(design, ['commonFormulas.ek', 'ez']),
      ),
      _DesignPrintField(
        'No Load Current (%):',
        _readDesign(design, ['noLoadCurrent', 'commonFormulas.noLoadCurrent']),
      ),
    ];
  }

  String _tapSummary(Object? design) {
    if (design is! TwoWindingDesign) {
      return '-';
    }

    final positive = _display(design.readPath('tapStepsPositive'));
    final negative = _display(design.readPath('tapStepsNegative'));
    final percent = _display(design.readPath('tapStepsPercent'));
    final turns = _display(_turnsPerTapValue(design));
    final parts = <String>[
      if (positive != '-' || negative != '-') '+$positive to -$negative',
      if (percent != '-') '@ $percent%',
      'HV',
      if (turns != '-') '$turns Turns/Step',
    ];
    return parts.join(', ');
  }

  pw.Widget _buildHeader({required String title, required FilesState state}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 72,
              height: 42,
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500),
              ),
              child: pw.Text(
                'LOGO\nPLACEHOLDER',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Design Ref: ${_designReference(state)}'),
                  if (state.customerName.trim().isNotEmpty)
                    pw.Text('Customer: ${state.customerName.trim()}'),
                  if (state.customerPlace.trim().isNotEmpty)
                    pw.Text('Place: ${state.customerPlace.trim()}'),
                  pw.Text('Generated: ${_timestampLabel()}'),
                ],
              ),
            ),
          ],
        ),
        pw.Divider(),
      ],
    );
  }

  List<List<Object>> _coreRows(FilesState state) {
    final design = state.twoWindingDesign;
    final core = state.coreResult;
    return [
      [
        'Frame: ${_blankIfMissing(design?.readPath('core.coreDia'))}',
        'Core Factor: ${_designValue(design, ['core.coreFactor', 'buildFactor'])}',
        'Core Type: ${_blankIfMissing(design?.readPath('core.coreType'))}',
        'Grade: ${_designValue(design, ['core.grade', 'core.wkgGrade', 'core.coreMaterial'])}',
      ],
      [
        'Area: ${_blankIfMissing(_firstAvailable([core?.coreArea, design?.readPath('core.area')]))}',
        'Weight: ${_designValue(design, ['core.coreWeight', 'hvFormulas.coreWeight'], fallback: core?.coreWeight)}',
        'Flux Density: ${_designValue(design, ['core.fluxDensity', 'fluxDensity'])}',
        'Frequency: ${_blankIfMissing(design?.readPath('frequency'))}',
      ],
      [
        'Volts/Turn: ${_blankIfMissing(design?.readPath('voltsPerTurn'))}',
        'Temperature: ${_blankIfMissing(design?.readPath('windingTemp'))}',
        'Cooling: ${_blankIfMissing(design?.readPath('cooling'))}',
        'Vector Group: ${_blankIfMissing(design?.readPath('vectorGroup'))}',
      ],
    ];
  }

  List<List<Object>> _fabricationRowsForDesignPrint(FilesState state) {
    final fabrication = state.fabricationResult;
    final design = state.twoWindingDesign;
    return [
      [
        'Side sheet: ${_designValue(design, ['tank.tankWallThickness'], fallback: fabrication?.readPath('tank.sideSheet'))}',
        'Bot. Sheet: ${_designValue(design, ['tank.tankBottomThickness'], fallback: fabrication?.readPath('tank.bottomSheet'))}',
        'Lid Sheet: ${_designValue(design, ['tank.tankLidThickness'], fallback: fabrication?.readPath('lid.lid_Thick'))}',
        'Frame: ${_designValue(design, ['tank.frameThickness', 'core.frame'])}',
      ],
      [
        'Tank Size',
        'Length: ${_designValue(design, ['tank.tankLength'], fallback: fabrication?.readPath('tank.length'))}',
        'Width: ${_designValue(design, ['tank.tankWidth'], fallback: fabrication?.readPath('tank.width'))}',
        'Height: ${_designValue(design, ['tank.tankHeight'], fallback: fabrication?.readPath('tank.height'))}',
      ],
      [
        'Radiator: ${_designValue(design, ['tankAndOilFormulas.noOfRadiators'], fallback: fabrication?.readPath('radiator.radiator_Nos'))}',
        'Length: ${_designValue(design, ['tankAndOilFormulas.radiatorHeight'], fallback: fabrication?.readPath('radiator.radiator_CC'))}',
        'Width: ${_designValue(design, ['tankAndOilFormulas.radiatorWidth', 'radiatorWidth'], fallback: fabrication?.readPath('radiator.radiator_W'))}',
        'Sections: ${_designValue(design, ['tankAndOilFormulas.noOfFinsPerRadiator'], fallback: fabrication?.readPath('radiator.radiator_Fin_Nos'))}',
      ],
      [
        'Conservator:',
        'Dia: ${_designValue(design, ['tankAndOilFormulas.conservatorDia', 'conservatorDia'])}',
        'Length: ${_designValue(design, ['tankAndOilFormulas.conservatorLength', 'conservatorLength'])}',
        'Volume: ${_designValue(design, ['tankAndOilFormulas.conservatorCapacity'], fallback: fabrication?.readPath('conservator.volume'))}',
      ],
    ];
  }

  pw.Widget _windingDataBlock(FilesState state) {
    return _designTable(
      [
        [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _templateText('Winding Data:'),
              _designTable(
                _windingRowsForDesignPrint(state),
                const <double>[1776, 2160, 2250],
                tableWidth: 321,
                fontSize: 7.8,
                horizontalPadding: 2,
                verticalPadding: 0.45,
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _templateLines([
                'Coil Dimensions:',
                'Core Dia: ${_designValue(state.twoWindingDesign, ['coilDimensions.coreDia', 'core.coreDia'])}',
                'Core-LV gap: ${_designValue(state.twoWindingDesign, ['coilDimensions.coreGap', 'coreLVClr'])}',
                'LV ID: ${_designValue(state.twoWindingDesign, ['coilDimensions.lvid', 'coilDimensions.lVID'])}',
                'LV Rad. Thick.: ${_designValue(state.twoWindingDesign, ['coilDimensions.lvradial', 'coilDimensions.lVRadial'])}',
                'LV OD: ${_designValue(state.twoWindingDesign, ['coilDimensions.lvod', 'coilDimensions.lVOD'])}',
                'LV-HV gap: ${_designValue(state.twoWindingDesign, ['coilDimensions.lvhvgap', 'coilDimensions.lVHVGap', 'lVHVClr'])}',
                'HV ID: ${_designValue(state.twoWindingDesign, ['coilDimensions.hvid', 'coilDimensions.hVID'])}',
                'HV Rad. Thick.: ${_designValue(state.twoWindingDesign, ['coilDimensions.hvradial', 'coilDimensions.hVRadial'])}',
                'HV OD: ${_designValue(state.twoWindingDesign, ['coilDimensions.hvod', 'coilDimensions.hVOD'])}',
                'HV-HV gap: ${_designValue(state.twoWindingDesign, ['coilDimensions.hvhvgap', 'coilDimensions.hVHVGap', 'hVHVGap'])}',
                'Cen. Dist.: ${_designValue(state.twoWindingDesign, ['core.cenDist', 'hvFormulas.centerDistance'])}',
                'Active Part Size: ${_designValue(state.twoWindingDesign, ['coilDimensions.activePartSize', 'hvFormulas.activePartSize'])}',
              ], fontSize: 7.8),
              _templateLines([
                'Impedance:',
                'Ls: l, b, Kr --> ls',
                'Δ’ : Δ + (h2 + h1)/3  Δ’',
                'Ds: LvOd + Δ + (h2 - h1)/3  Ds',
              ], fontSize: 7.5),
              _designTable(
                const [
                  ['(H):', 'V/T:'],
                ],
                const <double>[1963, 1963],
                tableWidth: 196,
                fontSize: 7.5,
                horizontalPadding: 2,
                verticalPadding: 0.4,
              ),
              _templateLines([
                'ex = (1.24 ∗ (H) ∗ Δ′ ∗ Ds ∗ 10−4) / (V/T ∗ ls)',
                'er: ${_designValue(state.twoWindingDesign, ['commonFormulas.er', 'resistance'])}',
                'ex: ${_designValue(state.twoWindingDesign, ['commonFormulas.ex', 'reactance'])}',
                'ez: ${_designValue(state.twoWindingDesign, ['commonFormulas.ek', 'ez'])}',
                'Insulation Clearances:',
                'Insu. Core-LV: ${_designValue(state.twoWindingDesign, ['coreLVClr', 'coilDimensions.coreGap'])}',
                'Insu. LV-HV: ${_designValue(state.twoWindingDesign, ['lVHVClr', 'coilDimensions.lvhvgap'])}',
                'Insu. HV-HV: ${_designValue(state.twoWindingDesign, ['hVHVGap', 'coilDimensions.hvhvgap'])}',
                'Tank Clearances:',
                'Yoke- Cover: ${_designValue(state.twoWindingDesign, ['tank.topYokeToCoverGap', 'tankAndOilFormulas.topYokeCoverGap'])}',
                'Wdg-Tank: ${_designValue(state.twoWindingDesign, ['tank.wdgToTankGap', 'tankAndOilFormulas.wdgTankGap'])}',
                'Wdg-Leads: ${_designValue(state.twoWindingDesign, ['tank.connectionGap', 'tankAndOilFormulas.connectionGap'])}',
              ], fontSize: 7.8),
            ],
          ),
        ],
      ],
      const <double>[6412, 4388],
      fontSize: 7.8,
      horizontalPadding: 2,
      verticalPadding: 1,
    );
  }

  List<List<Object>> _windingRowsForDesignPrint(FilesState state) {
    final design = state.twoWindingDesign;
    Object? read(String path) => design?.readPath(path);
    Object? first(List<Object?> values) => _firstAvailable(values);

    return [
      [
        'Winding Type',
        _blankIfMissing(read('lvWindingType')),
        _blankIfMissing(read('hvWindingType')),
      ],
      [
        'Voltage (V)',
        _blankIfMissing(read('lowVoltage')),
        _blankIfMissing(read('highVoltage')),
      ],
      [
        'Current (A)',
        _blankIfMissing(
          first([
            read('innerWindings.phaseCurrent'),
            read('lvFormulas.lvCurrentPerPhase'),
          ]),
        ),
        _blankIfMissing(
          first([
            read('outerWindings.phaseCurrent'),
            read('hvFormulas.hvCurrentPerPhase'),
          ]),
        ),
      ],
      [
        'No. of Limbs',
        _blankIfMissing(read('lVLimbs')),
        _blankIfMissing(read('hVLimbs')),
      ],
      [
        'Turns/Limb',
        _blankIfMissing(
          first([
            read('innerWindings.turnsPerPhase'),
            read('lvFormulas.lvTurnsPerPhase'),
          ]),
        ),
        _blankIfMissing(
          first([
            read('outerWindings.turnsPerPhase'),
            read('hvFormulas.hvTurnsPerPhase'),
          ]),
        ),
      ],
      [
        'Coils / Discs',
        _blankIfMissing(read('lvFormulas.lvNoOfCoils')),
        _blankIfMissing(
          first([
            read('hvFormulas.hvNoOfCoils'),
            read('hvFormulas.hvNoOfDiscs'),
          ]),
        ),
      ],
      [
        'Turns/Coil Disc',
        _blankIfMissing(read('lvFormulas.lvTurnsPerCoil')),
        _blankIfMissing(read('hvFormulas.hvTurnsPerCoil')),
      ],
      [
        'No. of Layers ',
        _blankIfMissing(read('innerWindings.noOfLayers')),
        _blankIfMissing(
          first([
            read('outerWindings.noOfLayers'),
            read('hvFormulas.hvNumberOfLayers'),
          ]),
        ),
      ],
      [
        'Turns/Layer',
        _blankIfMissing(read('innerWindings.turnsLayers')),
        _blankIfMissing(
          first([
            read('outerWindings.turnsLayers'),
            read('hvFormulas.hvTurnsPerLayer'),
          ]),
        ),
      ],
      [
        'Insu. b/w layer',
        _blankIfMissing(read('innerWindings.interLayerInsulation')),
        _blankIfMissing(
          first([
            read('outerWindings.interLayerInsulation'),
            read('hvFormulas.hvInterLayerInsulation'),
          ]),
        ),
      ],
      [
        'Oil Duct',
        _ductLabel(design, 'innerWindings'),
        _blankIfMissing(
          first([
            _ductLabel(design, 'outerWindings'),
            read('hvFormulas.hvDiscDuctsSize'),
            read('hvFormulas.hvDuctThickness'),
          ]),
        ),
      ],
      [
        'Conductor',
        _conductorLabel(design, 'innerWindings'),
        _conductorLabel(design, 'outerWindings'),
      ],
      [
        'Parallels',
        _parallelLabel(design, 'innerWindings'),
        _parallelLabel(design, 'outerWindings'),
      ],
      [
        'Cond Cross Sec',
        _blankIfMissing(read('innerWindings.condCrossSec')),
        _blankIfMissing(
          first([
            read('outerWindings.condCrossSec'),
            read('hvFormulas.hvConductorCrossSection'),
            read('hvFormulas.hvTotalCondCrossSection'),
          ]),
        ),
      ],
      [
        'Current Dens.',
        _blankIfMissing(
          first([
            read('innerWindings.currentDensity'),
            read('lvCurrentDensity'),
          ]),
        ),
        _blankIfMissing(
          first([
            read('outerWindings.currentDensity'),
            read('hvCurrentDensity'),
          ]),
        ),
      ],
      [
        'Radial Thick.',
        _blankIfMissing(
          first([
            read('coilDimensions.lvradial'),
            read('innerWindings.radialThickness'),
          ]),
        ),
        _blankIfMissing(
          first([
            read('coilDimensions.hvradial'),
            read('hvFormulas.hvRadialThickness'),
          ]),
        ),
      ],
      [
        'Wire Length',
        _blankIfMissing(read('innerWindings.wireLength')),
        _blankIfMissing(read('hvFormulas.hvWireLength')),
      ],
      [
        'Resist. @ 750C',
        _blankIfMissing(read('innerWindings.r75')),
        _blankIfMissing(read('hvFormulas.hvR75')),
      ],
      [
        'Resist. @ 350C',
        _blankIfMissing(read('innerWindings.r26')),
        _blankIfMissing(read('hvFormulas.hvR26')),
      ],
      [
        'Wt – Bare/Ins.',
        _blankIfMissing(
          first([
            read('innerWindings.weightBareInsulated'),
            read('lvFormulas.lvProcurementWeight'),
          ]),
        ),
        _blankIfMissing(
          first([
            read('outerWindings.weightBareInsulated'),
            read('hvFormulas.hvInsulatedWeight'),
            read('hvFormulas.hvProcurementWeight'),
          ]),
        ),
      ],
      [
        'Stray Loss',
        _blankIfMissing(read('innerWindings.eddyStrayLoss')),
        _blankIfMissing(read('hvFormulas.hvStrayLoss')),
      ],
      [
        'Load Loss',
        _blankIfMissing(read('innerWindings.loadLoss')),
        _blankIfMissing(
          first([
            read('outerWindings.loadLoss'),
            read('hvFormulas.hvLoadLossAtNormal'),
          ]),
        ),
      ],
      [
        'Gradient',
        _blankIfMissing(read('innerWindings.tempGradDegC')),
        _blankIfMissing(
          first([
            read('outerWindings.tempGradDegC'),
            read('hvFormulas.hvGradient'),
          ]),
        ),
      ],
      [
        'Transpose',
        _blankIfMissing(read('lvFormulas.lvTransposition')),
        _blankIfMissing(read('hvFormulas.hvTransposition')),
      ],
      [
        'Wdg Length',
        _blankIfMissing(read('innerWindings.windingLength')),
        _blankIfMissing(
          first([
            read('outerWindings.windingLength'),
            read('hvFormulas.hvWindingLength'),
          ]),
        ),
      ],
      [
        'End Clearance',
        _blankIfMissing(read('innerWindings.endClearances')),
        _blankIfMissing(
          first([
            read('outerWindings.endClearances'),
            read('hvFormulas.hvEndClearance'),
          ]),
        ),
      ],
      [
        'Window Ht. ',
        _blankIfMissing(read('core.limbHt')),
        _blankIfMissing(read('core.limbHt')),
      ],
      [
        'Ampere Turns',
        _ampereTurnsLabel(design, 'innerWindings'),
        _ampereTurnsLabel(design, 'outerWindings'),
      ],
      [
        'Terminals',
        _blankIfMissing(read('innerWindings.terminal')),
        _blankIfMissing(read('outerWindings.terminal')),
      ],
    ];
  }

  pw.Widget _generalPerformanceBlock(FilesState state) {
    final design = state.twoWindingDesign;
    return _designTable(
      [
        [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _templateText('Generals'),
              _designTable(
                [
                  [
                    _templateLines([
                      'Weights',
                      'Core & Wdg: ${_designValue(design, ['tankAndOilFormulas.weightsOfActivePart', 'coreAndWindingWeight'])}',
                      'Tank & Fitting: ${_blankIfMissing(design?.readPath('tankAndOilFormulas.weightOfTankAndAcc'))}',
                      'Oil: ${_designValue(design, ['tankAndOilFormulas.oilWeight', 'tankAndOilFormulas.totalOil'])}',
                      'Total: ${_designValue(design, ['tankAndOilFormulas.transformerWeight', 'tankAndOilFormulas.totalWeight', 'totalWeight'])}',
                      'Over-all Dimensions: ${_blankIfMissing(design?.readPath('tankAndOilFormulas.overallDimension'))}',
                    ], fontSize: 8),
                    _templateLines([
                      'Cost (Total: ${_blankIfMissing(design?.readPath('cost.capitalCost'))})',
                      'Oil: ${_blankIfMissing(design?.readPath('cost.totalOilCost'))}',
                      'Cond: ${_blankIfMissing(design?.readPath('cost.totalCondCost'))}',
                      'Core: ${_blankIfMissing(design?.readPath('cost.totalCoreCost'))}',
                      'Insulation: ${_blankIfMissing(design?.readPath('cost.totalInsCost'))}',
                      'Steel: ${_blankIfMissing(design?.readPath('cost.totalSteelCost'))}',
                      'Radiators: ${_blankIfMissing(design?.readPath('cost.totalRadiatorCost'))}',
                    ], fontSize: 8),
                  ],
                ],
                const <double>[2584, 2585],
                tableWidth: 258,
                fontSize: 8,
                horizontalPadding: 2,
                verticalPadding: 0.8,
              ),
            ],
          ),
          _templateLines([
            'Performance',
            ..._performanceRows(state).map((field) {
              return '${field.label} ${_blankIfMissing(field.value)}';
            }),
          ], fontSize: 8.2),
        ],
      ],
      const <double>[5395, 5395],
      fontSize: 8.2,
      horizontalPadding: 2,
      verticalPadding: 1,
    );
  }

  List<List<Object>> _tappingRowsForDesignPrint(FilesState state) {
    final design = state.twoWindingDesign;
    return [
      ['Taps: ', _tapSummary(design)],
      [
        'Turns:',
        '${_blankIfMissing(_turnsPerTapValue(design))} - HV Tapping turns.',
      ],
    ];
  }

  pw.Widget _designTable(
    List<List<Object>> rows,
    List<double> twipWidths, {
    double tableWidth = _designPrintContentWidth,
    double fontSize = 8.5,
    double horizontalPadding = 3,
    double verticalPadding = 1,
  }) {
    final total = twipWidths.fold<double>(0, (sum, width) => sum + width);
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: <int, pw.TableColumnWidth>{
        for (var index = 0; index < twipWidths.length; index++)
          index: pw.FixedColumnWidth(tableWidth * twipWidths[index] / total),
      },
      children: rows
          .map((row) {
            return pw.TableRow(
              children: row
                  .map((cell) {
                    return pw.Container(
                      padding: pw.EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: verticalPadding,
                      ),
                      alignment: pw.Alignment.topLeft,
                      child: cell is pw.Widget
                          ? cell
                          : _templateText(cell.toString(), fontSize: fontSize),
                    );
                  })
                  .toList(growable: false),
            );
          })
          .toList(growable: false),
    );
  }

  pw.Widget _templateLines(List<String> lines, {double fontSize = 8.5}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: lines
          .map((line) {
            return _templateText(line, fontSize: fontSize);
          })
          .toList(growable: false),
    );
  }

  pw.Widget _templateText(String text, {double fontSize = 8.5}) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: fontSize, lineSpacing: 0.5),
      maxLines: 3,
      softWrap: true,
    );
  }

  pw.Widget _gap({double height = 2}) => pw.SizedBox(height: height);

  List<pw.Widget> _buildGtp(FilesState state) {
    final twoWinding = state.twoWindingDesign;
    return [
      _section(
        'Electrical Snapshot',
        _keyValueRows(<List<String>>[
          ['Capacity (kVA)', _display(twoWinding?.readPath('kVA'))],
          ['HV Voltage', _display(twoWinding?.readPath('highVoltage'))],
          ['LV Voltage', _display(twoWinding?.readPath('lowVoltage'))],
          ['Vector Group', twoWinding?.stringAt('vectorGroup') ?? '-'],
          ['Frequency', _display(twoWinding?.readPath('frequency'))],
          ['Core Loss', _display(twoWinding?.readPath('coreLoss'))],
          ['Load Loss', _display(twoWinding?.readPath('loadLoss'))],
          [
            'Total Oil',
            _display(twoWinding?.readPath('tankAndOilFormulas.totalOil')),
          ],
          [
            'Tank + Accessories Weight',
            _display(
              twoWinding?.readPath('tankAndOilFormulas.weightOfTankAndAcc'),
            ),
          ],
        ]),
      ),
      pw.SizedBox(height: 12),
      _section(
        'Customer',
        _keyValueRows(<List<String>>[
          [
            'Customer Name',
            state.customerName.trim().isEmpty ? '-' : state.customerName.trim(),
          ],
          [
            'Customer Place',
            state.customerPlace.trim().isEmpty
                ? '-'
                : state.customerPlace.trim(),
          ],
        ]),
      ),
    ];
  }

  List<pw.Widget> _buildCoreAssembly(FilesState state) {
    return [_coreAssemblyPrintout(state)];
  }

  List<pw.Widget> _buildCoreBlade(FilesState state) {
    return [_coreBladePrintout(state)];
  }

  pw.Widget _coreAssemblyPrintout(
    FilesState state, [
    _CorePrintImages? images,
  ]) {
    final isFourBlade = _isFourBladeCore(state.coreResult);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: _printText(
            'Design Ref : ${_designReference(state)}',
            bold: true,
          ),
        ),
        pw.SizedBox(height: 28),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 82, right: 82),
          child: _coreAssemblyHeaderTable(state),
        ),
        pw.SizedBox(height: 54),
        pw.Center(
          child: images == null
              ? _printText(_assemblyAscii())
              : pw.Image(
                  isFourBlade ? images.assembly4Blade : images.assembly3Blade,
                  width: isFourBlade ? 190 : 245,
                  height: isFourBlade ? 200 : 138,
                  fit: pw.BoxFit.contain,
                ),
        ),
        pw.SizedBox(height: isFourBlade ? 28 : 42),
        _assemblyStackTable(state),
        pw.SizedBox(height: 32),
        _assemblySummaryTable(state),
      ],
    );
  }

  pw.Widget _coreBladePrintout(FilesState state, [_CorePrintImages? images]) {
    return pw.Stack(
      children: [
        pw.Positioned(
          top: 0,
          right: 0,
          child: _printText(
            'Design Ref : ${_designReference(state)}',
            bold: true,
          ),
        ),
        pw.Positioned(
          top: 44,
          left: 170,
          child: _printText(_coreHeaderBlock(state, compactKva: true)),
        ),
        pw.Positioned(
          top: 130,
          left: 0,
          right: 0,
          child: images == null
              ? pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _printText(_bladeSketchAscii()),
                    pw.SizedBox(width: 16),
                    pw.Expanded(child: _printText(_bladeTableBlock(state))),
                  ],
                )
              : pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _coreBladeDiagramColumn(state, images),
                    pw.SizedBox(width: 16),
                    pw.Expanded(child: _printText(_bladeTableBlock(state))),
                  ],
                ),
        ),
        pw.Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _printText(_bladeNotesBlock(state)),
        ),
      ],
    );
  }

  pw.Widget _coreBladeDiagramColumn(FilesState state, _CorePrintImages images) {
    final isFourBlade = _isFourBladeCore(state.coreResult);
    final diagramImages = isFourBlade
        ? images.blade4Images
        : images.blade3Images;
    final imageWidth = isFourBlade ? 128.0 : 136.0;
    final imageHeight = isFourBlade ? 46.0 : 68.0;
    final gap = isFourBlade ? 12.0 : 18.0;

    return pw.SizedBox(
      width: 150,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          for (var index = 0; index < diagramImages.length; index += 1) ...[
            pw.Image(
              diagramImages[index],
              width: imageWidth,
              height: imageHeight,
              fit: pw.BoxFit.contain,
            ),
            if (index != diagramImages.length - 1) pw.SizedBox(height: gap),
          ],
        ],
      ),
    );
  }

  pw.Widget _coreAssemblyHeaderTable(FilesState state) {
    final secondary = _filesDesignValue(
      state,
      ['highVoltage', 'secondaryVoltage'],
      ['secondaryVoltage', 'highVoltage'],
    );
    final primary = _filesDesignValue(
      state,
      ['lowVoltage', 'primaryVoltage'],
      ['primaryVoltage', 'lowVoltage'],
    );
    final frequency = _filesDesignValue(state, ['frequency'], ['frequency']);
    final kva = _filesDesignValue(state, ['kVA'], ['kVA']);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Center(
          child: _printText(
            'CORE Details for Transformer',
            bold: true,
            fontSize: 11,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black, width: 0.45),
          columnWidths: const <int, pw.TableColumnWidth>{
            0: pw.FlexColumnWidth(1.2),
            1: pw.FlexColumnWidth(2.4),
          },
          children: [
            _printoutRow([
              'Transformer',
              '${_dashIfEmpty(secondary)} / ${_dashIfEmpty(primary)} V, Hz:${_dashIfEmpty(frequency)}, ${_dashIfEmpty(kva)} kVA',
            ]),
            _printoutRow(['CORE Size', _coreSizeLabel(state)]),
            _printoutRow(['Blade', _bladeLabel(state.coreResult)]),
          ],
        ),
      ],
    );
  }

  pw.Widget _assemblyStackTable(FilesState state) {
    final steps = state.coreResult?.bldStacks ?? const <CoreStackStep>[];
    if (steps.isEmpty) {
      return _printText('No core stack data available.');
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.45),
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(1.8),
        for (var index = 0; index < steps.length; index += 1)
          index + 1: const pw.FlexColumnWidth(),
      },
      children: [
        _printoutRow([
          'Stack Step No',
          ...steps.map((step) => _compactNumber(step.stepNo)),
        ], isHeader: true),
        _printoutRow([
          'Width (mm)',
          ...steps.map((step) => _compactNumber(step.width)),
        ]),
        _printoutRow([
          'Step Ht (mm)',
          ...steps.map((step) => _compactNumber(step.stack)),
        ]),
      ],
    );
  }

  pw.Widget _assemblySummaryTable(FilesState state) {
    final core = state.coreResult;
    final fluxDensity = _filesDesignValue(
      state,
      ['lvFormulas.revisedFluxDensity', 'fluxDensity'],
      ['revisedFluxDensity', 'fluxDensity'],
    );
    final voltsPerTurn = _filesDesignValue(
      state,
      ['lvFormulas.revisedVoltsPerTurn', 'revisedVoltsPerTurn'],
      ['performance.voltsPerTurn', 'revisedVoltsPerTurn'],
    );
    final noLoadCurrent = _filesDesignValue(
      state,
      ['performance.nlCurrentPercentage', 'commonFormulas.noLoadCurrent'],
      ['performance.nlCurrentPercentage'],
    );
    final noLoadLoss = _filesDesignValue(
      state,
      ['performance.noLoadLoss', 'coreLoss'],
      ['performance.noLoadLoss', 'coreLoss'],
    );

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.45),
      columnWidths: const <int, pw.TableColumnWidth>{
        0: pw.FlexColumnWidth(2.4),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(2.4),
        3: pw.FlexColumnWidth(1.3),
      },
      children: [
        _printoutRow([
          'Parameter',
          'Value',
          'Parameter',
          'Value',
        ], isHeader: true),
        _printoutRow([
          'TOTAL CROSS-SECTION (sqcm)',
          _display(core?.coreArea),
          'EFFECTIVE CROSS-SECTION(sqcm)',
          _display(core?.designedCoreArea),
        ]),
        _printoutRow([
          'HIGHEST V/F CONDITION %',
          _dashIfEmpty(fluxDensity),
          'NORMAL FLUX DENSITY',
          _gaussLabel(fluxDensity),
        ]),
        _printoutRow([
          'HIGHEST FLUX DENSITY Under V/F Condn.',
          _gaussLabel(fluxDensity),
          'SATURATION LEVEL FOR THE CORE MATERIAL',
          '20,500 gauss',
        ]),
        _printoutRow([
          'VOLTS per TURN',
          _dashIfEmpty(voltsPerTurn),
          'Weight Of CORE',
          '${_display(core?.coreWeight)} kg',
        ]),
        _printoutRow([
          'NO-LOAD Current',
          '${_dashIfEmpty(noLoadCurrent)} Amps',
          'NO-LOAD Loss',
          '${_dashIfEmpty(noLoadLoss)} kW',
        ]),
      ],
    );
  }

  pw.TableRow _printoutRow(List<String> cells, {bool isHeader = false}) {
    return pw.TableRow(
      decoration: isHeader
          ? const pw.BoxDecoration(color: PdfColors.grey300)
          : null,
      children: cells
          .map((cell) => _printoutCell(cell, isHeader: isHeader))
          .toList(growable: false),
    );
  }

  pw.Widget _printoutCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _printText(String text, {bool bold = false, double fontSize = 10}) {
    return pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: fontSize,
        fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
      softWrap: false,
    );
  }

  String _coreHeaderBlock(FilesState state, {bool compactKva = false}) {
    final secondary = _filesDesignValue(
      state,
      ['highVoltage', 'secondaryVoltage'],
      ['secondaryVoltage', 'highVoltage'],
    );
    final primary = _filesDesignValue(
      state,
      ['lowVoltage', 'primaryVoltage'],
      ['primaryVoltage', 'lowVoltage'],
    );
    final frequency = _filesDesignValue(state, ['frequency'], ['frequency']);
    final kva = _filesDesignValue(state, ['kVA'], ['kVA']);
    final kvaLabel = compactKva
        ? '${_dashIfEmpty(kva)}kVA'
        : '${_dashIfEmpty(kva)} kVA';
    return <String>[
      'CORE Details for Transformer',
      '${_dashIfEmpty(secondary)} / ${_dashIfEmpty(primary)} V, Hz:${_dashIfEmpty(frequency)},    $kvaLabel',
      'CORE Size : ${_coreSizeLabel(state)} , ${_bladeLabel(state.coreResult)}',
    ].join('\n');
  }

  String _coreSizeLabel(FilesState state) {
    final values = <String>[
      _filesDesignValue(state, ['core.coreDia'], ['core.coreDia']),
      _filesDesignValue(state, ['core.limbHt'], ['core.limbHt']),
      _filesDesignValue(
        state,
        ['core.cenDist'],
        ['core.cenDist', 'coilDimensions.centerDistance'],
      ),
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    return values.isEmpty ? '-' : values.join(' / ');
  }

  String _filesDesignValue(
    FilesState state,
    List<String> twoPaths,
    List<String> multiPaths, {
    Object? fallback,
  }) {
    return _blankIfMissing(
      _readDesign(
        state.twoWindingDesign,
        twoPaths,
        fallback: _readMulti(
          state.multiWindingDesign,
          multiPaths,
          fallback: fallback,
        ),
      ),
    );
  }

  String _assemblyAscii() {
    return r'''
       B
  +---------------+
 /|     | |     |\ 
C |     |A|     | C
 \|_____|_|_____|
       B''';
  }

  String _bladeSketchAscii() {
    return r'''
 W
   ______
  /      |----
B |      |   A
  |______|
     \ OFFSET 10mm

     A
  ___________   W
 /____/\_____\
 Notch, W/2 depth

     B
  ___________   W
 /___________\
     A''';
  }

  String _bladeTableBlock(FilesState state) {
    final core = state.coreResult;
    final rows = _bladeSections(core);
    final isCrusi3 = core?.bladeType == 'CRUSI_3';
    final buffer = StringBuffer()
      ..writeln(
        isCrusi3
            ? 'Step    Len A    Len B    Width    Stack    Weight   ${_holeText(core)}'
            : 'Step    Length   Width    Stack    Weight   ${_holeText(core)}',
      )
      ..writeln(
        isCrusi3
            ? ' No.      mm        mm       mm       mm       kg     ${_centerText(state)}'
            : ' No.      mm       mm       mm       kg     ${_centerText(state)}',
      )
      ..writeln('${'-' * 52}From One End(See Below)');

    var total = 0.0;
    for (final section in rows) {
      for (final row in section.rows) {
        buffer.writeln(_bladeRow(row, isCrusi3: isCrusi3));
      }
      total += section.totalWeight;
      buffer.writeln(
        '${'-' * 52}Group Total=${section.totalWeight.toStringAsFixed(2)}',
      );
    }
    final totalLabel = total == 0
        ? _display(core?.coreWeight)
        : total.toStringAsFixed(2);
    buffer.writeln('                 Total Weight:   $totalLabel kg');
    return buffer.toString().trimRight();
  }

  String _bladeNotesBlock(FilesState state) {
    final core = state.coreResult;
    final material = _filesDesignValue(
      state,
      ['core.coreMaterial', 'coreMaterial'],
      ['core.coreMaterial'],
    );
    return <String>[
      '1. All dimensions are in mm.  2. All cutting angles are at 45 deg.',
      '3. Deburring And/Or Annealing required. 5. The weights are Approx.',
      '4. NET C/S(sq cm):${_display(core?.designedCoreArea)}    Material : ${_dashIfEmpty(material)}',
      '5. Gross C/s = ${_display(core?.coreArea)}  Area = ${_filesDesignValue(state, ['core.coreDia'], ['core.coreDia'])}  Stack factor =  0.97',
    ].join('\n');
  }

  List<_CoreBladeSection> _bladeSections(CoreCalculationResult? core) {
    if (core == null) {
      return const <_CoreBladeSection>[];
    }
    final isFourBlade =
        core.bladeType == 'CRUSI_4' || core.bladeType == 'BLADE_4';
    final isThreeBlade =
        core.bladeType == 'CRUSI_3' || core.bladeType == 'BLADE_3';
    final weightIndex = core.bladeType == 'CRUSI_3' ? 5 : 4;
    final paths = <String>[
      'centerLimbStacking',
      isThreeBlade ? 'yokeStacking' : 'sideLimbStacking',
      isThreeBlade ? 'sideLimbStacking' : 'doubleNotchStacking',
      if (isFourBlade) 'singleNotchStacking',
    ];
    final sections = paths
        .map((path) {
          final rows = core
              .tableAt(path)
              .where(_hasVisibleCell)
              .toList(growable: false);
          return _CoreBladeSection(
            rows: rows,
            totalWeight: _tableWeight(rows, weightIndex),
          );
        })
        .where((section) => section.rows.isNotEmpty)
        .toList(growable: false);
    if (sections.isNotEmpty) {
      return sections;
    }
    final fallbackRows = core.bldStacks
        .map(
          (step) => <Object?>[step.stepNo, '', '', step.width, step.stack, ''],
        )
        .toList(growable: false);
    return <_CoreBladeSection>[
      _CoreBladeSection(rows: fallbackRows, totalWeight: 0),
    ];
  }

  bool _hasVisibleCell(List<Object?> row) {
    return row.any((cell) => _valueText(cell).trim().isNotEmpty);
  }

  double _tableWeight(List<List<Object?>> rows, int weightIndex) {
    return rows.fold<double>(0, (sum, row) {
      if (weightIndex >= row.length) {
        return sum;
      }
      return sum + (double.tryParse(_valueText(row[weightIndex])) ?? 0);
    });
  }

  String _bladeRow(List<Object?> row, {required bool isCrusi3}) {
    final width = isCrusi3 ? 6 : 5;
    final cells = List<Object?>.generate(
      width,
      (index) => index < row.length ? row[index] : '',
    ).map(_compactNumber).toList();
    if (isCrusi3) {
      return '${cells[0].padLeft(4)}'
          '${cells[1].padLeft(10)}'
          '${cells[2].padLeft(10)}'
          '${cells[3].padLeft(9)}'
          '${cells[4].padLeft(9)}'
          '${cells[5].padLeft(10)}';
    }
    return '${cells[0].padLeft(4)}'
        '${cells[1].padLeft(10)}'
        '${cells[2].padLeft(9)}'
        '${cells[3].padLeft(9)}'
        '${cells[4].padLeft(10)}';
  }

  String _holeText(CoreCalculationResult? core) {
    final isFourBlade = _isFourBladeCore(core);
    return '2HolesDia = ${isFourBlade ? '18' : '22'} mm';
  }

  String _centerText(FilesState state) {
    final center = _filesDesignValue(
      state,
      ['core.cenDist'],
      ['core.cenDist', 'coilDimensions.centerDistance'],
    );
    if (center.isEmpty) {
      return '';
    }
    final secondary = (double.tryParse(center) ?? 0) + 20;
    return 'CenDist:${center.padRight(4)},${_compactNumber(secondary)}';
  }

  String _bladeLabel(CoreCalculationResult? core) {
    return _isFourBladeCore(core) ? '4Cruci' : '3Cruci';
  }

  bool _isFourBladeCore(CoreCalculationResult? core) {
    final type = core?.bladeType ?? 'CRUSI_3';
    return type == 'CRUSI_4' || type == 'BLADE_4';
  }

  String _compactNumber(Object? value) {
    final text = _valueText(value);
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return text;
    }
    if (parsed == parsed.roundToDouble()) {
      return parsed.round().toString();
    }
    return parsed
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  }

  String _dashIfEmpty(String value) => value.trim().isEmpty ? '-' : value;

  String _gaussLabel(String value) {
    final parsed = double.tryParse(value);
    if (parsed == null || parsed == 0) {
      return '';
    }
    return '${(parsed * 10000).round()} gauss';
  }

  List<pw.Widget> _buildLom(FilesState state) {
    final rows = state.displayRows;
    return [
      _section(
        'LOM Totals',
        _keyValueRows(<List<String>>[
          ['Material Rows', '${rows.length}'],
          ['Total Cost', _numberLabel(state.totalCost)],
        ]),
      ),
      pw.SizedBox(height: 12),
      _section(
        'Line Items',
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          cellAlignment: pw.Alignment.centerLeft,
          headers: const <String>[
            'Description',
            'Specification',
            'Unit',
            'Qty',
            'Rate',
            'Cost',
          ],
          data: rows
              .map(
                (row) => <String>[
                  row.description,
                  row.specification,
                  row.unit,
                  _numberLabel(row.quantity),
                  _numberLabel(row.rate),
                  _numberLabel(row.cost),
                ],
              )
              .toList(growable: false),
        ),
      ),
    ];
  }

  pw.Widget _section(String title, pw.Widget child) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        child,
      ],
    );
  }

  pw.Widget _keyValueRows(List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headerCount: 0,
      cellAlignment: pw.Alignment.centerLeft,
      cellStyle: const pw.TextStyle(fontSize: 10),
      data: rows,
      columnWidths: <int, pw.TableColumnWidth>{
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
    );
  }

  String _designReference(FilesState state) {
    final value = state.designId.trim();
    if (value.isNotEmpty) {
      return value;
    }
    return state.entityId.trim();
  }

  String _safeFileSegment(String value) {
    final normalized = value.trim().isEmpty ? 'design' : value.trim();
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _display(Object? value) {
    final label = _valueText(value);
    return label.isEmpty ? '-' : label;
  }

  String _blankIfMissing(Object? value) {
    return _valueText(value);
  }

  String _numberLabel(num value) {
    final isWhole = value == value.roundToDouble();
    return isWhole ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  Object? _firstAvailable(List<Object?> values) {
    for (final value in values) {
      final label = _valueText(value);
      if (label.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  Object? _readDesign(
    TwoWindingDesign? design,
    List<String> paths, {
    Object? fallback,
  }) {
    if (design == null) {
      return fallback;
    }
    return _firstAvailable([
          for (final path in paths) design.readPath(path),
          fallback,
        ]) ??
        fallback;
  }

  String _designValue(
    TwoWindingDesign? design,
    List<String> paths, {
    Object? fallback,
  }) {
    return _blankIfMissing(_readDesign(design, paths, fallback: fallback));
  }

  Object? _readMulti(
    MultiWindingDesign? design,
    List<String> paths, {
    Object? fallback,
  }) {
    if (design == null) {
      return fallback;
    }
    return _firstAvailable([
          for (final path in paths) design.readPath(path),
          fallback,
        ]) ??
        fallback;
  }

  String _multiValue(
    MultiWindingDesign? design,
    List<String> paths, {
    Object? fallback,
  }) {
    return _blankIfMissing(_readMulti(design, paths, fallback: fallback));
  }

  String _multiWindingVoltage(MultiWindingDesign design, String id) {
    return _blankIfMissing(
      _readMulti(design, [
        _multiSpec(id).voltagePath,
        'part2Windings.$id.voltage',
      ]),
    );
  }

  String _multiWindingType(MultiWindingDesign design, String id) {
    return _blankIfMissing(design.readPath(_multiSpec(id).typePath));
  }

  String _multiWindingValue(
    MultiWindingDesign design,
    String id,
    String field,
  ) {
    return _blankIfMissing(design.readPath('part2Windings.$id.$field'));
  }

  String _multiConductorLabel(MultiWindingDesign design, String id) {
    final saved = _multiWindingValue(design, id, 'conductorSizes');
    if (saved.isNotEmpty) {
      return saved;
    }
    final isRound = _isTruthy(
      design.readPath('part2Windings.$id.isConductorRound'),
    );
    if (isRound) {
      return _multiWindingValue(design, id, 'conductorDiameter');
    }
    final breadth = _multiWindingValue(design, id, 'condBreadth');
    final height = _multiWindingValue(design, id, 'condHeight');
    if (breadth.isEmpty && height.isEmpty) {
      return '';
    }
    return '$breadth x $height'.trim();
  }

  String _multiParallelLabel(MultiWindingDesign design, String id) {
    final saved = _multiWindingValue(design, id, 'noInParallel');
    if (saved.isNotEmpty) {
      return saved;
    }
    final radial = _multiWindingValue(design, id, 'radialParallelCond');
    final axial = _multiWindingValue(design, id, 'axialParallelCond');
    return [radial, axial].where((value) => value.isNotEmpty).join(' x ');
  }

  String _multiDuctLabel(MultiWindingDesign design, String id) {
    final ducts = _multiWindingValue(design, id, 'ducts');
    final ductSize = _multiWindingValue(design, id, 'ductSize');
    if (ducts.isEmpty && ductSize.isEmpty) {
      return _multiWindingValue(design, id, 'noOfDuctsWidth');
    }
    if (ducts.isEmpty) return ductSize;
    if (ductSize.isEmpty) return ducts;
    return '$ducts / $ductSize';
  }

  String _multiRadialValue(MultiWindingDesign design, String id) {
    final spec = _multiSpec(id);
    return _blankIfMissing(design.readPath(spec.dimensionPath('radial')));
  }

  String _multiAmpereTurnsLabel(MultiWindingDesign design, String id) {
    final existing = _multiWindingValue(design, id, 'ampereTurns');
    if (existing.isNotEmpty) {
      return existing;
    }
    final turns = _toDouble(design.readPath('part2Windings.$id.turnsPerPhase'));
    final current = _toDouble(
      design.readPath('part2Windings.$id.phaseCurrent'),
    );
    if (turns == null || current == null) {
      return '';
    }
    return _numberLabel(turns * current);
  }

  String _multiTapSummary(MultiWindingDesign design) {
    final positive = _display(design.readPath('tapStepsPositive'));
    final negative = _display(design.readPath('tapStepsNegative'));
    final percent = _display(design.readPath('tapStepsPercent'));
    final parts = <String>[
      if (positive != '-' || negative != '-') '+$positive to -$negative',
      if (percent != '-') '@ $percent%',
      if (_isTruthy(design.readPath('isOLTC'))) 'OLTC' else 'OCTC',
    ];
    return parts.join(', ');
  }

  _MultiPrintWindingSpec _multiSpec(String id) {
    return _multiPrintWindingSpecs.firstWhere(
      (spec) => spec.id == id,
      orElse: () => _multiPrintWindingSpecs.first,
    );
  }

  String _conductorLabel(TwoWindingDesign? design, String prefix) {
    final saved = _readDesign(design, ['$prefix.conductorSizes']);
    if (_valueText(saved).isNotEmpty) {
      return _valueText(saved);
    }

    final isRound = design?.boolAt('$prefix.isConductorRound') ?? false;
    if (isRound) {
      return _blankIfMissing(design?.readPath('$prefix.conductorDiameter'));
    }

    final breadth = _blankIfMissing(
      _readDesign(design, [
        '$prefix.condBreadth',
        if (prefix == 'outerWindings') 'hvFormulas.hvBreadth',
      ]),
    );
    final height = _blankIfMissing(
      _readDesign(design, [
        '$prefix.condHeight',
        if (prefix == 'outerWindings') 'hvFormulas.hvHeight',
      ]),
    );

    if (breadth.isEmpty && height.isEmpty) {
      return '';
    }
    return '$breadth x $height'.trim();
  }

  String _parallelLabel(TwoWindingDesign? design, String prefix) {
    final radial = _blankIfMissing(
      _readDesign(design, [
        '$prefix.radialParallelCond',
        if (prefix == 'outerWindings') 'hvFormulas.hvRadialParallelConductors',
      ]),
    );
    final axial = _blankIfMissing(
      _readDesign(design, [
        '$prefix.axialParallelCond',
        if (prefix == 'outerWindings') 'hvFormulas.hvAxialParallelConductors',
      ]),
    );
    final combined = [
      radial,
      axial,
    ].where((value) => value.isNotEmpty).join(' x ');
    if (combined.isNotEmpty) {
      return combined;
    }
    return _blankIfMissing(design?.readPath('$prefix.noInParallel'));
  }

  String _ductLabel(TwoWindingDesign? design, String prefix) {
    final ducts = _blankIfMissing(design?.readPath('$prefix.ducts'));
    final ductSize = _blankIfMissing(design?.readPath('$prefix.ductSize'));
    if (ducts.isEmpty && ductSize.isEmpty) {
      return _blankIfMissing(
        _readDesign(design, [
          '$prefix.noOfDuctsWidth',
          if (prefix == 'outerWindings') 'hvFormulas.hvNoOfDuct',
        ]),
      );
    }
    if (ducts.isEmpty) {
      return ductSize;
    }
    if (ductSize.isEmpty) {
      return ducts;
    }
    return '$ducts / $ductSize';
  }

  String _ampereTurnsLabel(TwoWindingDesign? design, String prefix) {
    final existing = _blankIfMissing(design?.readPath('$prefix.ampereTurns'));
    if (existing.isNotEmpty) {
      return existing;
    }

    final turns = _toDouble(design?.readPath('$prefix.turnsPerPhase'));
    final current = _toDouble(design?.readPath('$prefix.phaseCurrent'));
    if (turns == null || current == null) {
      return '';
    }
    return _numberLabel(turns * current);
  }

  Object? _turnsPerTapValue(TwoWindingDesign? design) {
    return _readDesign(design, [
      'turnsPerTap',
      'hvFormulas.hvTurnsPerTap',
      'hvFormulas.turnsPerTap',
    ]);
  }

  double? _toDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(_valueText(value));
  }

  bool _isTruthy(Object? value) {
    return switch (value) {
      true => true,
      false || null => false,
      String() => value.trim().isNotEmpty && value.toLowerCase() != 'false',
      num() => value != 0,
      _ => true,
    };
  }

  String _valueText(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is Iterable) {
      return value
          .map(_valueText)
          .where((entry) => entry.isNotEmpty)
          .join(', ');
    }
    if (value is Map) {
      return '';
    }
    return value.toString().trim();
  }

  String _dateLabel() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${pad(now.day)}-${pad(now.month)}-${now.year}';
  }

  String _timestampLabel() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${pad(now.month)}-${pad(now.day)} '
        '${pad(now.hour)}:${pad(now.minute)}';
  }
}

class _DesignPrintField {
  const _DesignPrintField(this.label, this.value);

  final String label;
  final Object? value;
}

class _CoreBladeSection {
  const _CoreBladeSection({required this.rows, required this.totalWeight});

  final List<List<Object?>> rows;
  final double totalWeight;
}

class _CorePrintImages {
  const _CorePrintImages({
    required this.assembly3Blade,
    required this.assembly4Blade,
    required this.blade3Images,
    required this.blade4Images,
  });

  final pw.MemoryImage assembly3Blade;
  final pw.MemoryImage assembly4Blade;
  final List<pw.MemoryImage> blade3Images;
  final List<pw.MemoryImage> blade4Images;
}

class _MultiPrintWindingSpec {
  const _MultiPrintWindingSpec({
    required this.id,
    required this.voltagePath,
    required this.typePath,
    required this.currentDensityPath,
  });

  final String id;
  final String voltagePath;
  final String typePath;
  final String currentDensityPath;

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

const List<String> _multiWindingIds = <String>[
  'lv',
  'hvMain',
  'corse',
  'fine',
  'outer',
];

const List<_MultiPrintWindingSpec> _multiPrintWindingSpecs =
    <_MultiPrintWindingSpec>[
      _MultiPrintWindingSpec(
        id: 'lv',
        voltagePath: 'primaryVoltage',
        typePath: 'lvWindingType',
        currentDensityPath: 'lvCurrentDensity',
      ),
      _MultiPrintWindingSpec(
        id: 'hvMain',
        voltagePath: 'secondaryVoltage',
        typePath: 'hvWindingType',
        currentDensityPath: 'hvCurrentDensity',
      ),
      _MultiPrintWindingSpec(
        id: 'corse',
        voltagePath: 'corseVoltage',
        typePath: 'corseWindingType',
        currentDensityPath: 'corseCurrentDensity',
      ),
      _MultiPrintWindingSpec(
        id: 'fine',
        voltagePath: 'fineVoltage',
        typePath: 'fineWindingType',
        currentDensityPath: 'fineCurrentDensity',
      ),
      _MultiPrintWindingSpec(
        id: 'outer',
        voltagePath: 'outerVoltage',
        typePath: 'outerWindingType',
        currentDensityPath: 'outerCurrentDensity',
      ),
    ];

const double _designPrintContentWidth = 540;
const double _multiDesignPrintContentWidth = 720;
