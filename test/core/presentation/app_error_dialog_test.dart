import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trafo_desktop/src/core/presentation/app_error_dialog.dart';

void main() {
  testWidgets('shows and dismisses the error dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    AppErrorDialog.show(
                      context,
                      title: 'Request failed',
                      message: 'Unable to load data.',
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Unable to load data.'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Request failed'), findsNothing);
  });
}
