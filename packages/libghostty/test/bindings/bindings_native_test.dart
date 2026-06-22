@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:libghostty/libghostty.dart';
import 'package:libghostty/src/bindings/bindings.dart';
import 'package:libghostty/src/ffi/libghostty_enums.g.dart';
import 'package:test/test.dart';

void main() {
  group('terminal', () {
    late int terminal;
    late int renderState;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
      final (_, rs) = bindings.renderStateNew();
      renderState = rs;
    });

    tearDown(() {
      bindings.renderStateFree(renderState);
      bindings.terminalFree(terminal);
    });

    group('terminalNew', () {
      test('returns handle', () {
        expect(terminal, isNonZero);
      });

      test('initializes dimensions', () {
        checkCode(bindings.renderStateUpdate(renderState, terminal));
        expect(bindings.renderStateGetCols(renderState).$2, 80);
        expect(bindings.renderStateGetRows(renderState).$2, 24);
      });

      test('initializes cursor at origin', () {
        checkCode(bindings.renderStateUpdate(renderState, terminal));
        expect(bindings.renderStateGetCursorViewportX(renderState).$2, 0);
        expect(bindings.renderStateGetCursorViewportY(renderState).$2, 0);
        expect(bindings.renderStateGetCursorVisible(renderState).$2, isTrue);
      });
    });

    group('terminalVtWrite', () {
      test('updates row iterator cells', () {
        bindings.terminalVtWrite(
          terminal,
          Uint8List.fromList('Hello'.codeUnits),
        );
        checkCode(bindings.renderStateUpdate(renderState, terminal));

        final text = _firstRowText(renderState);
        expect(text, startsWith('Hello'));
      });

      test('moves cursor', () {
        bindings.terminalVtWrite(terminal, Uint8List.fromList('ABC'.codeUnits));
        checkCode(bindings.renderStateUpdate(renderState, terminal));
        expect(bindings.renderStateGetCursorViewportX(renderState).$2, 3);
      });
    });

    group('terminalResize', () {
      test('updates dimensions', () {
        checkCode(bindings.terminalResize(terminal, 40, 10, 0, 0));
        checkCode(bindings.renderStateUpdate(renderState, terminal));
        expect(bindings.renderStateGetCols(renderState).$2, 40);
        expect(bindings.renderStateGetRows(renderState).$2, 10);
      });
    });

    group('terminalGetActiveScreen', () {
      test('tracks alternate screen mode', () {
        expect(
          bindings.terminalGetActiveScreen(terminal).$2,
          TerminalScreen.primary,
        );
        bindings.terminalVtWrite(
          terminal,
          Uint8List.fromList('\x1b[?1049h'.codeUnits),
        );
        expect(
          bindings.terminalGetActiveScreen(terminal).$2,
          TerminalScreen.alternate,
        );
        bindings.terminalVtWrite(
          terminal,
          Uint8List.fromList('\x1b[?1049l'.codeUnits),
        );
        expect(
          bindings.terminalGetActiveScreen(terminal).$2,
          TerminalScreen.primary,
        );
      });
    });

    group('renderStateGetDirty', () {
      test('reports write dirtiness', () {
        checkCode(bindings.renderStateUpdate(renderState, terminal));
        checkCode(
          bindings.renderStateSetDirty(renderState, RenderStateDirty.false$),
        );

        bindings.terminalVtWrite(terminal, Uint8List.fromList('X'.codeUnits));
        checkCode(bindings.renderStateUpdate(renderState, terminal));
        expect(
          bindings.renderStateGetDirty(renderState).$2,
          isNot(RenderStateDirty.false$),
        );
      });
    });

    group('renderStateGetColors', () {
      test('returns palette', () {
        checkCode(bindings.renderStateUpdate(renderState, terminal));
        final (_, colors) = bindings.renderStateGetColors(renderState);
        expect(colors.palette.length, 256);
      });
    });

    group('terminalModeGet', () {
      test('reflects terminalModeSet value', () {
        expect(
          bindings
              .terminalModeGet(
                terminal,
                const TerminalMode.bracketedPaste().value,
              )
              .$2,
          isFalse,
        );
        checkCode(
          bindings.terminalModeSet(
            terminal,
            const TerminalMode.bracketedPaste().value,
            value: true,
          ),
        );
        expect(
          bindings
              .terminalModeGet(
                terminal,
                const TerminalMode.bracketedPaste().value,
              )
              .$2,
          isTrue,
        );
      });
    });

    group('terminalReset', () {
      test('restores cursor origin', () {
        bindings.terminalVtWrite(
          terminal,
          Uint8List.fromList('Hello'.codeUnits),
        );
        bindings.terminalReset(terminal);
        expect(bindings.terminalGetCursorX(terminal).$2, 0);
        expect(bindings.terminalGetCursorY(terminal).$2, 0);
      });
    });

    group('terminalGetScrollbar', () {
      test('returns visible range', () {
        final (_, sb) = bindings.terminalGetScrollbar(terminal);
        expect(sb.visible, greaterThan(0));
      });
    });

    group('terminalGetViewportActive', () {
      test('returns false after scrollback navigation', () {
        final (_, t) = bindings.terminalNew(5, 2, 100);
        addTearDown(() => bindings.terminalFree(t));
        bindings.terminalVtWrite(
          t,
          Uint8List.fromList('one\r\ntwo\r\nthree'.codeUnits),
        );

        bindings.terminalScrollViewport(t, .delta, -1);

        expect(bindings.terminalGetViewportActive(t).$2, isFalse);
      });
    });
  });

  group('key event', () {
    late int event;

    setUp(() {
      final (_, e) = bindings.keyEventNew();
      event = e;
    });
    tearDown(() => bindings.keyEventFree(event));

    group('accessors', () {
      test('return set scalar values', () {
        bindings.keyEventSetAction(event, KeyAction.press);
        expect(bindings.keyEventGetAction(event), KeyAction.press);

        bindings.keyEventSetKey(event, Key.a);
        expect(bindings.keyEventGetKey(event), Key.a);

        final mods = const Mods.ctrl().value | const Mods.shift().value;
        bindings.keyEventSetMods(event, mods);
        expect(bindings.keyEventGetMods(event), mods);

        bindings.keyEventSetConsumedMods(event, const Mods.alt().value);
        expect(bindings.keyEventGetConsumedMods(event), const Mods.alt().value);

        bindings.keyEventSetComposing(event, composing: true);
        expect(bindings.keyEventGetComposing(event), isTrue);

        bindings.keyEventSetUtf8(event, 'a');
        expect(bindings.keyEventGetUtf8(event), 'a');

        bindings.keyEventSetUnshiftedCodepoint(event, 0x61);
        expect(bindings.keyEventGetUnshiftedCodepoint(event), 0x61);
      });

      test('returns null after utf8 is set to null', () {
        bindings.keyEventSetUtf8(event, null);
        expect(bindings.keyEventGetUtf8(event), isNull);
      });
    });
  });

  group('key encoder', () {
    late int encoder;
    late int event;

    setUp(() {
      final (_, enc) = bindings.keyEncoderNew();
      encoder = enc;
      final (_, ev) = bindings.keyEventNew();
      event = ev;
    });

    tearDown(() {
      bindings.keyEventFree(event);
      bindings.keyEncoderFree(encoder);
    });

    group('keyEncoderEncode', () {
      test('returns ETX for Ctrl+C', () {
        bindings.keyEventSetAction(event, KeyAction.press);
        bindings.keyEventSetKey(event, Key.c);
        bindings.keyEventSetMods(event, const Mods.ctrl().value);
        final (_, result) = bindings.keyEncoderEncode(encoder, event);
        expect(result, '\x03');
      });

      test('uses back-arrow key mode from terminal options', () {
        final (_, t) = bindings.terminalNew(80, 24, 0);
        addTearDown(() => bindings.terminalFree(t));
        checkCode(
          bindings.terminalModeSet(
            t,
            const TerminalMode.backArrowKeyMode().value,
            value: true,
          ),
        );

        bindings.keyEncoderSetOptFromTerminal(encoder, t);
        bindings.keyEventSetAction(event, KeyAction.press);
        bindings.keyEventSetKey(event, Key.backspace);

        final (_, result) = bindings.keyEncoderEncode(encoder, event);
        expect(result, '\x08');
      });
    });
  });

  group('mouse event', () {
    late int event;

    setUp(() {
      final (_, e) = bindings.mouseEventNew();
      event = e;
    });
    tearDown(() => bindings.mouseEventFree(event));

    group('accessors', () {
      test('return set values', () {
        bindings.mouseEventSetAction(event, MouseAction.press);
        expect(bindings.mouseEventGetAction(event), MouseAction.press);

        bindings.mouseEventSetButton(event, MouseButton.left);
        final (code, button) = bindings.mouseEventGetButton(event);
        expect(code, Result.success);
        expect(button, MouseButton.left);

        bindings.mouseEventSetMods(event, const Mods.shift().value);
        expect(bindings.mouseEventGetMods(event), const Mods.shift().value);

        bindings.mouseEventSetPosition(event, 10.5, 20.5);
        final (x, y) = bindings.mouseEventGetPosition(event);
        expect(x, closeTo(10.5, 0.01));
        expect(y, closeTo(20.5, 0.01));
      });

      test('returns noValue after button is cleared', () {
        bindings.mouseEventSetButton(event, MouseButton.left);
        bindings.mouseEventClearButton(event);
        final (code, _) = bindings.mouseEventGetButton(event);
        expect(code, Result.noValue);
      });
    });
  });

  group('mouse encoder', () {
    late int encoder;

    setUp(() {
      final (_, enc) = bindings.mouseEncoderNew();
      encoder = enc;
    });
    tearDown(() => bindings.mouseEncoderFree(encoder));

    group('mouseEncoderEncode', () {
      test('returns press sequence for manual SGR tracking', () {
        final (_, event) = bindings.mouseEventNew();
        addTearDown(() => bindings.mouseEventFree(event));
        bindings.mouseEventSetAction(event, MouseAction.press);
        bindings.mouseEventSetButton(event, MouseButton.left);
        bindings.mouseEventSetPosition(event, 24.0, 32.0);

        bindings.mouseEncoderSetTrackingMode(encoder, MouseTrackingMode.normal);
        bindings.mouseEncoderSetFormat(encoder, MouseFormat.sgr);
        bindings.mouseEncoderSetSize(
          encoder,
          const MouseEncoderSize(
            screenWidth: 640,
            screenHeight: 384,
            cellWidth: 8,
            cellHeight: 16,
          ),
        );

        final (_, result) = bindings.mouseEncoderEncode(encoder, event);
        expect(result, startsWith('\x1b[<'));
        expect(result, endsWith('M'));
      });

      test('uses mouse tracking mode from terminal options', () {
        final (_, t) = bindings.terminalNew(80, 24, 0);
        addTearDown(() => bindings.terminalFree(t));
        bindings.terminalVtWrite(
          t,
          Uint8List.fromList('\x1b[?1000h\x1b[?1006h'.codeUnits),
        );
        bindings.mouseEncoderSetOptFromTerminal(encoder, t);

        final (_, event) = bindings.mouseEventNew();
        addTearDown(() => bindings.mouseEventFree(event));
        bindings.mouseEventSetAction(event, MouseAction.press);
        bindings.mouseEventSetButton(event, MouseButton.left);
        bindings.mouseEventSetPosition(event, 24.0, 32.0);
        bindings.mouseEncoderSetSize(
          encoder,
          const MouseEncoderSize(
            screenWidth: 640,
            screenHeight: 384,
            cellWidth: 8,
            cellHeight: 16,
          ),
        );

        final (_, result) = bindings.mouseEncoderEncode(encoder, event);
        expect(result, startsWith('\x1b[<'));
        expect(result, endsWith('M'));
      });
    });
  });

  group('focusEncode', () {
    group('encode', () {
      test('returns focus sequences', () {
        expect(bindings.focusEncode(FocusEvent.gained).$2, '\x1b[I');
        expect(bindings.focusEncode(FocusEvent.lost).$2, '\x1b[O');
      });
    });
  });

  group('paste', () {
    group('pasteIsSafe', () {
      test('classifies safe and unsafe content', () {
        expect(bindings.pasteIsSafe('hello'), isTrue);
        expect(bindings.pasteIsSafe('hello\nworld'), isFalse);
      });
    });
  });

  group('build info', () {
    group('buildInfoBool', () {
      test('returns boolean fields', () {
        final (_, simd) = bindings.buildInfoBool(BuildInfo.simd);
        expect(simd, isA<bool>());
      });
    });

    group('buildInfo', () {
      test('returns numeric fields', () {
        final (_, opt) = bindings.buildInfo(BuildInfo.optimize);
        expect(opt, isA<int>());

        final (code, val) = bindings.buildInfo(BuildInfo.versionMajor);
        expect(code, Result.success);
        expect(val, greaterThanOrEqualTo(0));
      });
    });

    group('buildInfoString', () {
      test('returns string fields', () {
        final (code, version) = bindings.buildInfoString(
          BuildInfo.versionString,
        );
        expect(code, Result.success);
        expect(version, isNotEmpty);
      });
    });
  });

  group('modeReportEncode', () {
    group('encode', () {
      test('returns sequence', () {
        final (_, result) = bindings.modeReportEncode(
          const TerminalMode.cursorKeys().value,
          ModeReportState.set,
        );
        expect(result, isNotEmpty);
      });
    });
  });

  group('sizeReportEncode', () {
    group('encode', () {
      test('returns text area character report for csi18T', () {
        final (_, result) = bindings.sizeReportEncode(
          SizeReportStyle.csi18T,
          80,
          24,
          8,
          16,
        );
        expect(result, startsWith('\x1b[8;'));
        expect(result, endsWith('t'));
      });
    });
  });

  group('style', () {
    group('styleDefault', () {
      test('returns unstyled default style', () {
        final style = bindings.styleDefault();
        expect(style.bold, isFalse);
        expect(style.italic, isFalse);
        expect(style.foreground, isA<DefaultColor>());
        expect(bindings.styleIsDefault(style), isTrue);
      });
    });
  });

  group('grid ref', () {
    late int terminal;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
      bindings.terminalVtWrite(terminal, Uint8List.fromList('Hello'.codeUnits));
    });

    tearDown(() => bindings.terminalFree(terminal));

    group('handles', () {
      test('return selected cell and row', () {
        final (_, ref) = bindings.terminalGridRef(terminal, .active, 0, 0);

        final (_, cell) = bindings.gridRefCell(ref);
        expect(bindings.cellGetCodepoint(cell).$2, 'H'.codeUnitAt(0));

        final (_, row) = bindings.gridRefRow(ref);
        expect(row, isNonZero);
      });
    });

    group('gridRefStyle', () {
      test('reflects bold attribute', () {
        final (_, t) = bindings.terminalNew(80, 24, 0);
        addTearDown(() => bindings.terminalFree(t));
        bindings.terminalVtWrite(
          t,
          Uint8List.fromList('\x1b[1mBold'.codeUnits),
        );
        final (_, ref) = bindings.terminalGridRef(t, .active, 0, 0);
        final (_, style) = bindings.gridRefStyle(ref);
        expect(style.bold, isTrue);
      });
    });

    group('gridRefGraphemes', () {
      test('returns codepoints', () {
        final (_, ref) = bindings.terminalGridRef(terminal, .active, 0, 0);
        final (_, graphemes) = bindings.gridRefGraphemes(ref);
        expect(graphemes, contains('H'.codeUnitAt(0)));
      });
    });

    group('trackedGridRefSnapshot', () {
      test('returns current tracked cell content', () {
        final (_, tracked) = bindings.terminalGridRefTrack(
          terminal,
          .active,
          1,
          0,
        );
        addTearDown(() => bindings.trackedGridRefFree(tracked));

        final (_, ref) = bindings.trackedGridRefSnapshot(tracked);
        final (_, graphemes) = bindings.gridRefGraphemes(ref);

        expect(graphemes, contains('e'.codeUnitAt(0)));
      });
    });

    group('trackedGridRefPoint', () {
      test('returns tracked coordinates', () {
        final (_, tracked) = bindings.terminalGridRefTrack(
          terminal,
          .active,
          2,
          0,
        );
        addTearDown(() => bindings.trackedGridRefFree(tracked));

        final (_, point) = bindings.trackedGridRefPoint(tracked, .active);

        expect(point, (col: 2, row: 0));
      });
    });

    group('trackedGridRefSet', () {
      test('moves tracked coordinates', () {
        final (_, tracked) = bindings.terminalGridRefTrack(
          terminal,
          .active,
          2,
          0,
        );
        addTearDown(() => bindings.trackedGridRefFree(tracked));

        checkCode(bindings.trackedGridRefSet(tracked, terminal, .active, 3, 0));
        final (_, point) = bindings.trackedGridRefPoint(tracked, .active);

        expect(point, (col: 3, row: 0));
      });
    });
  });

  group('terminal cursor style and mouse tracking', () {
    late int terminal;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
    });

    tearDown(() => bindings.terminalFree(terminal));

    group('getters', () {
      test('return initial values', () {
        final (code, style) = bindings.terminalGetCursorStyle(terminal);
        expect(code, Result.success);
        expect(bindings.styleIsDefault(style), isTrue);

        final (trackingCode, tracking) = bindings.terminalGetMouseTracking(
          terminal,
        );
        expect(trackingCode, Result.success);
        expect(tracking, isFalse);
      });
    });

    group('setters', () {
      test('accept default cursor shape', () {
        final result = bindings.terminalSetDefaultCursorShape(terminal, .bar);
        expect(result, Result.success);
      });

      test('accept default cursor blink', () {
        final result = bindings.terminalSetDefaultCursorBlink(
          terminal,
          blinking: true,
        );
        expect(result, Result.success);
      });

      test('accept glyph protocol toggle', () {
        final result = bindings.terminalSetGlyphProtocol(
          terminal,
          enabled: false,
        );
        expect(result, Result.success);
      });
    });
  });

  group('row iterator data', () {
    group('rowIteratorGetSelection', () {
      test('returns noValue for an unselected row', () {
        final iterator = _selectedRowIterator(0);

        final (code, _) = bindings.rowIteratorGetSelection(iterator);

        expect(code, Result.noValue);
      });

      test('returns selected columns for a selected row', () {
        final iterator = _selectedRowIterator(1);

        final (code, selection) = bindings.rowIteratorGetSelection(iterator);

        expect(code, Result.success);
        expect(selection, (startCol: 1, endCol: 3));
      });
    });
  });

  group('row cells data', () {
    group('rowCellsGetSelected', () {
      test('returns true for a selected cell', () {
        final cells = _selectedRowCells(2);

        final (code, selected) = bindings.rowCellsGetSelected(cells);

        expect(code, Result.success);
        expect(selected, isTrue);
      });

      test('returns true for the selected end column', () {
        final cells = _selectedRowCells(3);

        final (code, selected) = bindings.rowCellsGetSelected(cells);

        expect(code, Result.success);
        expect(selected, isTrue);
      });

      test('returns false for an unselected cell', () {
        final cells = _selectedRowCells(4);

        final (code, selected) = bindings.rowCellsGetSelected(cells);

        expect(code, Result.success);
        expect(selected, isFalse);
      });
    });

    group('rowCellsGetGraphemesUtf8', () {
      test('returns current cell content', () {
        final cells = _firstCellCells('\u00E9');

        final (code, text) = bindings.rowCellsGetGraphemesUtf8(cells);

        expect(code, Result.success);
        expect(text, '\u00E9');
      });
    });

    group('rowCellsGetHasStyling', () {
      test('returns true for styled current cell', () {
        final cells = _firstCellCells('\x1b[1mB');

        final (code, value) = bindings.rowCellsGetHasStyling(cells);

        expect(code, Result.success);
        expect(value, isTrue);
      });
    });
  });

  group('kitty image config', () {
    late int terminal;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
    });

    tearDown(() => bindings.terminalFree(terminal));

    group('getters', () {
      test('return success or noValue', () {
        final (code, _) = bindings.terminalGetKittyImageStorageLimit(terminal);
        expect(code, anyOf(Result.success, Result.noValue));

        final (fileCode, _) = bindings.terminalGetKittyImageMediumFile(
          terminal,
        );
        expect(fileCode, anyOf(Result.success, Result.noValue));

        final (tempFileCode, _) = bindings.terminalGetKittyImageMediumTempFile(
          terminal,
        );
        expect(tempFileCode, anyOf(Result.success, Result.noValue));

        final (sharedMemCode, _) = bindings
            .terminalGetKittyImageMediumSharedMem(terminal);
        expect(sharedMemCode, anyOf(Result.success, Result.noValue));
      });
    });

    group('setters', () {
      test('accept values', () {
        expect(
          bindings.terminalSetKittyImageStorageLimit(terminal, 1024 * 1024),
          Result.success,
        );
        expect(
          bindings.terminalSetKittyImageMediumFile(terminal, enabled: true),
          Result.success,
        );
        expect(
          bindings.terminalSetKittyImageMediumTempFile(terminal, enabled: true),
          Result.success,
        );
        expect(
          bindings.terminalSetKittyImageMediumSharedMem(
            terminal,
            enabled: true,
          ),
          Result.success,
        );
      });
    });
  });

  group('grid ref hyperlink uri', () {
    late int terminal;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
      bindings.terminalVtWrite(terminal, Uint8List.fromList('Hello'.codeUnits));
    });

    tearDown(() => bindings.terminalFree(terminal));

    group('gridRefHyperlinkUri', () {
      test('returns empty string for cell without hyperlink', () {
        final (_, ref) = bindings.terminalGridRef(terminal, .active, 0, 0);
        final (code, uri) = bindings.gridRefHyperlinkUri(ref);
        expect(code, Result.success);
        expect(uri, isEmpty);
      });
    });
  });

  group('terminal point from grid ref', () {
    late int terminal;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
      bindings.terminalVtWrite(terminal, Uint8List.fromList('Hello'.codeUnits));
    });

    tearDown(() => bindings.terminalFree(terminal));

    group('terminalPointFromGridRef', () {
      test('roundtrips active coordinates', () {
        final (_, ref) = bindings.terminalGridRef(terminal, .active, 3, 0);
        final (code, point) = bindings.terminalPointFromGridRef(
          terminal,
          ref,
          .active,
        );
        expect(code, Result.success);
        expect(point.col, 3);
        expect(point.row, 0);
      });
    });
  });

  group('formatter', () {
    late int terminal;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
      bindings.terminalVtWrite(
        terminal,
        Uint8List.fromList('Hello World'.codeUnits),
      );
    });

    tearDown(() => bindings.terminalFree(terminal));

    group('formatterFormat', () {
      test('returns terminal content for plain format', () {
        final (_, formatter) = bindings.formatterTerminalNew(
          terminal,
          .plain,
          trim: true,
        );
        addTearDown(() => bindings.formatterFree(formatter));
        final (_, result) = bindings.formatterFormat(formatter);
        expect(result, contains('Hello World'));
      });

      test('preserves content for vt format', () {
        final (_, formatter) = bindings.formatterTerminalNew(
          terminal,
          .vt,
          trim: true,
        );
        addTearDown(() => bindings.formatterFree(formatter));
        final (_, result) = bindings.formatterFormat(formatter);
        expect(result, contains('Hello World'));
      });

      test('returns tags for html format', () {
        bindings.terminalVtWrite(
          terminal,
          Uint8List.fromList('\x1b[1mBold'.codeUnits),
        );
        final (_, formatter) = bindings.formatterTerminalNew(
          terminal,
          .html,
          trim: true,
        );
        addTearDown(() => bindings.formatterFree(formatter));
        final (_, result) = bindings.formatterFormat(formatter);
        expect(result.toLowerCase(), contains('<'));
      });

      test('includes extra state for FormatterExtra', () {
        final (_, formatter) = bindings.formatterTerminalNew(
          terminal,
          .vt,
          extra: const FormatterExtra.all(),
        );
        addTearDown(() => bindings.formatterFree(formatter));
        final (_, withExtras) = bindings.formatterFormat(formatter);

        final (_, fmtBasic) = bindings.formatterTerminalNew(terminal, .vt);
        addTearDown(() => bindings.formatterFree(fmtBasic));
        final (_, withoutExtras) = bindings.formatterFormat(fmtBasic);

        expect(withExtras.length, greaterThan(withoutExtras.length));
      });

      test('restricts output to selection', () {
        final (_, t) = bindings.terminalNew(80, 24, 0);
        addTearDown(() => bindings.terminalFree(t));
        bindings.terminalVtWrite(
          t,
          Uint8List.fromList('ABCDE\r\nFGHIJ'.codeUnits),
        );
        final (_, startRef) = bindings.terminalGridRef(t, .active, 0, 0);
        final (_, endRef) = bindings.terminalGridRef(t, .active, 2, 0);
        final (_, formatter) = bindings.formatterTerminalNew(
          t,
          .plain,
          selection: (start: startRef, end: endRef, rectangle: false),
        );
        addTearDown(() => bindings.formatterFree(formatter));
        final (_, text) = bindings.formatterFormat(formatter);
        expect(text, contains('ABC'));
        expect(text, isNot(contains('FGHIJ')));
      });
    });
  });
}

