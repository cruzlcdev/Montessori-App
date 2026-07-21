import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prototipo_2/core/widgets/adaptive_single_line_text.dart';

void main() {
  testWidgets('keeps a heading on one line in an iPhone-sized card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(402, 874),
            textScaler: TextScaler.linear(1.2),
          ),
          child: const Scaffold(
            body: Center(
              child: SizedBox(
                width: 245,
                child: AdaptiveSingleLineText(
                  'Seguimiento del grupo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Seguimiento del grupo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AdaptiveSingleLineText)).height,
      lessThan(30),
    );
  });
}
