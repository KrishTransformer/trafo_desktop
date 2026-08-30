import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';

import '../../design_workspace/domain/models/core_stack_step.dart';
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
  Future<void> openPdf({
    required String fileName,
    required Uint8List bytes,
  });

  Future<void> openUrl(Uri uri);
}

class UrlLauncherFilesDocumentOpener implements FilesDocumentOpener {
  @override
  Future<void> openPdf({
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
  FilesExportService({FilesDocumentOpener? opener})
    : _opener = opener ?? UrlLauncherFilesDocumentOpener();

  final FilesDocumentOpener _opener;

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
    final bytes = await _buildPdf(action: action, state: state);
    await _opener.openPdf(fileName: fileName, bytes: bytes);
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

    return Uri.parse(
      'https://transformer.treffertech.com/000_delivery/'
      '$designId/$designId$suffix',
    );
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
    return '${designId}_$suffix.pdf';
  }

  Future<Uint8List> _buildPdf({
    required FilesExportAction action,
    required FilesState state,
  }) async {
    final document = pw.Document();
    final title = action.label;

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

    return Uint8List.fromList(await document.save());
  }

  pw.Widget _buildHeader({
    required String title,
    required FilesState state,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text('Design Ref: ${_designReference(state)}'),
        if (state.customerName.trim().isNotEmpty)
          pw.Text('Customer: ${state.customerName.trim()}'),
        if (state.customerPlace.trim().isNotEmpty)
          pw.Text('Place: ${state.customerPlace.trim()}'),
        pw.Text('Generated: ${_timestampLabel()}'),
        pw.Divider(),
      ],
    );
  }

  List<pw.Widget> _buildDesignPrintOut(FilesState state) {
    final twoWinding = state.twoWindingDesign;
    final fabrication = state.fabricationResult;
    final core = state.coreResult;

    return [
      _section(
        'Design Summary',
        _keyValueRows(<List<String>>[
          ['Capacity (kVA)', _display(twoWinding?.readPath('kVA'))],
          ['HV Voltage', _display(twoWinding?.readPath('highVoltage'))],
          ['LV Voltage', _display(twoWinding?.readPath('lowVoltage'))],
          ['Vector Group', twoWinding?.stringAt('vectorGroup') ?? '-'],
          ['Frequency', _display(twoWinding?.readPath('frequency'))],
          ['Impedance', _display(twoWinding?.readPath('ez'))],
          ['Volts / Turn', _display(twoWinding?.readPath('voltsPerTurn'))],
        ]),
      ),
      pw.SizedBox(height: 12),
      _section(
        'Core Summary',
        _keyValueRows(<List<String>>[
          ['Core Weight', _display(twoWinding?.readPath('core.coreWeight'))],
          ['Core Area', _display(core?.coreArea)],
          ['Designed Core Area', _display(core?.designedCoreArea)],
          ['Core Diameter', _display(twoWinding?.readPath('core.coreDia'))],
          ['Limb Height', _display(twoWinding?.readPath('core.limbHt'))],
          ['Centre Distance', _display(twoWinding?.readPath('core.cenDist'))],
        ]),
      ),
      pw.SizedBox(height: 12),
      _section(
        'Fabrication Summary',
        _keyValueRows(<List<String>>[
          ['Tank Length', _display(fabrication?.readPath('tank.length'))],
          ['Tank Width', _display(fabrication?.readPath('tank.width'))],
          ['Tank Height', _display(fabrication?.readPath('tank.height'))],
          ['Pressure Relief Valve', _display(fabrication?.readPath('restOfVariables.prv'))],
          ['Rollers', _display(fabrication?.readPath('roller.roller'))],
          ['MOG', _display(fabrication?.readPath('mog.mog'))],
        ]),
      ),
      pw.SizedBox(height: 12),
      _section(
        'LOM Cost',
        _keyValueRows(<List<String>>[
          ['Rows', '${state.displayRows.length}'],
          ['Total Cost', _numberLabel(state.totalCost)],
        ]),
      ),
    ];
  }

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
          ['Total Oil', _display(twoWinding?.readPath('tankAndOilFormulas.totalOil'))],
          ['Tank + Accessories Weight', _display(twoWinding?.readPath('tankAndOilFormulas.weightOfTankAndAcc'))],
        ]),
      ),
      pw.SizedBox(height: 12),
      _section(
        'Customer',
        _keyValueRows(<List<String>>[
          ['Customer Name', state.customerName.trim().isEmpty ? '-' : state.customerName.trim()],
          ['Customer Place', state.customerPlace.trim().isEmpty ? '-' : state.customerPlace.trim()],
        ]),
      ),
    ];
  }

  List<pw.Widget> _buildCoreAssembly(FilesState state) {
    final core = state.coreResult;
    return [
      _section(
        'Core Metrics',
        _keyValueRows(<List<String>>[
          ['Core Area', _display(core?.coreArea)],
          ['Designed Core Area', _display(core?.designedCoreArea)],
          ['Core Weight', _display(core?.coreWeight)],
          ['Stack Rows', '${core?.bldStacks.length ?? 0}'],
        ]),
      ),
      pw.SizedBox(height: 12),
      _section('Stacking Table', _stackTable(core?.bldStacks ?? const <CoreStackStep>[])),
    ];
  }

  List<pw.Widget> _buildCoreBlade(FilesState state) {
    final core = state.coreResult;
    final twoWinding = state.twoWindingDesign;
    return [
      _section(
        'Blade Inputs',
        _keyValueRows(<List<String>>[
          ['Core Diameter', _display(twoWinding?.readPath('core.coreDia'))],
          ['Core Weight', _display(core?.coreWeight)],
          ['Gross Core Area', _display(core?.coreArea)],
          ['Designed Core Area', _display(core?.designedCoreArea)],
        ]),
      ),
      pw.SizedBox(height: 12),
      _section('Blade Stack Rows', _stackTable(core?.bldStacks ?? const <CoreStackStep>[])),
    ];
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

  pw.Widget _stackTable(List<CoreStackStep> steps) {
    if (steps.isEmpty) {
      return pw.Text('No core stack data available.');
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headers: const <String>['Step No', 'Width', 'Stack'],
      data: steps
          .map(
            (step) => <String>[
              _display(step.stepNo),
              _display(step.width),
              _display(step.stack),
            ],
          )
          .toList(growable: false),
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
    final label = value?.toString().trim() ?? '';
    return label.isEmpty ? '-' : label;
  }

  String _numberLabel(num value) {
    final isWhole = value == value.roundToDouble();
    return isWhole ? value.toInt().toString() : value.toStringAsFixed(2);
  }

  String _timestampLabel() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return '${now.year}-${pad(now.month)}-${pad(now.day)} '
        '${pad(now.hour)}:${pad(now.minute)}';
  }
}
