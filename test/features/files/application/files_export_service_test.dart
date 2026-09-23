import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/features/design_workspace/domain/models/core_calculation_result.dart';
import 'package:trafo_desktop/src/features/design_workspace/domain/models/two_winding_design.dart';
import 'package:trafo_desktop/src/features/fabrication/domain/models/fabrication_calculation_result.dart';
import 'package:trafo_desktop/src/features/files/application/files_export_service.dart';
import 'package:trafo_desktop/src/features/files/application/files_state.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_line_item.dart';
import 'package:trafo_desktop/src/features/files/domain/models/lom_material_entry.dart';
import 'package:trafo_desktop/src/features/multi_winding/domain/models/multi_winding_design.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hosted actions use the documented delivery URLs', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(opener: opener);
    final state = _sampleState();

    await service.exportAction(action: FilesExportAction.tank, state: state);

    expect(opener.openedUrls, <String>[
      'https://design.trafointel.com/000_delivery/'
          '100k-12345/100k-12345_Tank_GAD.pdf',
    ]);
    expect(opener.openedDocuments, isEmpty);
  });

  test('lom export generates a local pdf document', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(opener: opener);
    final state = _sampleState();

    await service.exportAction(action: FilesExportAction.lom, state: state);

    expect(opener.openedUrls, isEmpty);
    expect(opener.openedDocuments, hasLength(1));
    expect(opener.openedDocuments.single.fileName, '100k-12345_lom.pdf');
    expect(opener.openedDocuments.single.bytes, isNotEmpty);
  });

  test('design print out export generates a local pdf document', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(opener: opener);
    final state = _sampleState();

    await service.exportAction(
      action: FilesExportAction.designPrintOut,
      state: state,
    );

    expect(opener.openedUrls, isEmpty);
    expect(opener.openedDocuments, hasLength(1));
    final document = opener.openedDocuments.single;
    expect(document.fileName, '100k-12345_design_print_out.pdf');
    expect(String.fromCharCodes(document.bytes.take(4).toList()), '%PDF');
    expect(document.bytes, isNotEmpty);
  });

  test('multi winding design print out exports the MWdg pdf layout', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(opener: opener);
    final state = _multiWindingState();

    await service.exportAction(
      action: FilesExportAction.designPrintOut,
      state: state,
    );

    expect(opener.openedUrls, isEmpty);
    expect(opener.openedDocuments, hasLength(1));
    final document = opener.openedDocuments.single;
    expect(document.fileName, 'multi-12345_design_print_out.pdf');
    expect(String.fromCharCodes(document.bytes.take(4).toList()), '%PDF');
    expect(document.bytes, isNotEmpty);
  });

  test('print all generates local docs and opens hosted drawings', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(opener: opener);
    final state = _sampleState();

    await service.exportAction(
      action: FilesExportAction.printAll,
      state: state,
    );

    expect(opener.openedDocuments, hasLength(5));
    expect(opener.openedUrls, hasLength(6));
    expect(
      opener.openedDocuments.map((entry) => entry.fileName),
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
        'https://design.trafointel.com/000_delivery/'
        '100k-12345/100k-12345_Rating_plate.pdf',
      ),
    );
  });

  test('hosted delivery base URI can be overridden', () async {
    final opener = _RecordingOpener();
    final service = FilesExportService(
      opener: opener,
      deliveryBaseUri: Uri.parse('https://example.test/base/path?ignored=yes'),
    );
    final state = _sampleState();

    await service.exportAction(
      action: FilesExportAction.activePart,
      state: state,
    );

    expect(opener.openedUrls, <String>[
      'https://example.test/000_delivery/'
          '100k-12345/100k-12345_ActivePart_GAD.pdf',
    ]);
  });
}

