import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prototipo_2/core/widgets/app_loading_skeleton.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  testWidgets('shows a responsive home mockup instead of a progress circle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AppLoadingSkeleton()));

    expect(
      find.byWidgetPredicate((widget) => widget is Skeletonizer),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('app-loading-skeleton')), findsOneWidget);
    expect(find.byWidgetPredicate((widget) => widget is Bone), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders without animation when reduce motion is enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: HomeLoadingSkeleton()),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate((widget) => widget is Skeletonizer),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  for (final layout in AppSkeletonLayout.values) {
    testWidgets('renders ${layout.name} skeleton on a compact phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(960, 1600);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: ModuleLoadingSkeleton(layout: layout)),
        ),
      );

      expect(
        find.byKey(ValueKey('module-loading-skeleton-${layout.name}')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
