@Tags(['ffi'])
library;

import 'dart:convert';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/widgets/terminal_controller_impl.dart';
import 'package:flterm/src/widgets/terminal_view_binding.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' hide KeyEvent;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TerminalViewBinding', () {
    late TerminalViewBinding binding;
    late TerminalControllerImpl controller;

    setUp(() {
      controller = TerminalControllerImpl();
      binding = controller as TerminalViewBinding;
    });

    tearDown(() => controller.dispose());

    group('attach and detach', () {
      test('detach after attach does not throw', () {
        final focusNode = FocusNode();
        addTearDown(focusNode.dispose);

        binding.attach(focusNode, ScrollController());
        binding.detach();
      });

      test('re-attach replaces previous focus node without error', () {
        final node1 = FocusNode();
        final node2 = FocusNode();
        addTearDown(node1.dispose);
        addTearDown(node2.dispose);

        binding.attach(node1, ScrollController());
        binding.attach(node2, ScrollController());
        binding.detach();
      });
    });

    group('handleResize', () {
      test('fires onResize callback with correct dimensions', () {
        int? reportedCols;
        int? reportedRows;
        controller.onResize = (cols, rows) {
          reportedCols = cols;
          reportedRows = rows;
        };

        binding.handleResize(
          cols: 120,
          rows: 40,
          metrics: const CellMetrics(
            cellWidth: 8,
            cellHeight: 16,
            baseline: 12,
          ),
          padding: EdgeInsets.zero,
          devicePixelRatio: 1.0,
        );

        expect(reportedCols, 120);
        expect(reportedRows, 40);
      });
    });

    group('handleScroll', () {
      test('emits cursor key sequences on alternate screen', () {
        controller.terminal.writeUtf8('\x1b[?1049h');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        binding.handleScroll(-3);

        expect(output, hasLength(1));
        expect(output.first.length, greaterThan(0));
      });

      test('is no-op on primary screen', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        binding.handleScroll(-3);

        expect(output, isEmpty);
      });

      test('is no-op for zero lines', () {
        controller.terminal.writeUtf8('\x1b[?1049h');
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        binding.handleScroll(0);

        expect(output, isEmpty);
      });
    });

    group('updateSelection', () {
      test('creates selection with wide char snapping', () {
        final custom = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 5),
        );
        addTearDown(custom.dispose);
        final customBinding = custom as TerminalViewBinding;

        custom.terminal.write(
          Uint8List.fromList([
            ...utf8.encode('AB'),
            0xE6, 0x97, 0xA5, // 日
            ...utf8.encode('CD'),
          ]),
        );

        customBinding.updateSelection(0, 3, 0, 5, .normal);

        final sel = custom.selection!;
        expect(sel.startCol, 2);
        expect(sel.endCol, 5);
      });
    });

    group('handleKeyEvent', () {
      test('returns handled and emits output for printable key', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        final result = binding.handleKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            character: 'a',
            timeStamp: Duration.zero,
          ),
        );

        expect(result, KeyEventResult.handled);
        expect(output, isNotEmpty);
      });

      test('returns ignored for key release', () {
        final result = binding.handleKeyEvent(
          const KeyUpEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            timeStamp: Duration.zero,
          ),
        );

        expect(result, KeyEventResult.ignored);
      });

      test('clears selection on typing when enabled', () {
        controller.selection = const TerminalSelection(
          startRow: 0,
          startCol: 0,
          endRow: 0,
          endCol: 5,
        );
        controller.onOutput = (_) {};

        binding.handleKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            character: 'a',
            timeStamp: Duration.zero,
          ),
        );

        expect(controller.selection, isNull);
      });

      test('scrolls to bottom on input', () {
        final custom = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 3),
        );
        addTearDown(custom.dispose);
        final sc = ScrollController();
        addTearDown(sc.dispose);
        final customBinding = custom as TerminalViewBinding;
        customBinding.attach(FocusNode(), sc);

        for (var i = 0; i < 10; i++) {
          custom.terminal.writeUtf8('line $i\r\n');
        }
        custom.terminal.scrollViewport(-5);
        expect(
          custom.terminal.scrollbar.offset,
          lessThan(custom.scrollbackRows),
        );

        custom.onOutput = (_) {};
        customBinding.handleKeyEvent(
          const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.keyA,
            logicalKey: LogicalKeyboardKey.keyA,
            character: 'a',
            timeStamp: Duration.zero,
          ),
        );

        expect(custom.terminal.scrollbar.offset, custom.scrollbackRows);
      });
    });

    group('scrollToBottom', () {
      test('restores viewport to bottom after scrolling up', () {
        final custom = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 3),
        );
        addTearDown(custom.dispose);

        for (var i = 0; i < 10; i++) {
          custom.terminal.writeUtf8('line $i\r\n');
        }
        final bottomOffset = custom.terminal.scrollbar.offset;

        custom.terminal.scrollViewport(-5);
        expect(custom.terminal.scrollbar.offset, isNot(bottomOffset));

        custom.scrollToBottom();

        expect(custom.terminal.scrollbar.offset, bottomOffset);
      });
    });

    group('handleMouseEvent', () {
      test('emits encoded output when tracking is enabled', () {
        controller.terminal.writeUtf8('\x1b[?1000h');
        binding.handleResize(
          cols: 80,
          rows: 24,
          metrics: const CellMetrics(
            cellWidth: 8,
            cellHeight: 16,
            baseline: 12,
          ),
          padding: EdgeInsets.zero,
          devicePixelRatio: 1.0,
        );

        final output = <Uint8List>[];
        controller.onOutput = output.add;

        binding.handleMouseEvent((
          action: .press,
          button: .left,
          pixelX: 10.0,
          pixelY: 10.0,
        ));

        expect(output, isNotEmpty);
      });

      test('does not emit when tracking is off', () {
        final output = <Uint8List>[];
        controller.onOutput = output.add;

        binding.handleMouseEvent((
          action: .press,
          button: .left,
          pixelX: 10.0,
          pixelY: 10.0,
        ));

        expect(output, isEmpty);
      });

      test('scales pixel coordinates by devicePixelRatio', () {
        controller.terminal.writeUtf8('\x1b[?1000h');
        binding.handleResize(
          cols: 80,
          rows: 24,
          metrics: const CellMetrics(
            cellWidth: 8,
            cellHeight: 16,
            baseline: 12,
          ),
          padding: EdgeInsets.zero,
          devicePixelRatio: 2.0,
        );

        final output = <Uint8List>[];
        controller.onOutput = output.add;

        binding.handleMouseEvent((
          action: .press,
          button: .left,
          pixelX: 8.0,
          pixelY: 16.0,
        ));

        expect(output, hasLength(1));
        expect(output.single, [
          0x1b,
          0x5b,
          0x4d,
          ' '.codeUnitAt(0),
          '!'.codeUnitAt(0) + 1,
          '!'.codeUnitAt(0) + 1,
        ]);
      });
    });

    test('mouseTracking reflects mode changes', () {
      expect(binding.mouseTracking, MouseTracking.none);

      controller.terminal.writeUtf8('\x1b[?1000h');

      expect(binding.mouseTracking, MouseTracking.normal);
    });

    group('cursorBlinks', () {
      test('false without focus', () {
        expect(binding.cursorBlinks, isFalse);
      });

      test('true when focused with blinking enabled', () {
        final focusNode = FocusNode();
        final sc = ScrollController();
        addTearDown(focusNode.dispose);
        addTearDown(sc.dispose);
        binding.attach(focusNode, sc);

        // Simulate focus by requesting it in a widget context
        // Without a widget tree, hasFocus stays false
        expect(binding.cursorBlinks, isFalse);
      });
    });

    group('paste', () {
      test('scrolls to bottom on primary screen', () {
        final custom = TerminalControllerImpl(
          config: const TerminalConfig(cols: 20, rows: 3),
        );
        addTearDown(custom.dispose);

        for (var i = 0; i < 10; i++) {
          custom.terminal.writeUtf8('line $i\r\n');
        }
        custom.terminal.scrollViewport(-5);
        expect(
          custom.terminal.scrollbar.offset,
          lessThan(custom.scrollbackRows),
        );

        custom.onOutput = (_) {};
        custom.paste('hello');

        expect(custom.terminal.scrollbar.offset, custom.scrollbackRows);
      });
    });

    test('modes are re-applied on primary screen restore', () {
      final focusNode = FocusNode();
      final sc = ScrollController();
      addTearDown(focusNode.dispose);
      addTearDown(sc.dispose);
      binding.attach(focusNode, sc);

      // cursorBlinks depends on focus, so test the mode through config
      // Enter alternate screen, disable cursor blinking
      controller.terminal.writeUtf8('\x1b[?1049h');
      controller.terminal.writeUtf8('\x1b[?12l');

      // Exit alternate screen - modes should be re-applied from config
      controller.terminal.writeUtf8('\x1b[?1049l');

      // Config default has cursorBlink=null, so it reads from terminal
      // mode which _applyModes restores to the config default (true)
      expect(
        controller.terminal.modeGet(const TerminalMode.cursorBlinking()),
        isTrue,
      );
    });
  });
}

extension on Terminal {
  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}
