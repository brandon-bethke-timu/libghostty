import 'package:flterm/src/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show ScreenMode;

void main() {
  group('TerminalScrollController', () {
    late TerminalScrollController controller;

    setUp(() => controller = TerminalScrollController());

    tearDown(() => controller.dispose());

    test('screenMode defaults to primary', () {
      expect(controller.screenMode, ScreenMode.primary);
    });

    testWidgets('createScrollPosition returns TerminalScrollPosition', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScrollable(controller));
      expect(controller.position, isA<TerminalScrollPosition>());
    });

    testWidgets('screenMode propagates to attached positions', (tester) async {
      await tester.pumpWidget(_buildScrollable(controller));

      controller.screenMode = ScreenMode.alternate;

      final position = controller.position as TerminalScrollPosition;
      expect(position.screenMode, ScreenMode.alternate);

      controller.screenMode = ScreenMode.primary;
      expect(position.screenMode, ScreenMode.primary);
    });
  });

  group('TerminalScrollPosition', () {
    late TerminalScrollController controller;

    setUp(() => controller = TerminalScrollController());

    tearDown(() => controller.dispose());

    testWidgets('uses finite extents in primary mode', (tester) async {
      await tester.pumpWidget(_buildScrollable(controller));

      final position = controller.position;
      expect(position.maxScrollExtent.isFinite, isTrue);
    });

    testWidgets('uses infinite extents in alternate mode', (tester) async {
      await tester.pumpWidget(_buildScrollable(controller));

      controller.screenMode = ScreenMode.alternate;
      // Content change forces relayout, which calls applyContentDimensions.
      await tester.pumpWidget(_buildScrollable(controller, contentHeight: 501));

      final position = controller.position;
      expect(position.maxScrollExtent, double.infinity);
      expect(position.minScrollExtent, double.negativeInfinity);
    });

    testWidgets('saves and restores pixels on mode switch', (tester) async {
      await tester.pumpWidget(_buildScrollable(controller));

      controller.jumpTo(100);
      await tester.pump();
      expect(controller.position.pixels, 100);

      controller.screenMode = ScreenMode.alternate;
      await tester.pumpWidget(_buildScrollable(controller));

      controller.jumpTo(9999);
      await tester.pump();
      expect(controller.position.pixels, 9999);

      controller.screenMode = ScreenMode.primary;
      await tester.pumpWidget(_buildScrollable(controller));

      expect(controller.position.pixels, 100);
    });

    testWidgets('notifies listeners on scroll in alternate mode', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScrollable(controller));

      controller.screenMode = ScreenMode.alternate;
      await tester.pumpWidget(_buildScrollable(controller));

      var notified = false;
      controller.addListener(() => notified = true);

      controller.jumpTo(50);
      expect(notified, isTrue);
    });

    testWidgets('clamps restored pixels to new extents', (tester) async {
      await tester.pumpWidget(_buildScrollable(controller));

      final maxExtent = controller.position.maxScrollExtent;
      controller.jumpTo(maxExtent);
      await tester.pump();

      controller.screenMode = ScreenMode.alternate;
      await tester.pumpWidget(_buildScrollable(controller));

      await tester.pumpWidget(_buildScrollable(controller, contentHeight: 200));

      controller.screenMode = ScreenMode.primary;
      await tester.pumpWidget(_buildScrollable(controller, contentHeight: 200));

      expect(controller.position.pixels, 0);
    });
  });
}

Widget _buildScrollable(
  TerminalScrollController controller, {
  double contentHeight = 500,
  double viewportHeight = 200,
}) {
  return MaterialApp(
    home: SizedBox(
      height: viewportHeight,
      child: ListView(
        controller: controller,
        children: [SizedBox(height: contentHeight)],
      ),
    ),
  );
}
