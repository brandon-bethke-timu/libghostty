@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart'
    show Mods, MouseTracking, Screen, Terminal;

const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

Widget _buildHandler({
  required TerminalController controller,
  CellMetrics metrics = _metrics,
  MouseTracking mouseMode = MouseTracking.none,
  TerminalGestureSettings gestureSettings = const TerminalGestureSettings(),
  VoidCallback? onFocusRequest,
  ValueChanged<TerminalSelection?>? onSelectionChanged,
  ValueChanged<Uint8List>? onOutput,
  ScrollController? scrollController,
  Screen Function()? getScreen,
  int visibleRows = 24,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: TerminalGestureDetector(
        controller: controller,
        metrics: metrics,
        mouseMode: mouseMode,
        settings: gestureSettings,
        onFocusRequest: onFocusRequest,
        onSelectionChanged: onSelectionChanged,
        onOutput: onOutput,
        scrollController: scrollController,
        getScreen: getScreen,
        visibleRows: visibleRows,
        child: const SizedBox(width: 640, height: 384),
      ),
    ),
  );
}

Future<TestGesture> _mouseDown(
  WidgetTester tester,
  Offset pos, {
  int buttons = kPrimaryButton,
}) {
  return tester.startGesture(
    pos,
    kind: PointerDeviceKind.mouse,
    buttons: buttons,
  );
}

