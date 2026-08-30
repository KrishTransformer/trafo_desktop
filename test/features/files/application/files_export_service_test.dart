import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/features/design_workspace/domain/models/core_calculation_result.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/two_winding_design.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/fabrication_calculation_result.dart';
import 'package:trafo_desktop/src/features/files/application/files_export_service.dart';
import 'package:trafo_desktop/src/features/files/application/files_state.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_line_item.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_entry.dart';

void main() {
  test('hosted actions use the documented delivery URLs', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(opener: opener);
    final state = _sampleState();

    await service.exportAction(
      action: FilesExportAction.tank,
      state: state,
    );

    expect(opener.openedUrls, <String>[
      'https://transformer.treffertech.com/000_delivery/'
          '100k-12345/100k-12345_Tank_GAD.pdf',
    ]);
    expect(opener.openedPdfs, isEmpty);
  });

  test('lom export generates a local pdf document', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(opener: opener);
    final state = _sampleState();

    await service.exportAction(
      action: FilesExportAction.lom,
      state: state,
    );

    expect(opener.openedUrls, isEmpty);
    expect(opener.openedPdfs, hasLength(1));
    expect(opener.openedPdfs.single.fileName, '100k-12345_lom.pdf');
    expect(opener.openedPdfs.single.bytes, isNotEmpty);
  });

  test('print all generates local docs and opens hosted drawings', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(opener: opener);
    final state = _sampleState();

    await service.exportAction(
      action: FilesExportAction.printAll,
      state: state,
    );

    expect(opener.openedPdfs, hasLength(5));
    expect(opener.openedUrls, hasLength(6));
    expect(
      opener.openedPdfs.map((entry) => entry.fileName),
      containsAll(<String>[
        '100k-12345_design_print_out.pdf',
        '100k-12345_gtp.pdf',
        '100k-12345_core_assembly.pdf',
        '100k-12345_core_blade.pdf',
        '100k-12345_lom.pdf',
      ]),
    );
    expect(
      opener.openedUrls,
      contains(
        'https://transformer.treffertech.com/000_delivery/'
        '100k-12345/100k-12345_Rating_plate.pdf',
      ),
    );
  });
}

FilesState _sampleState() {
  return FilesState.initial(routeId: 'entity-31').copyWith(
    isInitialized: true,
    entityId: 'entity-31',
    designId: '100k-12345',
    twoWindingDesign: TwoWindingDesign.fromJson(<String, dynamic>{
      'designId': '100k-12345',
      'kVA': 100,
      'highVoltage': 11000,
      'lowVoltage': 433,
      'vectorGroup': 'Dyn11',
      'frequency': 50,
      'ez': 4.5,
      'voltsPerTurn': 3.21,
      'coreLoss': 123,
      'loadLoss': 456,
      'core': <String, dynamic>{
        'coreWeight': 880,
        'coreDia': 210,
        'limbHt': 640,
        'cenDist': 420,
      },
      'tankAndOilFormulas': <String, dynamic>{
        'totalOil': 320,
        'weightOfTankAndAcc': 900,
      },
    }),
    coreResult: CoreCalculationResult.fromJson(<String, dynamic>{
      'coreArea': 2000,
      'designedCoreArea': 1800,
      'coreWeight': 880,
      'bldStacks': <Map<String, dynamic>>[
        <String, dynamic>{'stepNo': 1, 'width': 120, 'stack': 60},
        <String, dynamic>{'stepNo': 2, 'width': 110, 'stack': 55},
      ],
    }),
    fabricationResult: FabricationCalculationResult.fromJson(<String, dynamic>{
      'tank': <String, dynamic>{
        'length': 1500,
        'width': 900,
        'height': 1400,
      },
      'roller': <String, dynamic>{'roller': true},
      'mog': <String, dynamic>{'mog': true},
      'restOfVariables': <String, dynamic>{'prv': true},
    }),
    materials: <LomMaterialEntry>[
      LomMaterialEntry.fromJson(<String, dynamic>{
        'id': 'mat-1',
        'materialName': 'Lamination',
        'materialRate': 220,
      }),
    ],
    lomItems: <LomLineItem>[
      LomLineItem.fromJson(<String, dynamic>{
        'description': 'Lamination',
        'specification': 'CRGO',
        'unit': 'kg',
        'quantity': 125.5,
        'rate': 220,
        'cost': 27610,
      }),
      LomLineItem.fromJson(<String, dynamic>{
        'description': 'Copper',
        'specification': 'HV winding',
        'unit': 'kg',
        'quantity': 45,
        'rate': 780,
        'cost': 35100,
      }),
    ],
    customerName: 'Krish Transformers',
    customerPlace: 'Bangalore',
  );
}

class _RecordingOpener implements FilesDocumentOpener {
  final List<String> openedUrls = <String>[];
  final List<_OpenedPdf> openedPdfs = <_OpenedPdf>[];

  @override
  Future<void> openPdf({
    required String fileName,
    required Uint8List bytes,
  }) async {
    openedPdfs.add(_OpenedPdf(fileName: fileName, bytes: bytes));
  }

  @override
  Future<void> openUrl(Uri uri) async {
    openedUrls.add(uri.toString());
  }
}

class _OpenedPdf {
  const _OpenedPdf({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