FilesState _multiWindingState() {
  return FilesState.initial(routeId: 'entity-multi').copyWith(
    isInitialized: true,
    entityId: 'entity-multi',
    designId: 'multi-12345',
    multiWindingDesign: MultiWindingDesign.fromJson(<String, dynamic>{
      'designId': 'multi-12345',
      'windingConfiguration': '5_WDG_LV_HV_MAIN_CORSE_FINE_OUTER',
      'kVA': 500,
      'primaryVoltage': 433,
      'secondaryVoltage': 11000,
      'corseVoltage': 6600,
      'fineVoltage': 3300,
      'outerVoltage': 2200,
      'vectorGroup': 'Dyn11',
      'frequency': 50,
      'revisedVoltsPerTurn': 4.2,
      'revisedFluxDensity': 1.67,
      'windingTemp': 65,
      'tapStepsPercent': 2.5,
      'tapStepsPositive': 2,
      'tapStepsNegative': 2,
      'core': <String, dynamic>{
        'coreDia': 300,
        'coreWeight': 1250,
        'limbHt': 780,
        'area': 3100,
        'coreMaterial': 'NipM4',
        'coreType': 'PRIME',
      },
      'performance': <String, dynamic>{
        'noLoadLoss': 650,
        'loadLoss': 4200,
        'impedance': 5.8,
        'nlCurrentPercentage': 1.1,
        'voltsPerTurn': 4.2,
      },
      'tank': <String, dynamic>{
        'tankLength': 1900,
        'tankWidth': 1200,
        'tankHeight': 1850,
        'tankWallThickness': 8,
        'tankBottomThickness': 10,
        'tankLidThickness': 6,
        'frameThickness': 12,
        'tankLoss': 120,
        'wdgToTankGap': 90,
        'connectionGap': 130,
        'topYokeToCoverGap': 100,
        'overallDimension': '2100 x 1400 x 2200',
      },
      'coilDimensions': <String, dynamic>{
        'coreDia': 300,
        'coreGap': 12,
        'lvid': 340,
        'lvradial': 35,
        'lvod': 410,
        'lvhvgap': 25,
        'hvid': 460,
        'hvradial': 42,
        'hvod': 544,
        'hvhvgap': 30,
      },
      'multiCoilDimensions': <String, dynamic>{
        'corse': <String, dynamic>{'id': 590, 'radial': 36, 'od': 662},
        'fine': <String, dynamic>{'id': 710, 'radial': 28, 'od': 766},
        'outer': <String, dynamic>{'id': 820, 'radial': 30, 'od': 880},
        'gaps': <String, dynamic>{
          'hvMainToCorseGap': 22,
          'corseToFineGap': 18,
          'fineToOuterGap': 20,
        },
      },
      'part2Windings': <String, dynamic>{
        'lv': _multiWinding(turns: 24, current: 667, cond: '5 x 3'),
        'hvMain': _multiWinding(turns: 610, current: 26.2, cond: '2 x 1.8'),
        'corse': _multiWinding(turns: 300, current: 18.4, cond: '1.8 x 1.6'),
        'fine': _multiWinding(turns: 150, current: 10.2, cond: '1.6 x 1.4'),
        'outer': _multiWinding(turns: 120, current: 8.1, cond: '1.4 x 1.2'),
      },
      'tankAndOilFormulas': <String, dynamic>{
        'weightsOfActivePart': 2300,
        'weightOfTankAndAcc': 1350,
        'oilWeight': 780,
        'totalOil': 850,
        'transformerWeight': 4430,
        'radiatorHeight': 1400,
        'radiatorWidth': 520,
        'radiatorSection': 20,
        'noOfRadiators': 6,
        'conservatorDia': 360,
        'conservatorLength': 1800,
        'conservatorCapacity': 280,
      },
      'cost': <String, dynamic>{
        'capitalCost': 120000,
        'totalOilCost': 6200,
        'totalCondCost': 42000,
        'totalCoreCost': 36000,
        'totalInsCost': 5400,
        'totalSteelCost': 16000,
        'totalRadiatorCost': 8400,
      },
      'multiCost': <String, dynamic>{
        'conductors': <String, dynamic>{
          'lv': <String, dynamic>{'weight': 260},
          'hvMain': <String, dynamic>{'weight': 210},
          'corse': <String, dynamic>{'weight': 115},
          'fine': <String, dynamic>{'weight': 80},
          'outer': <String, dynamic>{'weight': 60},
        },
      },
    }),
    customerName: 'Krish Transformers',
    customerPlace: 'Bangalore',
  );
}

