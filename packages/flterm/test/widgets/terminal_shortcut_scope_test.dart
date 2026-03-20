@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

void main() {
  group('TerminalShortcutScope', () {
    late TerminalController controller;
    late TerminalViewBinding binding;

    setUp(() {
      controller = TerminalController();
      binding = controller as TerminalViewBinding;
    });

    tearDown(() => controller.dispose());

    testWidgets('Cmd+C copies selected text to clipboard', (tester) async {
      final terminal = Terminal(cols: 20, rows: 5);
      addTearDown(terminal.dispose);
      terminal.write(Uint8List.fromList(utf8.encode('hello world')));
      binding.terminal = terminal;
      binding.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalShortcutScope(
            controller: controller,
            shortcuts: _macShortcuts(),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _sendCmd(tester, LogicalKeyboardKey.keyC);
      await tester.pump();

      expect(clipboardText, 'hello');
    });

    testWidgets('Cmd+C is disabled when no selection', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalShortcutScope(
            controller: controller,
            shortcuts: _macShortcuts(),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _sendCmd(tester, LogicalKeyboardKey.keyC);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Cmd+V invokes onPaste', (tester) async {
      var pasted = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalShortcutScope(
            controller: controller,
            onPaste: () => pasted = true,
            shortcuts: _macShortcuts(),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _sendCmd(tester, LogicalKeyboardKey.keyV);

      expect(pasted, isTrue);
    });

    testWidgets('Cmd+A selects all terminal content', (tester) async {
      final terminal = Terminal(cols: 20, rows: 5);
      addTearDown(terminal.dispose);
      terminal.write(Uint8List.fromList(utf8.encode('hello')));
      binding.terminal = terminal;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalShortcutScope(
            controller: controller,
            shortcuts: _macShortcuts(),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _sendCmd(tester, LogicalKeyboardKey.keyA);

      expect(controller.selection, isNotNull);
      expect(controller.selectedText, 'hello');
    });

    testWidgets('Cmd+A is disabled when enableSelectAll is false', (
      tester,
    ) async {
      final terminal = Terminal(cols: 20, rows: 5);
      addTearDown(terminal.dispose);
      terminal.write(Uint8List.fromList(utf8.encode('hello')));
      binding.terminal = terminal;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalShortcutScope(
            controller: controller,
            enableSelectAll: false,
            shortcuts: _macShortcuts(),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _sendCmd(tester, LogicalKeyboardKey.keyA);

      expect(controller.selection, isNull);
    });

    testWidgets('null callback does not throw', (tester) async {
      binding.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalShortcutScope(
            controller: controller,
            shortcuts: _macShortcuts(),
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _sendCmd(tester, LogicalKeyboardKey.keyC);

      expect(tester.takeException(), isNull);
    });

    testWidgets('custom shortcuts override defaults', (tester) async {
      var pasted = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: TerminalShortcutScope(
            controller: controller,
            onPaste: () => pasted = true,
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.keyP, control: true):
                  PasteIntent(),
            },
            child: const Focus(autofocus: true, child: SizedBox()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyP);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);

      expect(pasted, isTrue);
    });
  });

  group('TerminalShortcuts', () {
    group('macOS', () {
      late Map<ShortcutActivator, Intent> shortcuts;

      setUp(() {
        shortcuts = TerminalShortcuts.defaultsFor(TargetPlatform.macOS);
      });

      test('Cmd+C maps to CopyIntent', () {
        expect(
          shortcuts[const SingleActivator(LogicalKeyboardKey.keyC, meta: true)],
          isA<CopyIntent>(),
        );
      });

      test('Cmd+V maps to PasteIntent', () {
        expect(
          shortcuts[const SingleActivator(LogicalKeyboardKey.keyV, meta: true)],
          isA<PasteIntent>(),
        );
      });

      test('Cmd+A maps to SelectAllIntent', () {
        expect(
          shortcuts[const SingleActivator(LogicalKeyboardKey.keyA, meta: true)],
          isA<SelectAllIntent>(),
        );
      });

      test('Cmd+K maps to ClearIntent', () {
        expect(
          shortcuts[const SingleActivator(LogicalKeyboardKey.keyK, meta: true)],
          isA<ClearIntent>(),
        );
      });

      test('contains exactly 4 bindings', () {
        expect(shortcuts, hasLength(4));
      });
    });

    group('iOS', () {
      test('matches macOS bindings', () {
        expect(
          TerminalShortcuts.defaultsFor(TargetPlatform.iOS).keys,
          equals(TerminalShortcuts.defaultsFor(TargetPlatform.macOS).keys),
        );
      });
    });

    group('Linux', () {
      late Map<ShortcutActivator, Intent> shortcuts;

      setUp(() {
        shortcuts = TerminalShortcuts.defaultsFor(TargetPlatform.linux);
      });

      test('Ctrl+Shift+C maps to CopyIntent', () {
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyC,
            control: true,
            shift: true,
          )],
          isA<CopyIntent>(),
        );
      });

      test('Ctrl+Shift+V maps to PasteIntent', () {
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyV,
            control: true,
            shift: true,
          )],
          isA<PasteIntent>(),
        );
      });

      test('Ctrl+Shift+K maps to ClearIntent', () {
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyK,
            control: true,
            shift: true,
          )],
          isA<ClearIntent>(),
        );
      });

      test('contains exactly 4 bindings', () {
        expect(shortcuts, hasLength(4));
      });
    });

    group('Windows', () {
      late Map<ShortcutActivator, Intent> shortcuts;

      setUp(() {
        shortcuts = TerminalShortcuts.defaultsFor(TargetPlatform.windows);
      });

      test('Ctrl+C maps to CopyIntent', () {
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyC,
            control: true,
          )],
          isA<CopyIntent>(),
        );
      });

      test('Ctrl+V maps to PasteIntent', () {
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyV,
            control: true,
          )],
          isA<PasteIntent>(),
        );
      });

      test('Ctrl+K maps to ClearIntent', () {
        expect(
          shortcuts[const SingleActivator(
            LogicalKeyboardKey.keyK,
            control: true,
          )],
          isA<ClearIntent>(),
        );
      });

      test('contains exactly 4 bindings', () {
        expect(shortcuts, hasLength(4));
      });
    });

    group('Android', () {
      test('matches Windows bindings', () {
        expect(
          TerminalShortcuts.defaultsFor(TargetPlatform.android).keys,
          equals(TerminalShortcuts.defaultsFor(TargetPlatform.windows).keys),
        );
      });
    });
  });
}

Future<void> _sendCmd(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
}

Map<ShortcutActivator, Intent> _macShortcuts() {
  return const {
    SingleActivator(LogicalKeyboardKey.keyC, meta: true): CopyIntent(),
    SingleActivator(LogicalKeyboardKey.keyV, meta: true): PasteIntent(),
    SingleActivator(LogicalKeyboardKey.keyA, meta: true): SelectAllIntent(),
  };
}
