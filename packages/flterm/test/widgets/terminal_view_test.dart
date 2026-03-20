import 'dart:convert';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

const _cols = 80;
const _rows = 24;

Widget _wrapInApp({
  required Terminal terminal,
  TerminalController? controller,
  TerminalTheme? theme,
  ValueChanged<Uint8List>? onOutput,
  ValueChanged<TerminalSize>? onResize,
  bool autofocus = false,
  TerminalInputMode inputMode = TerminalInputMode.interactive,
  bool showKeyboard = true,
  MouseAutoHide mouseAutoHide = MouseAutoHide.onInput,
  TerminalGestureSettings gestureSettings = const TerminalGestureSettings(),
  EdgeInsets padding = EdgeInsets.zero,
  double width = 800,
  double height = 480,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
        height: height,
        child: TerminalView(
          terminal: terminal,
          controller: controller,
          theme: theme,
          onOutput: onOutput,
          onResize: onResize,
          autofocus: autofocus,
          inputMode: inputMode,
          showKeyboard: showKeyboard,
          mouseAutoHide: mouseAutoHide,
          gestureSettings: gestureSettings,
          padding: padding,
        ),
      ),
    ),
  );
}

Future<void> _sendSelectAllShortcut(WidgetTester tester) async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.macOS || TargetPlatform.iOS:
      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    case TargetPlatform.linux || TargetPlatform.fuchsia:
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    case TargetPlatform.windows || TargetPlatform.android:
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  }
  await tester.pump();
}

