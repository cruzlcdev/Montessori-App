import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prototipo_2/features/auth/presentation/widgets/auth_decorated_background.dart';

void main() {
  testWidgets('respeta la preferencia de reducir movimiento', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: AuthDecoratedBackground(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AuthDecoratedBackground), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
