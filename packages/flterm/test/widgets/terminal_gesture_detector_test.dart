@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show Mods, MouseTracking, Terminal;

void main() {
  group('TerminalGestureDetector', () {
    late TerminalController controller;

    setUp(() => controller = TerminalController());

    tearDown(() => controller.dispose());

    testWidgets('tap does not throw', (tester) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      final gesture = await _mouseDown(tester, const Offset(40, 16));
      await gesture.up();
    });

    testWidgets('drag creates selection with correct cells', (tester) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      final gesture = await _mouseDown(tester, const Offset(8, 0));
      await gesture.moveTo(const Offset(40, 16));
      await gesture.up();

      final selection = controller.selection!;
      expect(selection.startRow, 0);
      expect(selection.startCol, 1);
      expect(selection.endRow, 1);
      expect(selection.endCol, 5);
      expect(selection.mode, TerminalSelectionMode.normal);
    });

    testWidgets('mouse up ends selection drag', (tester) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      final gesture = await _mouseDown(tester, Offset.zero);
      await gesture.moveTo(const Offset(80, 32));
      await gesture.up();

      final selection = controller.selection!;
      expect(selection.startRow, 0);
      expect(selection.endRow, 2);
    });

    testWidgets('drag to same cell does not change selection', (tester) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      final gesture = await _mouseDown(tester, const Offset(8, 0));
      await gesture.moveTo(const Offset(40, 16));
      final selAfterFirst = controller.selection;

      await gesture.moveTo(const Offset(41, 17));
      final selAfterSecond = controller.selection;

      expect(selAfterFirst, selAfterSecond);

      await gesture.up();
    });

    testWidgets('double click selects word', (tester) async {
      _writeToTerminal(controller, 'hello world');

      await tester.pumpWidget(_buildHandler(controller: controller));

      var gesture = await _mouseDown(tester, const Offset(8, 0));
      await gesture.up();

      gesture = await _mouseDown(tester, const Offset(8, 0));
      await gesture.up();

      final selection = controller.selection!;
      expect(selection.startRow, 0);
      expect(selection.startCol, 0);
      expect(selection.endCol, 5);
    });

    testWidgets('double click on second word selects it', (tester) async {
      _writeToTerminal(controller, 'hello world');

      await tester.pumpWidget(_buildHandler(controller: controller));

      var gesture = await _mouseDown(tester, const Offset(56, 0));
      await gesture.up();

      gesture = await _mouseDown(tester, const Offset(56, 0));
      await gesture.up();

      final selection = controller.selection!;
      expect(selection.startCol, 6);
      expect(selection.endCol, 11);
    });

    testWidgets('triple click selects line content only', (tester) async {
      _writeToTerminal(controller, 'Hello');

      await tester.pumpWidget(_buildHandler(controller: controller));

      for (var i = 0; i < 3; i++) {
        final gesture = await _mouseDown(tester, const Offset(40, 0));
        await gesture.up();
      }

      final selection = controller.selection!;
      expect(selection.startCol, 0);
      expect(selection.endCol, 5);
    });

    testWidgets('triple click on wrapped line selects full terminal line', (
      tester,
    ) async {
      final narrowController = TerminalController(
        config: const TerminalConfig(cols: 10, rows: 5),
      );
      addTearDown(narrowController.dispose);

      _writeToTerminal(narrowController, 'ABCDEFGHIJKLMNO');

      await tester.pumpWidget(_buildHandler(controller: narrowController));

      for (var i = 0; i < 3; i++) {
        final gesture = await _mouseDown(tester, const Offset(8, 16));
        await gesture.up();
      }

      final selection = narrowController.selection!;
      expect(selection.startRow, 0);
      expect(selection.startCol, 0);
      expect(selection.endRow, 1);
      expect(selection.endCol, 5);
    });

    testWidgets('triple click with fullRow mode selects entire row width', (
      tester,
    ) async {
      final wideController = TerminalController(
        config: const TerminalConfig(cols: 20, rows: 5),
      );
      addTearDown(wideController.dispose);

      _writeToTerminal(wideController, 'Hello');

      await tester.pumpWidget(
        _buildHandler(
          controller: wideController,
          gestureSettings: const TerminalGestureSettings(lineSelectMode: .full),
        ),
      );

      for (var i = 0; i < 3; i++) {
        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.up();
      }

      final selection = wideController.selection!;
      expect(selection.endCol, 20);
    });

    testWidgets('tap counting resets on distant clicks', (tester) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      var gesture = await _mouseDown(tester, const Offset(40, 16));
      await gesture.up();

      gesture = await _mouseDown(tester, const Offset(200, 200));
      await gesture.up();

      expect(controller.selection, isNull);
    });

    testWidgets('touch long press starts normal selection by default', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      final gesture = await tester.startGesture(const Offset(40, 16));

      await tester.pump(const Duration(milliseconds: 550));

      // Long press alone does not create a selection.
      expect(controller.selection, isNull);

      await gesture.moveTo(const Offset(80, 32));
      final sel = controller.selection!;
      expect(sel.mode, TerminalSelectionMode.normal);

      await gesture.up();
    });

    testWidgets('touch move cancels long press if distance exceeds threshold', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      final gesture = await tester.startGesture(const Offset(40, 16));
      await gesture.moveTo(const Offset(80, 16));

      await tester.pump(const Duration(milliseconds: 550));

      await gesture.moveTo(const Offset(120, 16));
      expect(controller.selection, isNull);

      await gesture.up();
    });

    testWidgets('new click clears existing selection', (tester) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      final gesture = await _mouseDown(tester, Offset.zero);
      await gesture.moveTo(const Offset(80, 32));
      await gesture.up();

      expect(controller.selection, isNotNull);

      final gesture2 = await _mouseDown(tester, const Offset(40, 16));
      await gesture2.up();

      expect(controller.selection, isNull);
    });

    testWidgets('click without existing selection keeps selection null', (
      tester,
    ) async {
      await tester.pumpWidget(_buildHandler(controller: controller));

      final gesture = await _mouseDown(tester, const Offset(40, 16));
      await gesture.up();

      expect(controller.selection, isNull);
    });

    group('gesture settings', () {
      testWidgets('empty enabledSelections prevents drag selection', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {},
            ),
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(controller.selection, isNull);
      });

      testWidgets('empty enabledSelections prevents long press selection', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {},
            ),
          ),
        );

        final gesture = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(controller.selection, isNull);
      });

      testWidgets('drag disabled independently of other gestures', (
        tester,
      ) async {
        _writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {.word},
            ),
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();
        expect(controller.selection, isNull);

        var gesture2 = await _mouseDown(tester, const Offset(8, 0));
        await gesture2.up();
        gesture2 = await _mouseDown(tester, const Offset(8, 0));
        await gesture2.up();
        expect(controller.selection, isNotNull);
      });

      testWidgets('word disabled prevents double-tap word select', (
        tester,
      ) async {
        _writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {.drag, .line, .longPress},
            ),
          ),
        );

        var gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.up();
        gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.up();

        expect(controller.selection, isNull);
      });

      testWidgets('line disabled prevents triple-tap line select', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {.drag},
            ),
          ),
        );

        for (var i = 0; i < 3; i++) {
          final gesture = await _mouseDown(tester, const Offset(40, 16));
          await gesture.up();
        }

        expect(controller.selection, isNull);
      });

      testWidgets('tap count resets at triple even when line disabled', (
        tester,
      ) async {
        _writeToTerminal(controller, 'hello world');

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {.word},
            ),
          ),
        );

        var selectionCount = 0;
        controller.addListener(() {
          if (controller.selection != null) selectionCount++;
        });

        for (var i = 0; i < 5; i++) {
          final gesture = await _mouseDown(tester, const Offset(8, 0));
          await gesture.up();
        }

        expect(selectionCount, 2);
      });

      testWidgets('longPressSelectionMode block uses block mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              longPressSelectionMode: .block,
            ),
          ),
        );

        final gesture = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        final selection = controller.selection!;
        expect(selection.mode, TerminalSelectionMode.block);
      });

      testWidgets('empty enabledSelections still allows tap', (tester) async {
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {},
            ),
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(40, 16));
        await gesture.up();
      });

      testWidgets(
        'empty enabledSelections still allows mouse tracking output',
        (tester) async {
          _enableMouseTracking(controller);

          await tester.pumpWidget(
            _buildHandler(
              controller: controller,
              gestureSettings: const TerminalGestureSettings(
                enabledSelections: {},
              ),
            ),
          );

          final events = <Uint8List>[];
          controller.onOutput = events.add;

          final gesture = await _mouseDown(tester, const Offset(24, 16));
          await gesture.up();

          expect(events, isNotEmpty);
        },
      );
    });

    group('virtual mods', () {
      testWidgets('virtual alt triggers block selection on drag', (
        tester,
      ) async {
        controller.toggleMod(const Mods.alt());

        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        final selection = controller.selection!;
        expect(selection.mode, TerminalSelectionMode.block);
      });

      testWidgets('virtual alt triggers block selection on long press', (
        tester,
      ) async {
        controller.toggleMod(const Mods.alt());

        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        final selection = controller.selection!;
        expect(selection.mode, TerminalSelectionMode.block);
      });

      testWidgets('toggling alt mid-drag switches selection mode', (
        tester,
      ) async {
        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        expect(controller.selection!.mode, TerminalSelectionMode.normal);

        controller.toggleMod(const Mods.alt());
        await gesture.moveTo(const Offset(80, 48));
        expect(controller.selection!.mode, TerminalSelectionMode.block);

        controller.toggleMod(const Mods.alt());
        await gesture.moveTo(const Offset(80, 64));
        expect(controller.selection!.mode, TerminalSelectionMode.normal);

        await gesture.up();
      });

      testWidgets('virtual shift bypasses mouse tracking', (tester) async {
        controller.toggleMod(const Mods.shift());
        _enableMouseTracking(controller);

        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(events, isEmpty);
      });
    });

    group('wide character selection snapping', () {
      setUp(() {
        _terminal(controller).write(
          Uint8List.fromList([
            ...utf8.encode('AB'),
            0xE6, 0x97, 0xA5, // 日 U+65E5
            ...utf8.encode('CD'),
          ]),
        );
        _terminal(controller).renderState.update();
      });

      testWidgets('drag from spacer snaps anchor inclusive', (tester) async {
        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.moveTo(const Offset(40, 0));
        await gesture.up();

        final selection = controller.selection!;
        expect(selection.startCol, 2);
        expect(selection.endCol, 5);
      });

      testWidgets('drag ending on wide char snaps end exclusive', (
        tester,
      ) async {
        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, Offset.zero);
        await gesture.moveTo(const Offset(24, 0));
        expect(controller.selection!.endCol, 4);

        await gesture.moveTo(const Offset(16, 0));
        expect(controller.selection!.endCol, 4);

        await gesture.up();
      });

      testWidgets('leftward drag from spacer snaps anchor exclusive', (
        tester,
      ) async {
        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.moveTo(Offset.zero);
        await gesture.up();

        final selection = controller.selection!;
        expect(selection.startCol, 4);
        expect(selection.endCol, 0);
      });

      testWidgets('narrow cells pass through unaffected', (tester) async {
        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, Offset.zero);
        await gesture.moveTo(const Offset(8, 0));
        await gesture.up();

        final selection = controller.selection!;
        expect(selection.startCol, 0);
        expect(selection.endCol, 1);
      });

      testWidgets('double click on spacer selects wide char', (tester) async {
        await tester.pumpWidget(_buildHandler(controller: controller));

        var gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.up();
        gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.up();

        final selection = controller.selection!;
        expect(selection.startCol, 2);
        expect(selection.endCol, 4);
      });
    });

    group('mouse tracking', () {
      testWidgets('click fires press and release when mode is normal', (
        tester,
      ) async {
        _enableMouseTracking(controller);

        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(events.length, 2);
      });

      testWidgets('click fires press only when mode is x10', (tester) async {
        _enableMouseTracking(controller, mode: .x10);

        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(events.length, 1);
      });

      testWidgets('no events when mode is none', (tester) async {
        final events = <Uint8List>[];
        controller.onOutput = events.add;

        await tester.pumpWidget(_buildHandler(controller: controller));

        final gesture = await _mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(events, isEmpty);
      });
    });
  });
}