String _firstRowText(int renderState) {
  final (_, rowIter) = bindings.rowIteratorNew();
  final (_, rowCells) = bindings.rowCellsNew();
  addTearDown(() => bindings.rowCellsFree(rowCells));
  addTearDown(() => bindings.rowIteratorFree(rowIter));
  checkCode(bindings.rowIteratorInit(rowIter, renderState));

  expect(bindings.rowIteratorNext(rowIter), isTrue);
  checkCode(bindings.rowCellsInit(rowCells, rowIter));

  final codepoints = <int>[];
  while (bindings.rowCellsNext(rowCells)) {
    final (_, rawCell) = bindings.rowCellsGetRawCell(rowCells);
    codepoints.add(bindings.cellGetCodepoint(rawCell).$2);
  }

  return String.fromCharCodes(codepoints);
}

int _firstCellCells(String text) {
  final (_, terminal) = bindings.terminalNew(80, 24, 0);
  final (_, renderState) = bindings.renderStateNew();
  final (_, rowIter) = bindings.rowIteratorNew();
  final (_, rowCells) = bindings.rowCellsNew();
  addTearDown(() => bindings.rowCellsFree(rowCells));
  addTearDown(() => bindings.rowIteratorFree(rowIter));
  addTearDown(() => bindings.renderStateFree(renderState));
  addTearDown(() => bindings.terminalFree(terminal));
  bindings.terminalVtWrite(terminal, Uint8List.fromList(utf8.encode(text)));
  checkCode(bindings.renderStateUpdate(renderState, terminal));
  checkCode(bindings.rowIteratorInit(rowIter, renderState));
  expect(bindings.rowIteratorNext(rowIter), isTrue);
  checkCode(bindings.rowCellsInit(rowCells, rowIter));
  expect(bindings.rowCellsNext(rowCells), isTrue);
  return rowCells;
}