void main() {
  group('TerminalGestureDetector', () {
    late TerminalController controller;

    setUp(() => controller = TerminalController());
    tearDown(() => controller.dispose());

    testWidgets('fires onFocusRequest on pointer down', (tester) async {
      var focused = false;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          onFocusRequest: () => focused = true,
        ),
      );

      final gesture = await _mouseDown(tester, const Offset(40, 16));
      await gesture.up();

      expect(focused, isTrue);
    });

    testWidgets('drag creates selection with correct cells', (tester) async {
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      final gesture = await _mouseDown(tester, const Offset(8, 0));
      await gesture.moveTo(const Offset(40, 16));
      await gesture.up();

      expect(lastSel, isNotNull);
      expect(lastSel!.startRow, 0);
      expect(lastSel!.startCol, 1);
      expect(lastSel!.endRow, 1);
      expect(lastSel!.endCol, 5);
      expect(lastSel!.mode, TerminalSelectionMode.normal);
    });

    testWidgets('mouse up ends selection drag', (tester) async {
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      final gesture = await _mouseDown(tester, Offset.zero);
      await gesture.moveTo(const Offset(80, 32));
      await gesture.up();

      expect(lastSel, isNotNull);
      expect(lastSel!.startRow, 0);
      expect(lastSel!.endRow, 2);
    });

    testWidgets('drag to same cell does not fire callback again', (
      tester,
    ) async {
      var callbackCount = 0;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          onSelectionChanged: (_) => callbackCount++,
        ),
      );

      final gesture = await _mouseDown(tester, const Offset(8, 0));
      await gesture.moveTo(const Offset(40, 16));
      expect(callbackCount, 1);

      await gesture.moveTo(const Offset(41, 17));
      expect(callbackCount, 1);

      await gesture.up();
    });

    testWidgets('double click selects word', (tester) async {
      final terminal = Terminal(cols: 20, rows: 5);
      terminal.write(Uint8List.fromList(utf8.encode('hello world')));
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          getScreen: () => terminal.screen,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      var gesture = await _mouseDown(tester, const Offset(8, 0));
      await gesture.up();

      gesture = await _mouseDown(tester, const Offset(8, 0));
      await gesture.up();

      expect(lastSel, isNotNull);
      expect(lastSel!.startRow, 0);
      expect(lastSel!.startCol, 0);
      expect(lastSel!.endCol, 5);

      terminal.dispose();
    });

    testWidgets('double click on second word selects it', (tester) async {
      final terminal = Terminal(cols: 20, rows: 5);
      terminal.write(Uint8List.fromList(utf8.encode('hello world')));
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          getScreen: () => terminal.screen,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      var gesture = await _mouseDown(tester, const Offset(56, 0));
      await gesture.up();

      gesture = await _mouseDown(tester, const Offset(56, 0));
      await gesture.up();

      expect(lastSel, isNotNull);
      expect(lastSel!.startCol, 6);
      expect(lastSel!.endCol, 11);

      terminal.dispose();
    });

    testWidgets('triple click selects line content only', (tester) async {
      final terminal = Terminal(cols: 20, rows: 5);
      terminal.write(Uint8List.fromList(utf8.encode('Hello')));
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          getScreen: () => terminal.screen,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      for (var i = 0; i < 3; i++) {
        final gesture = await _mouseDown(tester, const Offset(40, 0));
        await gesture.up();
      }

      expect(lastSel!.startCol, 0);
      expect(lastSel!.endCol, 5);

      terminal.dispose();
    });

    testWidgets('triple click on wrapped line selects full terminal line', (
      tester,
    ) async {
      // cols=10: "ABCDEFGHIJKLMNO" wraps: row 0 full, row 1 has 5 chars
      final terminal = Terminal(cols: 10, rows: 5);
      terminal.write(Uint8List.fromList(utf8.encode('ABCDEFGHIJKLMNO')));
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          getScreen: () => terminal.screen,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      // Triple-click on row 1 (the continuation)
      for (var i = 0; i < 3; i++) {
        final gesture = await _mouseDown(tester, const Offset(8, 16));
        await gesture.up();
      }

      expect(lastSel!.startRow, 0);
      expect(lastSel!.startCol, 0);
      expect(lastSel!.endRow, 1);
      expect(lastSel!.endCol, 5);

      terminal.dispose();
    });

    testWidgets('triple click with fullRow mode selects entire row width', (
      tester,
    ) async {
      final terminal = Terminal(cols: 20, rows: 5);
      terminal.write(Uint8List.fromList(utf8.encode('Hello')));
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          gestureSettings: const TerminalGestureSettings(
            lineSelectMode: LineSelectMode.full,
          ),
          getScreen: () => terminal.screen,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      for (var i = 0; i < 3; i++) {
        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.up();
      }

      expect(lastSel!.endCol, 20);

      terminal.dispose();
    });

    testWidgets('tap counting resets on distant clicks', (tester) async {
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      var gesture = await _mouseDown(tester, const Offset(40, 16));
      await gesture.up();

      gesture = await _mouseDown(tester, const Offset(200, 200));
      await gesture.up();

      expect(lastSel, isNull);
    });

    testWidgets('touch long press starts normal selection by default', (
      tester,
    ) async {
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      final gesture = await tester.startGesture(const Offset(40, 16));

      await tester.pump(const Duration(milliseconds: 550));

      expect(lastSel, isNull);

      await gesture.moveTo(const Offset(80, 32));
      expect(lastSel, isNotNull);
      expect(lastSel!.mode, TerminalSelectionMode.normal);

      await gesture.up();
    });

    testWidgets('touch move cancels long press if distance exceeds threshold', (
      tester,
    ) async {
      TerminalSelection? lastSel;

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          onSelectionChanged: (sel) => lastSel = sel,
        ),
      );

      final gesture = await tester.startGesture(const Offset(40, 16));
      await gesture.moveTo(const Offset(80, 16));

      await tester.pump(const Duration(milliseconds: 550));

      await gesture.moveTo(const Offset(120, 16));
      expect(lastSel, isNull);

      await gesture.up();
    });

    testWidgets('new click clears existing selection and fires callback', (
      tester,
    ) async {
      final binding = controller as TerminalViewBinding;
      TerminalSelection? lastSel;

      void handleSelection(TerminalSelection? sel) {
        lastSel = sel;
        binding.selection = sel;
      }

      await tester.pumpWidget(
        _buildHandler(
          controller: controller,
          onSelectionChanged: handleSelection,
        ),
      );

      final gesture = await _mouseDown(tester, Offset.zero);
      await gesture.moveTo(const Offset(80, 32));
      await gesture.up();

      expect(lastSel, isNotNull);

      final gesture2 = await _mouseDown(tester, const Offset(40, 16));
      await gesture2.up();

      expect(lastSel, isNull);
    });

    testWidgets(
      'click without existing selection does not fire null callback',
      (tester) async {
        var nullCallbackCount = 0;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            onSelectionChanged: (sel) {
              if (sel == null) nullCallbackCount++;
            },
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(40, 16));
        await gesture.up();

        expect(nullCallbackCount, 0);
      },
    );

    group('gesture settings', () {
      testWidgets('empty enabledSelections prevents drag selection', (
        tester,
      ) async {
        TerminalSelection? lastSel;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {},
            ),
            onSelectionChanged: (sel) => lastSel = sel,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(lastSel, isNull);
      });

      testWidgets('empty enabledSelections prevents long press selection', (
        tester,
      ) async {
        TerminalSelection? lastSel;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {},
            ),
            onSelectionChanged: (sel) => lastSel = sel,
          ),
        );

        final gesture = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(lastSel, isNull);
      });

      testWidgets('drag disabled independently of other gestures', (
        tester,
      ) async {
        final terminal = Terminal(cols: 20, rows: 5);
        terminal.write(Uint8List.fromList(utf8.encode('hello world')));
        TerminalSelection? lastSel;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {SelectionGesture.word},
            ),
            getScreen: () => terminal.screen,
            onSelectionChanged: (sel) => lastSel = sel,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();
        expect(lastSel, isNull);

        var gesture2 = await _mouseDown(tester, const Offset(8, 0));
        await gesture2.up();
        gesture2 = await _mouseDown(tester, const Offset(8, 0));
        await gesture2.up();
        expect(lastSel, isNotNull);

        terminal.dispose();
      });

      testWidgets('word disabled prevents double-tap word select', (
        tester,
      ) async {
        final terminal = Terminal(cols: 20, rows: 5);
        terminal.write(Uint8List.fromList(utf8.encode('hello world')));
        TerminalSelection? lastSel;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {
                SelectionGesture.drag,
                SelectionGesture.line,
                SelectionGesture.longPress,
              },
            ),
            getScreen: () => terminal.screen,
            onSelectionChanged: (sel) => lastSel = sel,
          ),
        );

        var gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.up();
        gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.up();

        expect(lastSel, isNull);
        terminal.dispose();
      });

      testWidgets('line disabled prevents triple-tap line select', (
        tester,
      ) async {
        final terminal = Terminal(cols: 20, rows: 5);
        TerminalSelection? lastSel;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {SelectionGesture.drag},
            ),
            getScreen: () => terminal.screen,
            onSelectionChanged: (sel) => lastSel = sel,
          ),
        );

        for (var i = 0; i < 3; i++) {
          final gesture = await _mouseDown(tester, const Offset(40, 16));
          await gesture.up();
        }

        expect(lastSel, isNull);
        terminal.dispose();
      });

      testWidgets('tap count resets at triple even when line disabled', (
        tester,
      ) async {
        final terminal = Terminal(cols: 20, rows: 5);
        terminal.write(Uint8List.fromList(utf8.encode('hello world')));
        var selectionCount = 0;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {SelectionGesture.word},
            ),
            getScreen: () => terminal.screen,
            onSelectionChanged: (sel) {
              if (sel != null) selectionCount++;
            },
          ),
        );

        for (var i = 0; i < 5; i++) {
          final gesture = await _mouseDown(tester, const Offset(8, 0));
          await gesture.up();
        }

        expect(selectionCount, 2);
      });

      testWidgets('longPressSelectionMode block uses block mode', (
        tester,
      ) async {
        TerminalSelection? lastSel;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              longPressSelectionMode: TerminalSelectionMode.block,
            ),
            onSelectionChanged: (sel) => lastSel = sel,
          ),
        );

        final gesture = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(lastSel, isNotNull);
        expect(lastSel!.mode, TerminalSelectionMode.block);
      });

      testWidgets('empty enabledSelections still allows focus request', (
        tester,
      ) async {
        var focused = false;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {},
            ),
            onFocusRequest: () => focused = true,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(40, 16));
        await gesture.up();

        expect(focused, isTrue);
      });

      testWidgets(
        'empty enabledSelections still allows mouse tracking output',
        (tester) async {
          final output = <Uint8List>[];

          await tester.pumpWidget(
            _buildHandler(
              controller: controller,
              gestureSettings: const TerminalGestureSettings(
                enabledSelections: {},
              ),
              mouseMode: MouseTracking.normal,
              onOutput: output.add,
            ),
          );

          final gesture = await _mouseDown(tester, const Offset(24, 16));
          await gesture.up();

          expect(output, isNotEmpty);
        },
      );
    });

    group('virtual mods', () {
      testWidgets('virtual alt triggers block selection on drag', (
        tester,
      ) async {
        controller.toggleMod(Mods.alt);
        TerminalSelection? lastSel;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            onSelectionChanged: (sel) => lastSel = sel,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(lastSel, isNotNull);
        expect(lastSel!.mode, TerminalSelectionMode.block);
      });

      testWidgets('virtual alt triggers block selection on long press', (
        tester,
      ) async {
        controller.toggleMod(Mods.alt);
        TerminalSelection? lastSel;

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            onSelectionChanged: (sel) => lastSel = sel,
          ),
        );

        final gesture = await tester.startGesture(const Offset(40, 16));
        await tester.pump(const Duration(milliseconds: 550));
        await gesture.moveTo(const Offset(80, 32));
        await gesture.up();

        expect(lastSel, isNotNull);
        expect(lastSel!.mode, TerminalSelectionMode.block);
      });

      testWidgets('toggling alt mid-drag switches selection mode', (
        tester,
      ) async {
        final selections = <TerminalSelection>[];

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            onSelectionChanged: (sel) {
              if (sel != null) selections.add(sel);
            },
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(8, 0));
        await gesture.moveTo(const Offset(80, 32));
        expect(selections.last.mode, TerminalSelectionMode.normal);

        controller.toggleMod(Mods.alt);
        await gesture.moveTo(const Offset(80, 48));
        expect(selections.last.mode, TerminalSelectionMode.block);

        controller.toggleMod(Mods.alt);
        await gesture.moveTo(const Offset(80, 64));
        expect(selections.last.mode, TerminalSelectionMode.normal);

        await gesture.up();
      });

      testWidgets('virtual shift bypasses mouse tracking', (tester) async {
        controller.toggleMod(Mods.shift);
        final output = <Uint8List>[];

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            mouseMode: MouseTracking.normal,
            onOutput: output.add,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(output, isEmpty);
      });
    });

    group('wide character selection snapping', () {
      // Row 0: "AB日CD" → col 0:A, 1:B, 2:日(wide), 3:spacer, 4:C, 5:D
      late Terminal terminal;

      setUp(() {
        terminal = Terminal(cols: 20, rows: 5);
        terminal.write(
          Uint8List.fromList([
            ...utf8.encode('AB'),
            0xE6, 0x97, 0xA5, // 日 U+65E5
            ...utf8.encode('CD'),
          ]),
        );
      });

      tearDown(() => terminal.dispose());

      testWidgets('drag from spacer snaps anchor inclusive', (tester) async {
        TerminalSelection? sel;
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            getScreen: () => terminal.screen,
            onSelectionChanged: (s) => sel = s,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.moveTo(const Offset(40, 0));
        await gesture.up();

        expect(sel!.startCol, 2);
        expect(sel!.endCol, 5);
      });

      testWidgets('drag ending on wide char snaps end exclusive', (
        tester,
      ) async {
        TerminalSelection? sel;
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            getScreen: () => terminal.screen,
            onSelectionChanged: (s) => sel = s,
          ),
        );

        // Both spacer (col 3) and wide start (col 2) snap to col 4
        final gesture = await _mouseDown(tester, Offset.zero);
        await gesture.moveTo(const Offset(24, 0));
        expect(sel!.endCol, 4);

        await gesture.moveTo(const Offset(16, 0));
        expect(sel!.endCol, 4);

        await gesture.up();
      });

      testWidgets('leftward drag from spacer snaps anchor exclusive', (
        tester,
      ) async {
        TerminalSelection? sel;
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            getScreen: () => terminal.screen,
            onSelectionChanged: (s) => sel = s,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.moveTo(Offset.zero);
        await gesture.up();

        expect(sel!.startCol, 4);
        expect(sel!.endCol, 0);
      });

      testWidgets('narrow cells and missing screen are unaffected', (
        tester,
      ) async {
        TerminalSelection? sel;

        // With screen: narrow cells pass through
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            getScreen: () => terminal.screen,
            onSelectionChanged: (s) => sel = s,
          ),
        );
        var gesture = await _mouseDown(tester, Offset.zero);
        await gesture.moveTo(const Offset(8, 0));
        await gesture.up();
        expect(sel!.startCol, 0);
        expect(sel!.endCol, 1);

        // Without screen: spacer cols pass through raw
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            onSelectionChanged: (s) => sel = s,
          ),
        );
        gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.moveTo(const Offset(40, 0));
        await gesture.up();
        expect(sel!.startCol, 3);
        expect(sel!.endCol, 5);
      });

      testWidgets('double-click on spacer selects wide char', (tester) async {
        TerminalSelection? sel;
        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            getScreen: () => terminal.screen,
            onSelectionChanged: (s) => sel = s,
          ),
        );

        var gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.up();
        gesture = await _mouseDown(tester, const Offset(24, 0));
        await gesture.up();

        expect(sel!.startCol, 2);
        expect(sel!.endCol, 4);
      });
    });

    group('mouse tracking', () {
      testWidgets('click sends SGR press and release when mode is normal', (
        tester,
      ) async {
        final output = <Uint8List>[];

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            mouseMode: MouseTracking.normal,
            onOutput: output.add,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(output.length, 2);
        expect(utf8.decode(output.first), startsWith('\x1b[<'));
        expect(utf8.decode(output.first), endsWith('M'));
        expect(utf8.decode(output[1]), endsWith('m'));
      });

      testWidgets('x10 mode sends press only', (tester) async {
        final output = <Uint8List>[];

        await tester.pumpWidget(
          _buildHandler(
            controller: controller,
            mouseMode: MouseTracking.x10,
            onOutput: output.add,
          ),
        );

        final gesture = await _mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(output.length, 1);
        expect(utf8.decode(output.first), endsWith('M'));
      });

      testWidgets('no output when mode is none', (tester) async {
        final output = <Uint8List>[];

        await tester.pumpWidget(
          _buildHandler(controller: controller, onOutput: output.add),
        );

        final gesture = await _mouseDown(tester, const Offset(24, 16));
        await gesture.up();

        expect(output, isEmpty);
      });
    });
  });
}
