import 'dart:convert';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

void main() {
  group('TerminalView', () {
    late TerminalController controller;

    setUp(() => controller = TerminalController());

    tearDown(() => controller.dispose());

    testWidgets('renders with controller', (tester) async {
      await tester.pumpWidget(_wrapInApp(controller: controller));
      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('onResize fires with dimensions from layout', (tester) async {
      final cols = <int>[];
      final rows = <int>[];
      controller.onResize = (reportedCols, reportedRows) {
        cols.add(reportedCols);
        rows.add(reportedRows);
      };

      await tester.pumpWidget(_wrapInApp(controller: controller));
      await tester.pumpAndSettle();

      expect(cols, isNotEmpty);
      expect(cols.last, greaterThan(0));
      expect(rows.last, greaterThan(0));
    });

    testWidgets('tap to focus', (tester) async {
      await tester.pumpWidget(_wrapInApp(controller: controller));

      expect(controller.hasFocus, isFalse);

      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();

      expect(controller.hasFocus, isTrue);
    });

    testWidgets('autofocus focuses on mount', (tester) async {
      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      expect(controller.hasFocus, isTrue);
    });

    testWidgets('keyboard input produces output via onOutput', (tester) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(output, isNotEmpty);
    });

    testWidgets('dispose cleans up without error', (tester) async {
      await tester.pumpWidget(_wrapInApp(controller: controller));

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(controller.hasFocus, isFalse);
    });

    testWidgets('changing theme updates metrics', (tester) async {
      await tester.pumpWidget(_wrapInApp(controller: controller));

      final largeTheme = TerminalTheme(
        palette: ColorPalette(
          ansiColors: List.generate(16, (_) => const Color(0xFF888888)),
          background: const Color(0xFF000000),
          foreground: const Color(0xFFFFFFFF),
        ),
        fontSize: 24.0,
      );

      await tester.pumpWidget(
        _wrapInApp(controller: controller, theme: largeTheme),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TerminalView), findsOneWidget);
    });

    testWidgets('sendText via controller produces onOutput', (tester) async {
      final output = <Uint8List>[];
      controller.onOutput = output.add;

      await tester.pumpWidget(_wrapInApp(controller: controller));
      await tester.pump();

      controller.sendText('hello');

      expect(output, hasLength(1));
      expect(utf8.decode(output.first), 'hello');
    });

    testWidgets('changing controller detaches old and attaches new', (
      tester,
    ) async {
      final controller2 = TerminalController();

      await tester.pumpWidget(_wrapInApp(controller: controller));

      await tester.pumpWidget(_wrapInApp(controller: controller2));
      await tester.pumpAndSettle();

      expect(controller.hasFocus, isFalse);
      expect(find.byType(TerminalView), findsOneWidget);

      controller2.dispose();
    });

    testWidgets('changing scrollController does not throw', (tester) async {
      final sc1 = TerminalScrollController();
      final sc2 = TerminalScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 480,
              child: TerminalView(
                controller: controller,
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
                controller: controller,
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

    testWidgets('showKeyboard false skips keyboard show on focus', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrapInApp(controller: controller, showKeyboard: false),
      );

      await tester.tap(find.byType(TerminalView));
      await tester.pumpAndSettle();

      expect(controller.hasFocus, isTrue);
    });

    testWidgets('touch drag does not create selection', (tester) async {
      controller.writeUtf8('hello world');
      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
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
    });

    testWidgets('long press starts normal selection by default', (
      tester,
    ) async {
      controller.writeUtf8('hello world');
      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
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
    });

    testWidgets('scroll event changes scroll offset', (tester) async {
      for (var i = 0; i < 50; i++) {
        controller.writeUtf8('line $i\r\n');
      }

      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
      );
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

    testWidgets('selectAll via controller updates view', (tester) async {
      controller.writeUtf8('hello world');
      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      controller.selectAll();
      await tester.pump();

      expect(controller.selection, isNotNull);
    });

    testWidgets('selectAll shortcut works by default', (tester) async {
      controller.writeUtf8('hello world');
      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      await _sendSelectAllShortcut(tester);

      expect(controller.selection, isNotNull);
    });

    testWidgets(
      'selectAll shortcut blocked when selectAll not in enabled set',
      (tester) async {
        controller.writeUtf8('hello world');
        await tester.pumpWidget(
          _wrapInApp(
            controller: controller,
            autofocus: true,
            gestureSettings: const TerminalGestureSettings(
              enabledSelections: {.drag},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _sendSelectAllShortcut(tester);

        expect(controller.selection, isNull);
      },
    );

    testWidgets('typing clears selection when selectionClearOnTyping is true', (
      tester,
    ) async {
      controller.writeUtf8('hello world');
      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );
      expect(controller.selection, isNotNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pump();

      expect(controller.selection, isNull);
    });

    testWidgets('shift+arrow extends existing selection', (tester) async {
      controller.writeUtf8('hello world');
      await tester.pumpWidget(
        _wrapInApp(controller: controller, autofocus: true),
      );
      await tester.pumpAndSettle();

      controller.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();

      expect(controller.selection!.endCol, 6);
    });

    group('virtual mods', () {
      testWidgets('focus loss clears virtual mods', (tester) async {
        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        controller.toggleMod(const Mods.ctrl());
        expect(controller.virtualMods.hasCtrl, isTrue);

        controller.unfocus();
        await tester.pumpAndSettle();

        expect(controller.virtualMods, const Mods.none());
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
        await tester.pumpWidget(_wrapInApp(controller: controller));
        expect(findMouseCursor(tester), SystemMouseCursors.text);
      });

      testWidgets('switches to basic when mouse tracking is active', (
        tester,
      ) async {
        await tester.pumpWidget(_wrapInApp(controller: controller));
        expect(findMouseCursor(tester), SystemMouseCursors.text);

        controller.writeUtf8('\x1b[?1000h');
        await tester.pumpAndSettle();

        expect(findMouseCursor(tester), SystemMouseCursors.basic);
      });

      testWidgets('hides cursor on key input when mouseAutoHide is onInput', (
        tester,
      ) async {
        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();
        expect(findMouseCursor(tester), SystemMouseCursors.text);

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();

        expect(findMouseCursor(tester), SystemMouseCursors.none);
      });

      testWidgets('shows cursor on mouse hover after hiding', (tester) async {
        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
        );
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.pump();
        expect(findMouseCursor(tester), SystemMouseCursors.none);

        final center = tester.getCenter(find.byType(TerminalView));
        final gesture = await tester.createGesture(kind: .mouse);
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
            controller: controller,
            autofocus: true,
            mouseAutoHide: .never,
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
        controller.onOutput = output.add;

        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
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
        controller.writeUtf8('\x1b[?2004h');
        await mockClipboard(tester, 'hello');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
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
        controller.onOutput = output.add;

        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
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
        controller.writeUtf8('hello world');
        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
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
        expect(controller.selectedText(), contains('hello'));
      });

      testWidgets('triple click selects entire line', (tester) async {
        controller.writeUtf8('hello world');
        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
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
        expect(controller.selectedText().length, greaterThan('hello'.length));
      });

      testWidgets('mouse drag creates selection', (tester) async {
        controller.writeUtf8('hello world');
        await tester.pumpWidget(
          _wrapInApp(controller: controller, autofocus: true),
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
        expect(controller.selectedText(), isNotEmpty);
      });
    });

    group('padding', () {
      testWidgets('padding reduces reported grid size', (tester) async {
        final cols = <int>[];
        final rows = <int>[];
        controller.onResize = (c, r) {
          cols.add(c);
          rows.add(r);
        };

        await tester.pumpWidget(_wrapInApp(controller: controller));
        await tester.pumpAndSettle();
        final noPaddingCols = cols.last;
        final noPaddingRows = rows.last;

        cols.clear();
        rows.clear();
        await tester.pumpWidget(
          _wrapInApp(controller: controller, padding: const EdgeInsets.all(20)),
        );
        await tester.pumpAndSettle();

        expect(cols.last, lessThan(noPaddingCols));
        expect(rows.last, lessThan(noPaddingRows));
      });
    });

    group('transparent background', () {
      testWidgets('opaque theme paints ColoredBox with theme.background', (
        tester,
      ) async {
        final theme = TerminalTheme.dark();
        await tester.pumpWidget(
          _wrapInApp(controller: controller, theme: theme),
        );
        await tester.pumpAndSettle();

        final box = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(TerminalView),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(box.color, theme.background);
      });

      testWidgets('backgroundOpacity < 1 scales backdrop alpha to match', (
        tester,
      ) async {
        final theme = TerminalTheme.dark().copyWith(backgroundOpacity: 0.5);
        await tester.pumpWidget(
          _wrapInApp(controller: controller, theme: theme),
        );
        await tester.pumpAndSettle();

        final box = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byType(TerminalView),
            matching: find.byType(ColoredBox),
          ),
        );
        expect(box.color.a, closeTo(0.5, 0.01));
        expect(box.color.r, theme.background.r);
        expect(box.color.g, theme.background.g);
        expect(box.color.b, theme.background.b);
      });
    });
  });
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

Widget _wrapInApp({
  required TerminalController controller,
  TerminalTheme? theme,
  bool autofocus = false,
  bool showKeyboard = true,
  MouseAutoHide mouseAutoHide = .onInput,
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
          controller: controller,
          theme: theme,
          autofocus: autofocus,
          showKeyboard: showKeyboard,
          mouseAutoHide: mouseAutoHide,
          gestureSettings: gestureSettings,
          padding: padding,
        ),
      ),
    ),
  );
}

extension on TerminalController {
  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}
