@Tags(['ffi'])
library;

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

    test('create and free', () {
      expect(terminal, isNonZero);
    });

    test('dimensions match creation', () {
      checkCode(bindings.renderStateUpdate(renderState, terminal));
      expect(bindings.renderStateGetCols(renderState).$2, 80);
      expect(bindings.renderStateGetRows(renderState).$2, 24);
    });

    test('initial cursor at origin and visible', () {
      checkCode(bindings.renderStateUpdate(renderState, terminal));
      expect(bindings.renderStateGetCursorViewportX(renderState).$2, 0);
      expect(bindings.renderStateGetCursorViewportY(renderState).$2, 0);
      expect(bindings.renderStateGetCursorVisible(renderState).$2, isTrue);
    });

    test('write and read cells via row iterator', () {
      bindings.terminalVtWrite(terminal, Uint8List.fromList('Hello'.codeUnits));
      checkCode(bindings.renderStateUpdate(renderState, terminal));

      final (_, rowIter) = bindings.rowIteratorNew();
      final (_, rowCells) = bindings.rowCellsNew();
      checkCode(bindings.rowIteratorInit(rowIter, renderState));

      expect(bindings.rowIteratorNext(rowIter), isTrue);
      checkCode(bindings.rowCellsInit(rowCells, rowIter));

      final codepoints = <int>[];
      while (bindings.rowCellsNext(rowCells)) {
        final (_, rawCell) = bindings.rowCellsGetRawCell(rowCells);
        codepoints.add(bindings.cellGetCodepoint(rawCell).$2);
      }

      expect(String.fromCharCodes(codepoints.take(5)), 'Hello');

      bindings.rowCellsFree(rowCells);
      bindings.rowIteratorFree(rowIter);
    });

    test('cursor moves after write', () {
      bindings.terminalVtWrite(terminal, Uint8List.fromList('ABC'.codeUnits));
      checkCode(bindings.renderStateUpdate(renderState, terminal));
      expect(bindings.renderStateGetCursorViewportX(renderState).$2, 3);
    });

    test('resize changes dimensions', () {
      checkCode(bindings.terminalResize(terminal, 40, 10, 0, 0));
      checkCode(bindings.renderStateUpdate(renderState, terminal));
      expect(bindings.renderStateGetCols(renderState).$2, 40);
      expect(bindings.renderStateGetRows(renderState).$2, 10);
    });

    test('alternate screen via mode', () {
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

    test('dirty tracking', () {
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

    test('render state colors', () {
      checkCode(bindings.renderStateUpdate(renderState, terminal));
      final (_, colors) = bindings.renderStateGetColors(renderState);
      expect(colors.palette.length, 256);
    });

    test('mode get and set', () {
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

    test('reset restores defaults', () {
      bindings.terminalVtWrite(terminal, Uint8List.fromList('Hello'.codeUnits));
      bindings.terminalReset(terminal);
      expect(bindings.terminalGetCursorX(terminal).$2, 0);
      expect(bindings.terminalGetCursorY(terminal).$2, 0);
    });

    test('scrollbar state', () {
      final (_, sb) = bindings.terminalGetScrollbar(terminal);
      expect(sb.visible, greaterThan(0));
    });
  });

  group('key event', () {
    late int event;

    setUp(() {
      final (_, e) = bindings.keyEventNew();
      event = e;
    });
    tearDown(() => bindings.keyEventFree(event));

    test('set and get action', () {
      bindings.keyEventSetAction(event, KeyAction.press);
      expect(bindings.keyEventGetAction(event), KeyAction.press);
    });

    test('set and get key', () {
      bindings.keyEventSetKey(event, Key.a);
      expect(bindings.keyEventGetKey(event), Key.a);
    });

    test('set and get mods', () {
      final mods = const Mods.ctrl().value | const Mods.shift().value;
      bindings.keyEventSetMods(event, mods);
      expect(bindings.keyEventGetMods(event), mods);
    });

    test('set and get consumed mods', () {
      bindings.keyEventSetConsumedMods(event, const Mods.alt().value);
      expect(bindings.keyEventGetConsumedMods(event), const Mods.alt().value);
    });

    test('set and get composing', () {
      bindings.keyEventSetComposing(event, composing: true);
      expect(bindings.keyEventGetComposing(event), isTrue);
    });

    test('set and get utf8', () {
      bindings.keyEventSetUtf8(event, 'a');
      expect(bindings.keyEventGetUtf8(event), 'a');
    });

    test('utf8 null roundtrip', () {
      bindings.keyEventSetUtf8(event, null);
      expect(bindings.keyEventGetUtf8(event), isNull);
    });

    test('set and get unshifted codepoint', () {
      bindings.keyEventSetUnshiftedCodepoint(event, 0x61);
      expect(bindings.keyEventGetUnshiftedCodepoint(event), 0x61);
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

    test('encode Ctrl+C produces ETX', () {
      bindings.keyEventSetAction(event, KeyAction.press);
      bindings.keyEventSetKey(event, Key.c);
      bindings.keyEventSetMods(event, const Mods.ctrl().value);
      final (_, result) = bindings.keyEncoderEncode(encoder, event);
      expect(result, '\x03');
    });

    test('setOptFromTerminal syncs encoder options', () {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      bindings.keyEncoderSetOptFromTerminal(encoder, t);
      bindings.terminalFree(t);
    });
  });

  group('mouse event', () {
    late int event;

    setUp(() {
      final (_, e) = bindings.mouseEventNew();
      event = e;
    });
    tearDown(() => bindings.mouseEventFree(event));

    test('set and get action', () {
      bindings.mouseEventSetAction(event, MouseAction.press);
      expect(bindings.mouseEventGetAction(event), MouseAction.press);
    });

    test('set and get button', () {
      bindings.mouseEventSetButton(event, MouseButton.left);
      final (code, button) = bindings.mouseEventGetButton(event);
      expect(code, Result.success);
      expect(button, MouseButton.left);
    });

    test('clear button', () {
      bindings.mouseEventSetButton(event, MouseButton.left);
      bindings.mouseEventClearButton(event);
      final (code, _) = bindings.mouseEventGetButton(event);
      expect(code, Result.noValue);
    });

    test('set and get mods', () {
      bindings.mouseEventSetMods(event, const Mods.shift().value);
      expect(bindings.mouseEventGetMods(event), const Mods.shift().value);
    });

    test('set and get position', () {
      bindings.mouseEventSetPosition(event, 10.5, 20.5);
      final (x, y) = bindings.mouseEventGetPosition(event);
      expect(x, closeTo(10.5, 0.01));
      expect(y, closeTo(20.5, 0.01));
    });
  });

  group('mouse encoder', () {
    late int encoder;

    setUp(() {
      final (_, enc) = bindings.mouseEncoderNew();
      encoder = enc;
    });
    tearDown(() => bindings.mouseEncoderFree(encoder));

    test('configuration methods accept values without error', () {
      bindings.mouseEncoderReset(encoder);
      bindings.mouseEncoderSetBoolOpt(
        encoder,
        MouseEncoderOption.anyButtonPressed,
        value: true,
      );
      bindings.mouseEncoderSetBoolOpt(
        encoder,
        MouseEncoderOption.trackLastCell,
        value: true,
      );
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
    });

    test('setOptFromTerminal syncs encoder options', () {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      bindings.mouseEncoderSetOptFromTerminal(encoder, t);
      bindings.terminalFree(t);
    });
  });

  group('focus encode', () {
    test('gained encodes as CSI I', () {
      final (_, result) = bindings.focusEncode(FocusEvent.gained);
      expect(result, '\x1b[I');
    });

    test('lost encodes as CSI O', () {
      final (_, result) = bindings.focusEncode(FocusEvent.lost);
      expect(result, '\x1b[O');
    });
  });

  group('paste', () {
    test('safe content returns true', () {
      expect(bindings.pasteIsSafe('hello'), isTrue);
    });

    test('content with newline returns false', () {
      expect(bindings.pasteIsSafe('hello\nworld'), isFalse);
    });
  });

  group('build info', () {
    test('boolean and numeric fields return valid values', () {
      final (_, simd) = bindings.buildInfoBool(BuildInfo.simd);
      expect(simd, isA<bool>());
      final (_, opt) = bindings.buildInfo(BuildInfo.optimize);
      expect(opt, isA<int>());
    });

    test('string fields return valid values', () {
      final (code, version) = bindings.buildInfoString(BuildInfo.versionString);
      expect(code, Result.success);
      expect(version, isNotEmpty);
    });

    test('version number fields return valid values', () {
      final (code, val) = bindings.buildInfo(BuildInfo.versionMajor);
      expect(code, Result.success);
      expect(val, greaterThanOrEqualTo(0));
    });
  });

  group('mode report encode', () {
    test('produces non-empty sequence', () {
      final (_, result) = bindings.modeReportEncode(
        const TerminalMode.cursorKeys().value,
        ModeReportState.set,
      );
      expect(result, isNotEmpty);
    });
  });

  group('size report encode', () {
    test('csi18T encodes text area size in characters', () {
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

  group('style', () {
    test('default style has no colors or flags', () {
      final style = bindings.styleDefault();
      expect(style.bold, isFalse);
      expect(style.italic, isFalse);
      expect(style.foreground, isA<DefaultColor>());
      expect(bindings.styleIsDefault(style), isTrue);
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

    test('grid ref cell returns valid cell', () {
      final (_, ref) = bindings.terminalGridRef(
        terminal,
        PointTag.active,
        0,
        0,
      );
      final (_, cell) = bindings.gridRefCell(ref);
      expect(bindings.cellGetCodepoint(cell).$2, 'H'.codeUnitAt(0));
    });

    test('grid ref row returns valid row', () {
      final (_, ref) = bindings.terminalGridRef(
        terminal,
        PointTag.active,
        0,
        0,
      );
      final (_, row) = bindings.gridRefRow(ref);
      expect(row, isNonZero);
    });

    test('grid ref style reflects bold attribute', () {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      bindings.terminalVtWrite(t, Uint8List.fromList('\x1b[1mBold'.codeUnits));
      final (_, ref) = bindings.terminalGridRef(t, PointTag.active, 0, 0);
      final (_, style) = bindings.gridRefStyle(ref);
      expect(style.bold, isTrue);
      bindings.terminalFree(t);
    });

    test('grid ref graphemes returns codepoints', () {
      final (_, ref) = bindings.terminalGridRef(
        terminal,
        PointTag.active,
        0,
        0,
      );
      final (_, graphemes) = bindings.gridRefGraphemes(ref);
      expect(graphemes, contains('H'.codeUnitAt(0)));
    });
  });

  group('terminal cursor style and mouse tracking', () {
    late int terminal;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
    });

    tearDown(() => bindings.terminalFree(terminal));

    test('cursor style returns default style initially', () {
      final (code, style) = bindings.terminalGetCursorStyle(terminal);
      expect(code, Result.success);
      expect(bindings.styleIsDefault(style), isTrue);
    });

    test('mouse tracking is false initially', () {
      final (code, tracking) = bindings.terminalGetMouseTracking(terminal);
      expect(code, Result.success);
      expect(tracking, isFalse);
    });
  });

  group('kitty image config', () {
    late int terminal;

    setUp(() {
      final (_, t) = bindings.terminalNew(80, 24, 0);
      terminal = t;
    });

    tearDown(() => bindings.terminalFree(terminal));

    test('storage limit getter returns a value or noValue', () {
      final (code, _) = bindings.terminalGetKittyImageStorageLimit(terminal);
      expect(code, anyOf(Result.success, Result.noValue));
    });

    test('medium file getter returns a value or noValue', () {
      final (code, _) = bindings.terminalGetKittyImageMediumFile(terminal);
      expect(code, anyOf(Result.success, Result.noValue));
    });

    test('storage limit can be set', () {
      final result = bindings.terminalSetKittyImageStorageLimit(
        terminal,
        1024 * 1024,
      );
      expect(result, Result.success);
    });

    test('medium file can be toggled', () {
      final result = bindings.terminalSetKittyImageMediumFile(
        terminal,
        enabled: true,
      );
      expect(result, Result.success);
    });

    test('temp file medium getter returns a value or noValue', () {
      final (code, _) = bindings.terminalGetKittyImageMediumTempFile(terminal);
      expect(code, anyOf(Result.success, Result.noValue));
    });

    test('shared mem medium getter returns a value or noValue', () {
      final (code, _) = bindings.terminalGetKittyImageMediumSharedMem(terminal);
      expect(code, anyOf(Result.success, Result.noValue));
    });

    test('temp file medium can be toggled', () {
      final result = bindings.terminalSetKittyImageMediumTempFile(
        terminal,
        enabled: true,
      );
      expect(result, Result.success);
    });

    test('shared mem medium can be toggled', () {
      final result = bindings.terminalSetKittyImageMediumSharedMem(
        terminal,
        enabled: true,
      );
      expect(result, Result.success);
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

    test('returns empty string for cell without hyperlink', () {
      final (_, ref) = bindings.terminalGridRef(
        terminal,
        PointTag.active,
        0,
        0,
      );
      final (code, uri) = bindings.gridRefHyperlinkUri(ref);
      expect(code, Result.success);
      expect(uri, isEmpty);
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

    test('roundtrips active coordinates', () {
      final (_, ref) = bindings.terminalGridRef(
        terminal,
        PointTag.active,
        3,
        0,
      );
      final (code, point) = bindings.terminalPointFromGridRef(
        terminal,
        ref,
        PointTag.active,
      );
      expect(code, Result.success);
      expect(point.col, 3);
      expect(point.row, 0);
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

    test('plain text format', () {
      final (_, formatter) = bindings.formatterTerminalNew(
        terminal,
        FormatterFormat.plain,
        trim: true,
      );
      final (_, result) = bindings.formatterFormat(formatter);
      bindings.formatterFree(formatter);
      expect(result, contains('Hello World'));
    });

    test('vt format preserves content', () {
      final (_, formatter) = bindings.formatterTerminalNew(
        terminal,
        FormatterFormat.vt,
        trim: true,
      );
      final (_, result) = bindings.formatterFormat(formatter);
      bindings.formatterFree(formatter);
      expect(result, contains('Hello World'));
    });

    test('html format produces tags', () {
      bindings.terminalVtWrite(
        terminal,
        Uint8List.fromList('\x1b[1mBold'.codeUnits),
      );
      final (_, formatter) = bindings.formatterTerminalNew(
        terminal,
        FormatterFormat.html,
        trim: true,
      );
      final (_, result) = bindings.formatterFormat(formatter);
      bindings.formatterFree(formatter);
      expect(result.toLowerCase(), contains('<'));
    });

    test('vt format with FormatterExtra includes extra state', () {
      final (_, formatter) = bindings.formatterTerminalNew(
        terminal,
        FormatterFormat.vt,
        extra: const FormatterExtra.all(),
      );
      final (_, withExtras) = bindings.formatterFormat(formatter);
      bindings.formatterFree(formatter);

      final (_, fmtBasic) = bindings.formatterTerminalNew(
        terminal,
        FormatterFormat.vt,
      );
      final (_, withoutExtras) = bindings.formatterFormat(fmtBasic);
      bindings.formatterFree(fmtBasic);

      expect(withExtras.length, greaterThan(withoutExtras.length));
    });
  });
}
