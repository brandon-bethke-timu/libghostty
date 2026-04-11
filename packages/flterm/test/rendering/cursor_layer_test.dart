@Tags(['ffi', 'golden'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

import '../helpers/font_loader.dart';

void main() {
  group('Cursor goldens', () {
    setUpAll(loadBundledFonts);

    group('cursor shapes', () {
      late Terminal terminal;
      late CellMetrics metrics;

      setUp(() {
        terminal = Terminal(cols: _cols, rows: _rows);
        terminal.writeUtf8('Hello World!\r\n\x1b[1;4H');
        final theme = TerminalTheme.dark().copyWith(
          fontSize: 24.0,
          fontFamilyFallback: bundledFontFamilyFallback,
        );
        metrics = measureCellMetrics(
          fontFamily: theme.fontFamily,
          fontSize: theme.fontSize,
          fontData: jetBrainsMonoBytes,
        );
      });

      tearDown(() => terminal.dispose());

      testWidgets('block cursor', (tester) async {
        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.block),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block.png'),
        );
      });

      testWidgets('block hollow cursor', (tester) async {
        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.blockHollow),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_hollow.png'),
        );
      });

      testWidgets('underline cursor', (tester) async {
        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.underline),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_underline.png'),
        );
      });

      testWidgets('bar cursor', (tester) async {
        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.bar),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_bar.png'),
        );
      });

      testWidgets('cursor with explicit color', (tester) async {
        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.block, color: const Color(0xFF00FF88)),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_custom_color.png'),
        );
      });

      testWidgets('hidden cursor via DECTCEM', (tester) async {
        terminal.writeUtf8('\x1b[?25l');
        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.block),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_hidden.png'),
        );
      });
    });

    group('cursor on inverse text', () {
      late CellMetrics metrics;

      setUp(() {
        final theme = TerminalTheme.dark().copyWith(
          fontSize: 24.0,
          fontFamilyFallback: bundledFontFamilyFallback,
        );
        metrics = measureCellMetrics(
          fontFamily: theme.fontFamily,
          fontSize: theme.fontSize,
          fontData: jetBrainsMonoBytes,
        );
      });

      // SGR 7 = inverse video attribute
      testWidgets('block cursor on inverse text', (tester) async {
        final terminal = Terminal(cols: _cols, rows: _rows);
        addTearDown(terminal.dispose);
        terminal.writeUtf8('\x1b[7mHello\x1b[m World!\r\n\x1b[1;4H');
        terminal.renderState.update();

        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.block),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_inverse.png'),
        );
      });

      // SGR 31 = red foreground, SGR 7 = inverse
      testWidgets('block cursor on colored inverse text', (tester) async {
        final terminal = Terminal(cols: _cols, rows: _rows);
        addTearDown(terminal.dispose);
        terminal.writeUtf8('\x1b[31;7mHello\x1b[m World!\r\n\x1b[1;2H');
        terminal.renderState.update();

        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.block),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_colored_inverse.png'),
        );
      });
    });

    group('cursor on wide characters', () {
      late CellMetrics metrics;

      setUp(() {
        final theme = TerminalTheme.dark().copyWith(
          fontSize: 24.0,
          fontFamilyFallback: bundledFontFamilyFallback,
        );
        metrics = measureCellMetrics(
          fontFamily: theme.fontFamily,
          fontSize: theme.fontSize,
          fontData: jetBrainsMonoBytes,
        );
      });

      void writeEmojiCursorContent(Terminal terminal) {
        terminal.writeRawBytes([
          ...utf8.encode('AB'),
          0xE2, 0x9C, 0x85, // ✅
          ...utf8.encode('CD'),
          ...utf8.encode('\x1b[1;3H'),
        ]);
      }

      testWidgets('block cursor on emoji', (tester) async {
        final terminal = Terminal(cols: _cols, rows: _rows);
        addTearDown(terminal.dispose);
        writeEmojiCursorContent(terminal);

        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.block, fallback: _emojiFallback),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_emoji.png'),
        );
      });

      testWidgets('hollow cursor on emoji', (tester) async {
        final terminal = Terminal(cols: _cols, rows: _rows);
        addTearDown(terminal.dispose);
        writeEmojiCursorContent(terminal);

        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.blockHollow, fallback: _emojiFallback),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_hollow_emoji.png'),
        );
      });

      testWidgets('block cursor on CJK character', (tester) async {
        final terminal = Terminal(cols: _cols, rows: _rows);
        addTearDown(terminal.dispose);
        terminal.writeRawBytes([
          ...utf8.encode('AB'),
          0xE6, 0x97, 0xA5, // 日
          ...utf8.encode('CD'),
          ...utf8.encode('\x1b[1;3H'),
        ]);

        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.block, fallback: _cjkFallback),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_block_wide.png'),
        );
      });

      testWidgets('underline cursor on wide char', (tester) async {
        final terminal = Terminal(cols: _cols, rows: _rows);
        addTearDown(terminal.dispose);
        writeEmojiCursorContent(terminal);

        await _pumpRenderer(
          tester,
          terminal,
          metrics,
          _cursorTheme(CursorShape.underline, fallback: _emojiFallback),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/cursor_underline_emoji.png'),
        );
      });
    });
  });
}

const _cjkFallback = ['Noto Sans JP', 'JetBrains Mono'];
const _cols = 15;
const _emojiFallback = ['Noto Emoji', 'JetBrains Mono'];
const _rows = 3;

TerminalTheme _cursorTheme(
  CursorShape shape, {
  Color? color,
  List<String>? fallback,
}) {
  return TerminalTheme.dark().copyWith(
    fontSize: 24.0,
    fontFamilyFallback: fallback ?? bundledFontFamilyFallback,
    cursor: CursorTheme(
      shape: shape,
      color: color,
      blinkInterval: const Duration(hours: 1),
    ),
  );
}

Future<void> _pumpRenderer(
  WidgetTester tester,
  Terminal terminal,
  CellMetrics metrics,
  TerminalTheme theme,
) async {
  final width = _cols * metrics.cellWidth;
  final height = _rows * metrics.cellHeight;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: height),
          child: TerminalRenderer(
            theme: theme,
            metrics: metrics,
            terminal: terminal,
            offset: ViewportOffset.zero(),
            renderObserver: _TestRenderObserver(),
          ),
        ),
      ),
    ),
  );
}

class _TestRenderObserver implements TerminalRenderObserver {
  @override
  bool get hasFocus => true;

  @override
  TerminalSelection? get selection => null;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

extension on Terminal {
  void writeRawBytes(List<int> bytes) => write(Uint8List.fromList(bytes));

  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}
