@Tags(['ffi'])
library;

import 'dart:typed_data';

import 'package:libghostty/src/bindings/bindings.dart';
import 'package:test/test.dart';

void main() {
  group('native terminal bindings', () {
    late int handle;

    setUp(() {
      handle = bindings.terminalNew(80, 24);
    });

    tearDown(() {
      bindings.terminalFree(handle);
    });

    test('create and free terminal', () {
      expect(handle, isNonZero);
    });

    test('render state dimensions match creation', () {
      bindings.renderStateUpdate(handle);
      expect(bindings.renderStateGetCols(handle), 80);
      expect(bindings.renderStateGetRows(handle), 24);
    });

    test('initial cursor is at origin and visible', () {
      bindings.renderStateUpdate(handle);
      expect(bindings.renderStateGetCursorX(handle), 0);
      expect(bindings.renderStateGetCursorY(handle), 0);
      expect(bindings.renderStateGetCursorVisible(handle), isTrue);
    });

    test('write bytes and read viewport', () {
      bindings.terminalWrite(handle, Uint8List.fromList('Hello'.codeUnits));
      bindings.renderStateUpdate(handle);

      final cells = bindings.renderStateGetViewport(handle, 80, 24);
      expect(cells.length, 80 * 24);

      expect(cells.codepoint(0), 'H'.codeUnitAt(0));
      expect(cells.codepoint(1), 'e'.codeUnitAt(0));
      expect(cells.codepoint(2), 'l'.codeUnitAt(0));
      expect(cells.codepoint(3), 'l'.codeUnitAt(0));
      expect(cells.codepoint(4), 'o'.codeUnitAt(0));
      expect(cells.codepoint(5), 0);
    });

    test('cursor moves after write', () {
      bindings.terminalWrite(handle, Uint8List.fromList('ABC'.codeUnits));
      bindings.renderStateUpdate(handle);
      expect(bindings.renderStateGetCursorX(handle), 3);
      expect(bindings.renderStateGetCursorY(handle), 0);
    });

    test('resize changes dimensions', () {
      bindings.terminalResize(handle, 40, 10);
      bindings.renderStateUpdate(handle);
      expect(bindings.renderStateGetCols(handle), 40);
      expect(bindings.renderStateGetRows(handle), 10);
    });

    test('write returns event flags', () {
      final events = bindings.terminalWrite(handle, .fromList('Hi'.codeUnits));
      expect(events & TerminalEventFlag.repaint, isNonZero);
      expect(events & TerminalEventFlag.bell, isZero);
    });

    test('write returns bell event flag', () {
      final events = bindings.terminalWrite(handle, .fromList([0x07]));
      expect(events & TerminalEventFlag.bell, isNonZero);
    });

    test('write returns title event flag', () {
      const osc = '\x1b]0;Test\x07';
      final events = bindings.terminalWrite(handle, .fromList(osc.codeUnits));
      expect(events & TerminalEventFlag.titleChanged, isNonZero);
    });

    test('bell count incremented by BEL character', () {
      expect(bindings.terminalGetBellCount(handle), 0);
      bindings.terminalWrite(handle, Uint8List.fromList([0x07]));
      expect(bindings.terminalGetBellCount(handle), 1);
      bindings.terminalResetBellCount(handle);
      expect(bindings.terminalGetBellCount(handle), 0);
    });

    test('title change via OSC 0', () {
      expect(bindings.terminalHasTitleChanged(handle), isFalse);
      const osc = '\x1b]0;My Title\x07';
      bindings.terminalWrite(handle, Uint8List.fromList(osc.codeUnits));
      expect(bindings.terminalHasTitleChanged(handle), isTrue);
      expect(bindings.terminalGetTitle(handle), 'My Title');
      expect(bindings.terminalHasTitleChanged(handle), isFalse);
    });

    test('alternate screen mode', () {
      expect(bindings.terminalIsAlternateScreen(handle), isFalse);
      const enterAlt = '\x1b[?1049h';
      bindings.terminalWrite(handle, Uint8List.fromList(enterAlt.codeUnits));
      expect(bindings.terminalIsAlternateScreen(handle), isTrue);
      const exitAlt = '\x1b[?1049l';
      bindings.terminalWrite(handle, Uint8List.fromList(exitAlt.codeUnits));
      expect(bindings.terminalIsAlternateScreen(handle), isFalse);
    });

    test('bold attribute sets flag', () {
      const boldHello = '\x1b[1mHi';
      bindings.terminalWrite(handle, Uint8List.fromList(boldHello.codeUnits));
      bindings.renderStateUpdate(handle);
      final cells = bindings.renderStateGetViewport(handle, 80, 24);
      expect(cells.flags(0) & 1, 1);
      expect(cells.codepoint(0), 'H'.codeUnitAt(0));
    });

    test('create with config sets colors', () {
      const config = RawTerminalConfig(
        fgR: 255,
        fgG: 128,
        fgB: 64,
        fgSet: true,
        bgR: 10,
        bgG: 20,
        bgB: 30,
        bgSet: true,
      );
      final h = bindings.terminalNewWithConfig(80, 24, config);
      try {
        bindings.renderStateUpdate(h);
        final fg = bindings.renderStateGetFgColor(h);
        expect((fg >> 16) & 0xFF, 255);
        expect((fg >> 8) & 0xFF, 128);
        expect(fg & 0xFF, 64);

        final bg = bindings.renderStateGetBgColor(h);
        expect((bg >> 16) & 0xFF, 10);
        expect((bg >> 8) & 0xFF, 20);
        expect(bg & 0xFF, 30);
      } finally {
        bindings.terminalFree(h);
      }
    });

    test('dirty tracking works', () {
      bindings.renderStateUpdate(handle);
      bindings.renderStateMarkClean(handle);

      bindings.terminalWrite(handle, Uint8List.fromList('X'.codeUnits));
      final dirty = bindings.renderStateUpdate(handle);
      expect(dirty, greaterThan(0));
    });

    test('scrollback grows when lines scroll off', () {
      expect(bindings.terminalGetScrollbackLength(handle), 0);

      final lines = List.generate(30, (i) => 'Line $i\n').join();
      bindings.terminalWrite(handle, Uint8List.fromList(lines.codeUnits));

      final scrollback = bindings.terminalGetScrollbackLength(handle);
      expect(scrollback, greaterThan(0));
    });

    test('scrollback line returns cells', () {
      final lines = List.generate(30, (i) => 'L$i\n').join();
      bindings.terminalWrite(handle, Uint8List.fromList(lines.codeUnits));

      final scrollback = bindings.terminalGetScrollbackLength(handle);
      if (scrollback > 0) {
        final line = bindings.terminalGetScrollbackLine(handle, 0, 80);
        expect(line, isNotNull);
        expect(line!.length, 80);
        expect(line.codepoint(0), 'L'.codeUnitAt(0));
      }
    });

    test('viewport hyperlink flag set by OSC 8', () {
      const osc8 = '\x1b]8;;https://example.com\x1b\\Link\x1b]8;;\x1b\\';
      bindings.terminalWrite(handle, Uint8List.fromList(osc8.codeUnits));
      bindings.renderStateUpdate(handle);
      final cells = bindings.renderStateGetViewport(handle, 80, 24);

      expect(cells.hasHyperlink(0), isNonZero);
      expect(cells.hasHyperlink(3), isNonZero);
      expect(cells.hasHyperlink(4), isZero);
    });

    test('renderStateGetHyperlink returns URI', () {
      const osc8 = '\x1b]8;;https://example.com\x1b\\Link\x1b]8;;\x1b\\';
      bindings.terminalWrite(handle, Uint8List.fromList(osc8.codeUnits));
      bindings.renderStateUpdate(handle);

      expect(
        bindings.renderStateGetHyperlink(handle, 0, 0),
        'https://example.com',
      );
      expect(bindings.renderStateGetHyperlink(handle, 0, 4), isNull);
    });

    test('scrollback hyperlink flag set by OSC 8', () {
      const osc8 = '\x1b]8;;https://scroll.test\x1b\\A\x1b]8;;\x1b\\';
      for (var i = 0; i < 30; i++) {
        if (i == 0) {
          bindings.terminalWrite(
            handle,
            Uint8List.fromList('$osc8\n'.codeUnits),
          );
        } else {
          bindings.terminalWrite(
            handle,
            Uint8List.fromList('Line$i\n'.codeUnits),
          );
        }
      }

      final scrollback = bindings.terminalGetScrollbackLength(handle);
      expect(scrollback, greaterThan(0));

      final line = bindings.terminalGetScrollbackLine(handle, 0, 80);
      expect(line, isNotNull);
      expect(line!.hasHyperlink(0), isNonZero);
      expect(line.hasHyperlink(1), isZero);
    });

    test('terminalGetScrollbackHyperlink returns URI', () {
      const osc8 = '\x1b]8;;https://scroll.test\x1b\\A\x1b]8;;\x1b\\';
      for (var i = 0; i < 30; i++) {
        if (i == 0) {
          bindings.terminalWrite(
            handle,
            Uint8List.fromList('$osc8\n'.codeUnits),
          );
        } else {
          bindings.terminalWrite(
            handle,
            Uint8List.fromList('Line$i\n'.codeUnits),
          );
        }
      }

      expect(
        bindings.terminalGetScrollbackHyperlink(handle, 0, 0),
        'https://scroll.test',
      );
      expect(bindings.terminalGetScrollbackHyperlink(handle, 0, 1), isNull);
    });
  });
}