int _selectedRowIterator(int row) {
  final (_, terminal) = bindings.terminalNew(10, 3, 0);
  final (_, renderState) = bindings.renderStateNew();
  final (_, rowIter) = bindings.rowIteratorNew();
  addTearDown(() => bindings.rowIteratorFree(rowIter));
  addTearDown(() => bindings.renderStateFree(renderState));
  addTearDown(() => bindings.terminalFree(terminal));
  bindings.terminalVtWrite(
    terminal,
    Uint8List.fromList('ABCDE\r\nFGHIJ'.codeUnits),
  );
  final (_, start) = bindings.terminalGridRef(terminal, .active, 1, 1);
  final (_, end) = bindings.terminalGridRef(terminal, .active, 3, 1);
  checkCode(
    bindings.terminalSetSelection(terminal, (
      start: start,
      end: end,
      rectangle: false,
    )),
  );
  checkCode(bindings.renderStateUpdate(renderState, terminal));
  checkCode(bindings.rowIteratorInit(rowIter, renderState));
  for (var i = 0; i <= row; i++) {
    expect(bindings.rowIteratorNext(rowIter), isTrue);
  }
  return rowIter;
}

int _selectedRowCells(int col) {
  final (_, terminal) = bindings.terminalNew(10, 3, 0);
  final (_, renderState) = bindings.renderStateNew();
  final (_, rowIter) = bindings.rowIteratorNew();
  final (_, rowCells) = bindings.rowCellsNew();
  addTearDown(() => bindings.rowCellsFree(rowCells));
  addTearDown(() => bindings.rowIteratorFree(rowIter));
  addTearDown(() => bindings.renderStateFree(renderState));
  addTearDown(() => bindings.terminalFree(terminal));
  bindings.terminalVtWrite(
    terminal,
    Uint8List.fromList('ABCDE\r\nFGHIJ'.codeUnits),
  );
  final (_, start) = bindings.terminalGridRef(terminal, .active, 1, 1);
  final (_, end) = bindings.terminalGridRef(terminal, .active, 3, 1);
  checkCode(
    bindings.terminalSetSelection(terminal, (
      start: start,
      end: end,
      rectangle: false,
    )),
  );
  checkCode(bindings.renderStateUpdate(renderState, terminal));
  checkCode(bindings.rowIteratorInit(rowIter, renderState));
  expect(bindings.rowIteratorNext(rowIter), isTrue);
  expect(bindings.rowIteratorNext(rowIter), isTrue);
  checkCode(bindings.rowCellsInit(rowCells, rowIter));
  checkCode(bindings.rowCellsSelect(rowCells, col));
  return rowCells;
}
