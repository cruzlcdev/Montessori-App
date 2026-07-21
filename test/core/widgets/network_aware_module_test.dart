import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:prototipo_2/core/connectivity/network_status_controller.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:prototipo_2/core/widgets/network_aware_module.dart';

void main() {
  testWidgets('shows a matching skeleton before the offline state', (
    tester,
  ) async {
    final network = NetworkStatusController(
      autoInitialize: false,
      initialOffline: true,
    );
    addTearDown(network.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: network,
        child: const MaterialApp(
          home: Scaffold(
            body: NetworkAwareModule(
              layout: AppSkeletonLayout.calendar,
              child: Text('Calendario conectado'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('module-loading-skeleton-calendar')),
      findsOneWidget,
    );
    expect(find.text('Sin conexión a internet'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1250));

    expect(find.text('Sin conexión a internet'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.text('Calendario conectado'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps module content visible while a transport is available', (
    tester,
  ) async {
    final network = NetworkStatusController(autoInitialize: false);
    addTearDown(network.dispose);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: network,
        child: const MaterialApp(
          home: Scaffold(
            body: NetworkAwareModule(
              layout: AppSkeletonLayout.news,
              child: Text('Noticias conectadas'),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Noticias conectadas'), findsOneWidget);
    expect(find.text('Sin conexión a internet'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
