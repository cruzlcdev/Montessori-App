import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prototipo_2/admin_web/presentation/theme/admin_theme.dart';
import 'package:prototipo_2/admin_web/presentation/widgets/admin_time_selector.dart';

void main() {
  testWidgets('offers every hour and minute in styled dropdown menus', (
    tester,
  ) async {
    var selectedHour = 13;
    var selectedMinute = 15;

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminThemeData.light,
        home: Scaffold(
          body: SizedBox(
            width: 440,
            child: AdminTimeSelector(
              hour: selectedHour,
              minute: selectedMinute,
              onHourChanged: (value) => selectedHour = value,
              onMinuteChanged: (value) => selectedMinute = value,
            ),
          ),
        ),
      ),
    );

    expect(find.text('13'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);

    await tester.tap(find.byTooltip('Seleccionar hora'));
    await tester.pumpAndSettle();
    expect(find.text('00'), findsOneWidget);
    expect(find.text('23'), findsOneWidget);
    await tester.tap(find.text('14'));
    await tester.pumpAndSettle();
    expect(selectedHour, 14);

    await tester.tap(find.byTooltip('Seleccionar minutos'));
    await tester.pumpAndSettle();
    expect(find.text('00'), findsOneWidget);
    expect(find.text('59'), findsOneWidget);
    await tester.ensureVisible(find.text('37'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('37'));
    await tester.pumpAndSettle();
    expect(selectedMinute, 37);
  });

  testWidgets('renders and responds inside a web dialog', (tester) async {
    var selectedHour = 8;

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminThemeData.light,
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (dialogContext) {
                      return Dialog(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatefulBuilder(
                                  builder: (context, setDialogState) {
                                    return AdminTimeSelector(
                                      hour: selectedHour,
                                      minute: 0,
                                      onHourChanged: (value) {
                                        setDialogState(
                                          () => selectedHour = value,
                                        );
                                      },
                                      onMinuteChanged: (_) {},
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                child: const Text('Abrir selector'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();

    expect(find.text('08'), findsOneWidget);
    await tester.tap(find.byTooltip('Seleccionar hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('09'));
    await tester.pumpAndSettle();
    expect(find.text('09'), findsOneWidget);
  });
}
