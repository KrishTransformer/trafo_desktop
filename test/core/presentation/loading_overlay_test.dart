import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/presentation/loading_overlay.dart';

void main() {
  testWidgets('renders progress indicator when loading is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoadingOverlay(
          isLoading: true,
          child: SizedBox.expand(child: Text('Body')),
        ),
      ),
    );

    expect(find.text('Body'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('does not render progress indicator when loading is disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LoadingOverlay(
          isLoading: false,
          child: SizedBox.expand(child: Text('Body')),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
