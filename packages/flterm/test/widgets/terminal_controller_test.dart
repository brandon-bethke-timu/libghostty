@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets.dart';
import 'package:flutter/widgets.dart' hide Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalController', () {
    late TerminalController controller;

    setUp(() {
      controller = TerminalController();
    });

    tearDown(() => controller.dispose());

    test('factory returns a TerminalViewBinding', () {
      expect(controller, isA<TerminalViewBinding>());
    });

    test('initial state has null selection, empty selectedText, no focus', () {
      expect(controller.selection, isNull);
      expect(controller.selectedText, '');
      expect(controller.hasFocus, isFalse);
    });

    test('showKeyboard and hideKeyboard do not throw', () {
      expect(() => controller.showKeyboard(), returnsNormally);
      expect(() => controller.hideKeyboard(), returnsNormally);
    });
  });

  group('TerminalViewBinding', () {
    late TerminalController controller;
    late TerminalViewBinding binding;
    late Terminal terminal;
    late FocusNode focusNode;

    setUp(() {
      controller = TerminalController();
      binding = controller as TerminalViewBinding;
      terminal = Terminal(cols: 80, rows: 24);
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      terminal.dispose();
      focusNode.dispose();
    });

    test('sendText emits bytes via onOutput', () {
      final output = <Uint8List>[];
      binding.onOutput = output.add;

      controller.sendText('hello');

      expect(output, hasLength(1));
      expect(utf8.decode(output.first), 'hello');
    });

    test('sendText with empty string does not emit', () {
      final output = <Uint8List>[];
      binding.onOutput = output.add;

      controller.sendText('');

      expect(output, isEmpty);
    });

    test('sendKey encodes and emits output', () {
      final output = <Uint8List>[];
      binding.onOutput = output.add;

      controller.sendKey(Key.keyA);

      expect(output, hasLength(1));
      expect(utf8.decode(output.first), 'a');
    });

    test('sendKey does not emit when onOutput is null', () {
      controller.sendKey(Key.keyA);
    });

    test('selection setter notifies listeners', () {
      var notified = false;
      controller.addListener(() => notified = true);

      binding.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      expect(notified, isTrue);
      expect(controller.selection, isNotNull);
    });

    test('selection setter does not notify when value unchanged', () {
      const sel = TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );
      binding.selection = sel;

      var notified = false;
      controller.addListener(() => notified = true);

      binding.selection = sel;

      expect(notified, isFalse);
    });

    test('clearSelection notifies only when selection was active', () {
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.clearSelection();
      expect(notifyCount, 0);

      binding.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );
      notifyCount = 0;

      controller.clearSelection();
      expect(notifyCount, 1);
      expect(controller.selection, isNull);
    });

    test('selectAll selects up to last row and col with content', () {
      terminal.write(Uint8List.fromList(utf8.encode('hello\r\nworld')));
      binding.terminal = terminal;

      controller.selectAll();

      final sel = controller.selection!;
      expect(sel.startRow, 0);
      expect(sel.startCol, 0);
      expect(sel.endRow, 1);
      expect(sel.endCol, 5);
    });

    test('selectAll does nothing on empty screen', () {
      binding.terminal = terminal;

      controller.selectAll();

      expect(controller.selection, isNull);
    });

    test('selectAll does nothing when screen is null', () {
      controller.selectAll();
      expect(controller.selection, isNull);
    });

    test('selectAll with single row selects that row only', () {
      terminal.write(Uint8List.fromList(utf8.encode('abc')));
      binding.terminal = terminal;

      controller.selectAll();

      final sel = controller.selection!;
      expect(sel.startRow, 0);
      expect(sel.startCol, 0);
      expect(sel.endRow, 0);
      expect(sel.endCol, 3);
    });

    test('selectedText returns text from screen', () {
      terminal = Terminal(cols: 20, rows: 5);
      terminal.write(Uint8List.fromList(utf8.encode('hello world')));
      binding.terminal = terminal;

      binding.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      expect(controller.selectedText, 'hello');
    });

    test('selectedText excludes spacer tails from wide characters', () {
      terminal = Terminal(cols: 20, rows: 5);
      terminal.write(
        Uint8List.fromList([
          0xE6, 0x97, 0xA5, // 日
          0xE6, 0x9C, 0xAC, // 本
          0xE8, 0xAA, 0x9E, // 語
        ]),
      );
      binding.terminal = terminal;

      binding.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 6,
      );
      expect(controller.selectedText, '日本語');

      // Block mode also excludes spacer tails
      binding.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 6,
        mode: TerminalSelectionMode.block,
      );
      expect(controller.selectedText, '日本語');
    });

    test('selectedText returns empty when screen is null', () {
      binding.selection = const TerminalSelection(
        startRow: 0,
        startCol: 0,
        endRow: 0,
        endCol: 5,
      );

      expect(controller.selectedText, '');
    });

    group('scrollback selection', () {
      late Terminal smallTerminal;

      setUp(() {
        smallTerminal = Terminal(cols: 20, rows: 3);
        binding.terminal = smallTerminal;
      });

      tearDown(() => smallTerminal.dispose());

      void writeLines(List<String> lines) {
        smallTerminal.write(
          Uint8List.fromList(utf8.encode(lines.join('\r\n'))),
        );
      }

      test('selectAll includes scrollback rows', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd', 'eee']);
        final scrollbackLen = smallTerminal.scrollback.length;
        expect(scrollbackLen, 2);

        controller.selectAll();

        final sel = controller.selection!;
        expect(sel.startRow, 0);
        expect(sel.startCol, 0);
        expect(sel.endRow, scrollbackLen + 2);
        expect(sel.endCol, 3);
      });

      test('selectAll with only scrollback content', () {
        writeLines(['aaa', 'bbb', 'ccc', '']);
        final scrollbackLen = smallTerminal.scrollback.length;
        expect(scrollbackLen, greaterThan(0));

        controller.selectAll();

        final sel = controller.selection!;
        expect(sel.startRow, 0);
      });

      test('selectedText handles selection beyond screen bounds', () {
        writeLines(['aaa', 'bbb', 'ccc']);
        binding.selection = const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 99,
          endCol: 20,
        );

        expect(() => controller.selectedText, returnsNormally);
        expect(controller.selectedText, contains('aaa'));
      });

      test('selectedText extracts from scrollback and screen', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd', 'eee']);
        final scrollbackLen = smallTerminal.scrollback.length;
        expect(scrollbackLen, 2);

        controller.selectAll();

        final text = controller.selectedText;
        expect(text, contains('aaa'));
        expect(text, contains('bbb'));
        expect(text, contains('ccc'));
        expect(text, contains('ddd'));
        expect(text, contains('eee'));
      });

      test('selectedText joins wrapped lines without newline', () {
        final wrapTerminal = Terminal(cols: 5, rows: 3);
        addTearDown(wrapTerminal.dispose);
        wrapTerminal.write(Uint8List.fromList(utf8.encode('abcdefgh')));
        binding.terminal = wrapTerminal;

        controller.selectAll();

        final text = controller.selectedText;
        expect(text, 'abcdefgh');
        expect(text, isNot(contains('\n')));
      });

      test('selectedText with wrapped wide characters', () {
        // "A日B日C" on cols=5: row 0 "A日B" (5 cols), row 1 "日C" (3 cols)
        final wt = Terminal(cols: 5, rows: 3);
        addTearDown(wt.dispose);
        wt.write(
          Uint8List.fromList([
            ...utf8.encode('A'),
            0xE6, 0x97, 0xA5, // 日
            ...utf8.encode('B'),
            0xE6, 0x97, 0xA5, // 日
            ...utf8.encode('C'),
          ]),
        );
        binding.terminal = wt;
        controller.selectAll();

        expect(controller.selectedText, 'A日B日C');
      });

      test('selectedText in block mode inserts newlines between rows', () {
        writeLines(['aaaa', 'bbbb', 'cccc']);
        binding.selection = const TerminalSelection(
          startRow: 0,
          startCol: 1,
          endRow: 2,
          endCol: 3,
          mode: TerminalSelectionMode.block,
        );

        final text = controller.selectedText;
        final lines = text.split('\n');
        expect(lines.length, 3);
        expect(lines[0], 'aa');
        expect(lines[1], 'bb');
        expect(lines[2], 'cc');
      });

      test('selectedText with partial scrollback selection', () {
        writeLines(['aaa', 'bbb', 'ccc', 'ddd']);
        expect(smallTerminal.scrollback.length, 1);

        binding.selection = const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 1,
          endCol: 3,
        );

        final text = controller.selectedText;
        expect(text, contains('aaa'));
        expect(text, contains('bbb'));
        expect(text, isNot(contains('ccc')));
      });
    });

    group('clear', () {
      test('emits erase scrollback and form feed', () {
        final output = <Uint8List>[];
        binding.onOutput = output.add;
        binding.terminal = terminal;

        controller.clear();

        expect(output, hasLength(1));
        final decoded = utf8.decode(output.first);
        expect(decoded, '\x0c');
      });

      test('writes erase scrollback to terminal', () {
        binding.terminal = terminal;
        terminal.write(Uint8List.fromList(utf8.encode('hello\r\nworld\r\n')));

        controller.clear();

        expect(terminal.scrollback.length, 0);
      });

      test('does nothing on alternate screen', () {
        final output = <Uint8List>[];
        binding.onOutput = output.add;
        binding.terminal = terminal;
        terminal.write(Uint8List.fromList(utf8.encode('\x1b[?1049h')));

        controller.clear();

        expect(output, isEmpty);
      });

      test('clears selection', () {
        binding.terminal = terminal;
        binding.selection = const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 1,
          endCol: 5,
        );

        controller.clear();

        expect(controller.selection, isNull);
      });
    });

    test('syncModes returns null when modes unchanged', () {
      const modes = TerminalModes();
      binding.syncModes(modes);

      expect(binding.syncModes(modes), isNull);
    });

    test('syncModes returns new tracking mode when changed', () {
      const modes = TerminalModes(mouseTracking: MouseTracking.normal);
      final result = binding.syncModes(modes);

      expect(result, MouseTracking.normal);
    });

    test('syncModes returns null when only non-mouse modes change', () {
      const modes = TerminalModes(cursorKeyApplication: true);
      final result = binding.syncModes(modes);

      expect(result, isNull);
    });

    group('virtual mods', () {
      test('toggleMod activates, deactivates, and combines modifiers', () {
        expect(controller.virtualMods, Mods.none);

        controller.toggleMod(Mods.ctrl);
        expect(controller.virtualMods.hasCtrl, isTrue);

        controller.toggleMod(Mods.alt);
        expect(controller.virtualMods.hasCtrl, isTrue);
        expect(controller.virtualMods.hasAlt, isTrue);

        controller.toggleMod(Mods.ctrl);
        expect(controller.virtualMods.hasCtrl, isFalse);
        expect(controller.virtualMods.hasAlt, isTrue);

        controller.toggleMod(Mods.alt);
        expect(controller.virtualMods, Mods.none);
      });

      test('toggleMod notifies listeners', () {
        var notified = false;
        controller.addListener(() => notified = true);

        controller.toggleMod(Mods.ctrl);

        expect(notified, isTrue);
      });

      test('clearVirtualMods notifies only when mods were active', () {
        var notifyCount = 0;
        controller.addListener(() => notifyCount++);

        controller.clearVirtualMods();
        expect(notifyCount, 0);

        controller.toggleMod(Mods.ctrl);
        notifyCount = 0;

        controller.clearVirtualMods();
        expect(notifyCount, 1);
        expect(controller.virtualMods, Mods.none);
      });

      test('sendKey merges virtual mods', () {
        final output = <Uint8List>[];
        binding.onOutput = output.add;

        controller.toggleMod(Mods.ctrl);
        controller.sendKey(Key.keyC);

        expect(output, hasLength(1));
        expect(output.first, equals(utf8.encode('\x03')));
      });

      test('sendKey clears virtual mods after encoding', () {
        binding.onOutput = (_) {};

        controller.toggleMod(Mods.ctrl);
        controller.sendKey(Key.keyA);

        expect(controller.virtualMods, Mods.none);
      });

      test('sendKey merges explicit and virtual mods', () {
        final output = <Uint8List>[];
        binding.onOutput = output.add;

        controller.toggleMod(Mods.ctrl);
        controller.sendKey(Key.keyC, mods: Mods.shift);

        expect(output, hasLength(1));
        expect(controller.virtualMods, Mods.none);
      });

      test('sendText clears virtual mods', () {
        binding.onOutput = (_) {};

        controller.toggleMod(Mods.ctrl);
        controller.sendText('hello');

        expect(controller.virtualMods, Mods.none);
      });

      test('sendText does not clear when text is empty', () {
        controller.toggleMod(Mods.ctrl);
        controller.sendText('');

        expect(controller.virtualMods.hasCtrl, isTrue);
      });
    });

    group('text input with virtual mods', () {
      late List<Uint8List> output;

      setUp(() {
        output = [];
        binding.onOutput = output.add;
      });

      test('single char commits with mod via sendKey', () {
        controller.toggleMod(Mods.ctrl);

        binding.testCommitText('c');

        expect(output, hasLength(1));
        expect(output.first, equals(utf8.encode('\x03')));
        expect(controller.virtualMods, Mods.none);
      });

      test('multi-char commits as plain text and clears mods', () {
        controller.toggleMod(Mods.ctrl);

        binding.testCommitText('hello');

        expect(output, hasLength(1));
        expect(utf8.decode(output.first), 'hello');
        expect(controller.virtualMods, Mods.none);
      });

      test('unmappable single char commits as plain text and clears mods', () {
        controller.toggleMod(Mods.ctrl);

        binding.testCommitText('\u{1F600}');

        expect(output, hasLength(1));
        expect(controller.virtualMods, Mods.none);
      });
    });
  });
}