Map<String, dynamic> _multiWinding({
  required num turns,
  required num current,
  required String cond,
}) {
  return <String, dynamic>{
    'turnsPerPhase': turns,
    'phaseCurrent': current,
    'currentDensity': 3.1,
    'condCrossSec': 45,
    'conductorSizes': cond,
    'condInsulation': 0.2,
    'radialParallelCond': 2,
    'axialParallelCond': 3,
    'windingLength': 720,
    'noOfLayers': 4,
    'turnsLayers': 6,
    'interLayerInsulation': 0.13,
    'ducts': 2,
    'ductSize': 4,
    'discDuctSize': 5,
    'endClearances': 25,
    'eddyStrayLoss': 1.5,
    'tempGradDegC': 12,
    'weightBareInsulated': 100,
    'loadLoss': 800,
  };
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
      'windingTemp': 65,
      'fluxDensity': 1.65,
      'tapStepsPercent': 2.5,
      'tapStepsPositive': 2,
      'tapStepsNegative': 2,
      'core': <String, dynamic>{
        'coreWeight': 880,
        'coreDia': 210,
        'limbHt': 640,
        'cenDist': 420,
        'coreType': 'PRIME',
        'wkgGrade': 'NipM4',
        'area': 2000,
      },
      'tank': <String, dynamic>{
        'tankLength': 1500,
        'tankWidth': 900,
        'tankHeight': 1400,
        'tankWallThickness': 6,
        'tankBottomThickness': 8,
        'frameThickness': 10,
        'tankLidThickness': 5,
        'wdgToTankGap': 80,
        'connectionGap': 120,
        'topYokeToCoverGap': 90,
      },
      'coilDimensions': <String, dynamic>{
        'coreDia': 210,
        'coreGap': 12,
        'lvid': 240,
        'lvradial': 30,
        'lvod': 300,
        'lvhvgap': 25,
        'hvid': 340,
        'hvradial': 40,
        'hvod': 420,
        'hvhvgap': 35,
        'activePartSize': '650 x 420',
      },
      'innerWindings': <String, dynamic>{
        'turnsPerPhase': 18,
        'phaseCurrent': 145,
        'currentDensity': 3.1,
        'condCrossSec': 46.8,
        'condBreadth': 5,
        'condHeight': 2.5,
        'radialParallelCond': 2,
        'axialParallelCond': 3,
        'windingLength': 550,
        'noOfLayers': 4,
        'turnsLayers': 9,
        'interLayerInsulation': 0.2,
        'ducts': 2,
        'ductSize': 4,
        'endClearances': 20,
        'eddyStrayLoss': 1.2,
        'tempGradDegC': 12,
        'weightBareInsulated': 55,
        'loadLoss': 120,
        'terminal': 'Bushing',
      },
      'outerWindings': <String, dynamic>{
        'turnsPerPhase': 457,
        'phaseCurrent': 10.5,
        'currentDensity': 2.9,
        'condCrossSec': 3.62,
        'condBreadth': 2,
        'condHeight': 1.8,
        'radialParallelCond': 1,
        'axialParallelCond': 2,
        'windingLength': 680,
        'noOfLayers': 6,
        'turnsLayers': 76,
        'interLayerInsulation': 0.13,
        'ducts': 3,
        'ductSize': 5,
        'endClearances': 25,
        'eddyStrayLoss': 1.8,
        'tempGradDegC': 14,
        'weightBareInsulated': 45,
        'loadLoss': 336,
        'terminal': 'Bushing',
      },
      'commonFormulas': <String, dynamic>{'er': 1.5, 'ex': 4.24, 'ek': 4.5},
      'tankAndOilFormulas': <String, dynamic>{
        'totalOil': 320,
        'oilWeight': 285,
        'weightOfTankAndAcc': 900,
        'transformerWeight': 3450,
        'weightsOfActivePart': 1200,
        'radiatorHeight': 1200,
        'radiatorWidth': 520,
        'noOfFinsPerRadiator': 18,
        'noOfRadiators': 4,
        'conservatorCapacity': 200,
        'conservatorDia': 320,
        'conservatorLength': 1600,
        'overallDimension': '1700 x 1100 x 1800',
      },
      'hvFormulas': <String, dynamic>{
        'hvCurrentPerPhase': 10.5,
        'hvTurnsPerPhase': 457,
        'hvTurnsPerTap': 30,
        'turnsPerTap': <int>[30],
        'hvR75': 2.4,
        'hvR26': 1.9,
        'hvStrayLoss': 8,
        'hvLoadLossAtNormal': 336,
        'hvGradient': 14,
        'hvTransposition': 'No',
        'hvWireLength': 1200,
        'hvNoOfCoils': 8,
        'hvTurnsPerCoil': 57,
      },
      'lvFormulas': <String, dynamic>{
        'lvCurrentPerPhase': 145,
        'lvProcurementWeight': 55,
        'lvTransposition': 'No',
      },
      'cost': <String, dynamic>{
        'capitalCost': 7890,
        'totalOilCost': 1200,
        'totalCondCost': 3500,
        'totalCoreCost': 1800,
        'totalInsCost': 450,
        'totalSteelCost': 700,
        'totalRadiatorCost': 240,
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
      'tank': <String, dynamic>{'length': 1500, 'width': 900, 'height': 1400},
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
  final List<_OpenedDocument> openedDocuments = <_OpenedDocument>[];

  @override
  Future<void> openDocument({
    required String fileName,
    required Uint8List bytes,
  }) async {
    openedDocuments.add(_OpenedDocument(fileName: fileName, bytes: bytes));
  }

  @override
  Future<void> openUrl(Uri uri) async {
    openedUrls.add(uri.toString());
  }
}

class _OpenedDocument {
  const _OpenedDocument({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}