const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
final _enableNormalMouse = Uint8List.fromList(utf8.encode('\x1b[?1000h'));
final _enableX10Mouse = Uint8List.fromList(utf8.encode('\x1b[?9h'));

TerminalViewBinding _binding(TerminalController controller) {
  return controller as TerminalViewBinding;
}

Widget _buildHandler({
  required TerminalController controller,
  CellMetrics metrics = _metrics,
  TerminalGestureSettings gestureSettings = const TerminalGestureSettings(),
  ScrollController? scrollController,
  int visibleRows = 24,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: TerminalGestureDetector(
        binding: controller as TerminalViewBinding,
        metrics: metrics,
        settings: gestureSettings,
        scrollController: scrollController,
        visibleRows: visibleRows,
        child: const SizedBox(width: 640, height: 384),
      ),
    ),
  );
}

void _enableMouseTracking(
  TerminalController controller, {
  MouseTracking mode = .normal,
}) {
  final seq = switch (mode) {
    .normal => _enableNormalMouse,
    .x10 => _enableX10Mouse,
    _ => _enableNormalMouse,
  };
  final binding = _binding(controller);
  binding.terminal.write(seq);
  binding.handleResize(
    cols: 80,
    rows: 24,
    metrics: _metrics,
    padding: EdgeInsets.zero,
    devicePixelRatio: 1.0,
  );
  binding.terminal.renderState.update();
}

Future<TestGesture> _mouseDown(
  WidgetTester tester,
  Offset pos, {
  int buttons = kPrimaryButton,
}) {
  return tester.startGesture(pos, kind: .mouse, buttons: buttons);
}

Terminal _terminal(TerminalController controller) {
  return _binding(controller).terminal;
}

void _writeToTerminal(TerminalController controller, String text) {
  _terminal(controller).write(Uint8List.fromList(utf8.encode(text)));
  _terminal(controller).renderState.update();
}
