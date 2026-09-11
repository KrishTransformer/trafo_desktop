import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/features/home/domain/models/design_summary.dart';

void main() {
  test('explicit multi design type takes precedence over stored payloads', () {
    final design = DesignSummary.fromJson(<String, dynamic>{
      'id': 'entity-1',
      'designId': '500k-M12345',
      'designType': 'multi',
      'twoWindings': '{}',
      'multiWindings': '{}',
    });

    expect(design.type, DesignType.multiWinding);
    expect(design.isMultiWinding, isTrue);
  });

  test('records without designType default to two-winding designs', () {
    final design = DesignSummary.fromJson(<String, dynamic>{
      'id': 'entity-2',
      'designId': '500k-M54321',
      'multiWindings': <String, dynamic>{'kVA': 500},
    });

    expect(design.type, DesignType.twoWinding);
  });

  test('two-winding records remain the default', () {
    final design = DesignSummary.fromJson(<String, dynamic>{
      'id': 'entity-3',
      'designId': '100k-82911',
      'twoWindings': <String, dynamic>{'kVA': 100},
    });

    expect(design.type, DesignType.twoWinding);
    expect(design.isMultiWinding, isFalse);
  });
}