void main() {
  group('TerminalView', () {
    late Terminal terminal;

    setUp(() {
      terminal = Terminal(cols: _cols, rows: _rows);
    });

    tearDown(() {
      terminal.dispose();
    });

    testWidgets('renders with default and provided controller', (tester) async {
      await tester.pumpWidget(_wrapInApp(terminal: terminal));
      expect(find.byType(TerminalView), findsOneWidget);

      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller),
      );
      expect(find.byType(TerminalView), findsOneWidget);
      controller.dispose();
    });

    testWidgets('onResize fires with dimensions from layout', (tester) async {
      final sizes = <TerminalSize>[];

      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, onResize: sizes.add),
      );
      await tester.pumpAndSettle();

      expect(sizes, isNotEmpty);
      expect(sizes.last.cols, greaterThan(0));
      expect(sizes.last.rows, greaterThan(0));
    });

    testWidgets('tap to focus', (tester) async {
      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller),
      );

      expect(controller.hasFocus, isFalse);

      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();

      expect(controller.hasFocus, isTrue);
      controller.dispose();
    });

    testWidgets('autofocus focuses on mount', (tester) async {
      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller, autofocus: true),
      );
      await tester.pump();

      expect(controller.hasFocus, isTrue);
      controller.dispose();
    });

    testWidgets('keyboard input produces output via onOutput', (tester) async {
      final output = <Uint8List>[];

      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, autofocus: true, onOutput: output.add),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(output, isNotEmpty);
    });

    testWidgets('dispose cleans up without error', (tester) async {
      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller),
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(controller.hasFocus, isFalse);
      controller.dispose();
    });

    testWidgets('changing terminal instance updates rendering', (tester) async {
      await tester.pumpWidget(_wrapInApp(terminal: terminal));

      final terminal2 = Terminal(cols: _cols, rows: _rows);
      terminal2.write(Uint8List.fromList(utf8.encode('hello')));

      await tester.pumpWidget(_wrapInApp(terminal: terminal2));
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
      terminal2.dispose();
    });

    testWidgets('changing theme updates metrics', (tester) async {
      await tester.pumpWidget(_wrapInApp(terminal: terminal));

      final largeTheme = TerminalTheme(
        foreground: const Color(0xFFFFFFFF),
        background: const Color(0xFF000000),
        ansiColors: List.generate(16, (_) => const Color(0xFF888888)),
        fontSize: 24.0,
      );

      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, theme: largeTheme),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('sendText via controller produces onOutput', (tester) async {
      final controller = TerminalController();
      final output = <Uint8List>[];

      await tester.pumpWidget(
        _wrapInApp(
          terminal: terminal,
          controller: controller,
          onOutput: output.add,
        ),
      );
      await tester.pump();

      controller.sendText('hello');

      expect(output, hasLength(1));
      expect(utf8.decode(output.first), 'hello');
      controller.dispose();
    });

    testWidgets('changing controller detaches old and attaches new', (
      tester,
    ) async {
      final controller1 = TerminalController();
      final controller2 = TerminalController();

      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller1),
      );

      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller2),
      );
      await tester.pumpAndSettle();

      expect(controller1.hasFocus, isFalse);
      expect(find.byType(TerminalView), findsOneWidget);

      controller1.dispose();
      controller2.dispose();
    });

    testWidgets('changing scrollController does not throw', (tester) async {
      final sc1 = TerminalScrollController();
      final sc2 = TerminalScrollController();

      await tester.pumpWidget(_wrapInApp(terminal: terminal));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 480,
              child: TerminalView(
                terminal: terminal,
                scrollController: sc1,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 480,
              child: TerminalView(
                terminal: terminal,
                scrollController: sc2,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);

      sc1.dispose();
      sc2.dispose();
    });

    testWidgets('readOnly mode ignores keyboard input', (tester) async {
      final output = <Uint8List>[];

      await tester.pumpWidget(
        _wrapInApp(
          terminal: terminal,
          autofocus: true,
          inputMode: TerminalInputMode.readOnly,
          onOutput: output.add,
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(output, isEmpty);
    });

    testWidgets('showKeyboard false skips keyboard show on focus', (
      tester,
    ) async {
      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(
          terminal: terminal,
          controller: controller,
          showKeyboard: false,
        ),
      );

      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();

      expect(controller.hasFocus, isTrue);
      controller.dispose();
    });

    testWidgets('touch drag does not create selection', (tester) async {
      terminal.write(Uint8List.fromList(utf8.encode('hello world')));
      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(TerminalView));

      final downEvent = PointerDownEvent(position: center);
      await tester.sendEventToBinding(downEvent);
      await tester.pump();

      final moveEvent = PointerMoveEvent(
        position: center + const Offset(100, 0),
        pointer: downEvent.pointer,
      );
      await tester.sendEventToBinding(moveEvent);
      await tester.pump();

      final upEvent = PointerUpEvent(
        position: center + const Offset(100, 0),
        pointer: downEvent.pointer,
      );
      await tester.sendEventToBinding(upEvent);
      await tester.pumpAndSettle();

      expect(controller.selection, isNull);
      controller.dispose();
    });

    testWidgets('long press starts normal selection by default', (
      tester,
    ) async {
      terminal.write(Uint8List.fromList(utf8.encode('hello world')));
      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(TerminalView));
      final gesture = await tester.startGesture(center);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(80, 40));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final sel = controller.selection;
      expect(sel, isNotNull);
      expect(sel!.mode, TerminalSelectionMode.normal);
      controller.dispose();
    });

    testWidgets('scroll event changes scroll offset', (tester) async {
      for (var i = 0; i < 50; i++) {
        terminal.write(Uint8List.fromList(utf8.encode('line $i\r\n')));
      }

      await tester.pumpWidget(_wrapInApp(terminal: terminal, autofocus: true));
      await tester.pumpAndSettle();

      final center = tester.getCenter(find.byType(TerminalView));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('terminal response forwarded to onOutput', (tester) async {
      final output = <Uint8List>[];

      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, onOutput: output.add),
      );
      await tester.pump();

      terminal.write(Uint8List.fromList(utf8.encode('\x1b[6n')));
      await tester.pump();

      expect(output, isNotEmpty);
    });

    testWidgets('selectAll via controller updates view', (tester) async {
      terminal.write(Uint8List.fromList(utf8.encode('hello world')));
      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      controller.selectAll();
      await tester.pump();

      expect(controller.selection, isNotNull);
      controller.dispose();
    });

    testWidgets('selectAll shortcut works by default', (tester) async {
      terminal.write(Uint8List.fromList(utf8.encode('hello world')));
      final controller = TerminalController();
      await tester.pumpWidget(
        _wrapInApp(terminal: terminal, controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      await _sendSelectAllShortcut(tester);

      expect(controller.selection, isNotNull);
      controller.dispose();
    });

    testWidgets(
      'selectAll shortcut blocked when selectAll not in enabled set',
      (tester) async {
        terminal.write(Uint8List.fromList(utf8.encode('hello world')));
        final controller = TerminalController();
        await tester.pumpWidget(
          _wrapInApp(
            terminal: terminal,
            controller: controller,
            autofocus: true,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {SelectionGesture.drag},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _sendSelectAllShortcut(tester);

        expect(controller.selection, isNull);
        controller.dispose();
      },
    );

    group('virtual mods', () {
      testWidgets('focus loss clears virtual mods', (tester) async {
        final controller = TerminalController();
        await tester.pumpWidget(
          _wrapInApp(
            terminal: terminal,
            controller: controller,
            autofocus: true,
          ),
        );
        await tester.pump();

        controller.toggleMod(Mods.ctrl);
        expect(controller.virtualMods.hasCtrl, isTrue);

        controller.unfocus();
        await tester.pumpAndSettle();

        expect(controller.virtualMods, Mods.none);
        controller.dispose();
      });
    });

    group('mouse cursor', () {
      MouseCursor findMouseCursor(WidgetTester tester) {
        final mouseRegion = tester.widget<MouseRegion>(
          find.descendant(
            of: find.byType(TerminalView),
            matching: find.byType(MouseRegion),
          ),
        );
        return mouseRegion.cursor;
      }

      testWidgets('defaults to text cursor', (tester) async {
        await tester.pumpWidget(_wrapInApp(terminal: terminal));
        expect(findMouseCursor(tester), SystemMouseCursors.text);
      });

      testWidgets('switches to basic when mouse tracking is active', (
        tester,
      ) async {
        await tester.pumpWidget(_wrapInApp(terminal: terminal));
        expect(findMouseCursor(tester), SystemMouseCursors.text);

        terminal.write(Uint8List.fromList(utf8.encode('\x1b[?1000h')));
        await tester.pump();

        expect(findMouseCursor(tester), SystemMouseCursors.basic);
      });

      testWidgets('hides cursor on key input when mouseAutoHide is onInput', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrapInApp(terminal: terminal, autofocus: true),
        );
        await tester.pump();
        expect(findMouseCursor(tester), SystemMouseCursors.text);

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        expect(findMouseCursor(tester), SystemMouseCursors.none);
      });

      testWidgets('shows cursor on mouse hover after hiding', (tester) async {
        await tester.pumpWidget(
          _wrapInApp(terminal: terminal, autofocus: true),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();
        expect(findMouseCursor(tester), SystemMouseCursors.none);

        final center = tester.getCenter(find.byType(TerminalView));
        final gesture = await tester.createGesture(
          kind: PointerDeviceKind.mouse,
        );
        await gesture.addPointer(location: center);
        await gesture.moveTo(center + const Offset(10, 0));
        await tester.pump();

        expect(findMouseCursor(tester), isNot(SystemMouseCursors.none));
        await gesture.removePointer();
      });

      testWidgets('does not hide cursor when mouseAutoHide is never', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrapInApp(
            terminal: terminal,
            autofocus: true,
            mouseAutoHide: MouseAutoHide.never,
          ),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        expect(findMouseCursor(tester), isNot(SystemMouseCursors.none));
      });
    });

    group('paste', () {
      Future<void> mockClipboard(WidgetTester tester, String text) async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.getData') {
              return <String, dynamic>{'text': text};
            }
            return null;
          },
        );
      }

      Future<void> sendPasteShortcut(WidgetTester tester) async {
        switch (defaultTargetPlatform) {
          case TargetPlatform.macOS || TargetPlatform.iOS:
            await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
          case TargetPlatform.linux || TargetPlatform.fuchsia:
            await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
            await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
          case TargetPlatform.windows || TargetPlatform.android:
            await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
            await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
            await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
        }
        await tester.pump();
      }

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      testWidgets('paste shortcut sends clipboard text to onOutput', (
        tester,
      ) async {
        await mockClipboard(tester, 'pasted');
        final output = <Uint8List>[];

        await tester.pumpWidget(
          _wrapInApp(terminal: terminal, autofocus: true, onOutput: output.add),
        );
        await tester.pump();

        await sendPasteShortcut(tester);
        await tester.pumpAndSettle();

        final pasted = output.where((b) => utf8.decode(b).contains('pasted'));
        expect(pasted, isNotEmpty);
      });

      testWidgets('paste wraps with bracketed paste when mode is active', (
        tester,
      ) async {
        terminal.write(Uint8List.fromList(utf8.encode('\x1b[?2004h')));
        await mockClipboard(tester, 'hello');
        final output = <Uint8List>[];

        await tester.pumpWidget(
          _wrapInApp(terminal: terminal, autofocus: true, onOutput: output.add),
        );
        await tester.pump();

        await sendPasteShortcut(tester);
        await tester.pumpAndSettle();

        final pasted = output
            .map((b) => utf8.decode(b))
            .where((s) => s.contains('hello'));
        expect(pasted, isNotEmpty);
        expect(pasted.first, contains('\x1b[200~'));
        expect(pasted.first, contains('\x1b[201~'));
      });

      testWidgets('paste with empty clipboard produces no output', (
        tester,
      ) async {
        await mockClipboard(tester, '');
        final output = <Uint8List>[];

        await tester.pumpWidget(
          _wrapInApp(terminal: terminal, autofocus: true, onOutput: output.add),
        );
        await tester.pump();

        await sendPasteShortcut(tester);
        await tester.pumpAndSettle();

        final pasted = output.where(
          (b) => utf8.decode(b).contains('\x1b[200~'),
        );
        expect(pasted, isEmpty);
      });
    });

    group('mouse selection', () {
      Future<TestGesture> mouseDown(WidgetTester tester, Offset pos) {
        return tester.startGesture(pos, kind: PointerDeviceKind.mouse);
      }

      testWidgets('double click selects word', (tester) async {
        terminal.write(Uint8List.fromList(utf8.encode('hello world')));
        final controller = TerminalController();
        await tester.pumpWidget(
          _wrapInApp(
            terminal: terminal,
            controller: controller,
            autofocus: true,
          ),
        );
        await tester.pumpAndSettle();

        final topLeft = tester.getTopLeft(find.byType(TerminalView));
        final clickPos = topLeft + const Offset(20, 8);

        var gesture = await mouseDown(tester, clickPos);
        await gesture.up();
        gesture = await mouseDown(tester, clickPos);
        await gesture.up();
        await tester.pump();

        expect(controller.selection, isNotNull);
        expect(controller.selectedText, contains('hello'));
        controller.dispose();
      });

      testWidgets('triple click selects entire line', (tester) async {
        terminal.write(Uint8List.fromList(utf8.encode('hello world')));
        final controller = TerminalController();
        await tester.pumpWidget(
          _wrapInApp(
            terminal: terminal,
            controller: controller,
            autofocus: true,
          ),
        );
        await tester.pumpAndSettle();

        final topLeft = tester.getTopLeft(find.byType(TerminalView));
        final clickPos = topLeft + const Offset(20, 8);

        for (var i = 0; i < 3; i++) {
          final gesture = await mouseDown(tester, clickPos);
          await gesture.up();
        }
        await tester.pump();

        final sel = controller.selection;
        expect(sel, isNotNull);
        expect(sel!.startCol, 0);
        expect(controller.selectedText.length, greaterThan('hello'.length));
        controller.dispose();
      });

      testWidgets('mouse drag creates selection', (tester) async {
        terminal.write(Uint8List.fromList(utf8.encode('hello world')));
        final controller = TerminalController();
        await tester.pumpWidget(
          _wrapInApp(
            terminal: terminal,
            controller: controller,
            autofocus: true,
          ),
        );
        await tester.pumpAndSettle();

        final topLeft = tester.getTopLeft(find.byType(TerminalView));
        final start = topLeft + const Offset(10, 8);
        final end = topLeft + const Offset(100, 8);

        final gesture = await mouseDown(tester, start);
        await gesture.moveTo(end);
        await gesture.up();
        await tester.pump();

        expect(controller.selection, isNotNull);
        expect(controller.selectedText, isNotEmpty);
        controller.dispose();
      });
    });

    group('padding', () {
      testWidgets('padding reduces reported grid size', (tester) async {
        final sizes = <TerminalSize>[];

        await tester.pumpWidget(
          _wrapInApp(terminal: terminal, onResize: sizes.add),
        );
        await tester.pumpAndSettle();
        final noPaddingSize = sizes.last;

        sizes.clear();
        await tester.pumpWidget(
          _wrapInApp(
            terminal: terminal,
            padding: const EdgeInsets.all(20),
            onResize: sizes.add,
          ),
        );
        await tester.pumpAndSettle();
        final paddedSize = sizes.last;

        expect(paddedSize.cols, lessThan(noPaddingSize.cols));
        expect(paddedSize.rows, lessThan(noPaddingSize.rows));
      });
    });
  });
}
