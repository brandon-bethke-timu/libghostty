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
  setUpAll(loadBundledFonts);

  group('TerminalRenderer goldens', () {
    final theme = TerminalTheme.dark().copyWith(
      fontSize: 24.0,
      fontFamilyFallback: bundledFontFamilyFallback,
    );
    late Terminal terminal;
    late CellMetrics goldenMetrics;

    setUp(() {
      terminal = Terminal(cols: _cols, rows: _rows);
      goldenMetrics = measureCellMetrics(
        fontFamily: theme.fontFamily,
        fontSize: theme.fontSize,
        fontData: jetBrainsMonoBytes,
      );
    });

    tearDown(() => terminal.dispose());

    Future<void> pump(
      WidgetTester tester, {
      TerminalTheme? overrideTheme,
      TerminalSelection? selection,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        _wrap(
          terminal,
          theme: overrideTheme ?? theme,
          selection: selection,
          metrics: goldenMetrics,
        ),
      );
    }

    group('text rendering', () {
      testWidgets('text styles', (tester) async {
        // Each row demonstrates one text attribute. Inspect for:
        //  1. Normal: baseline glyph shapes
        //  2. Bold: heavier strokes, same baseline
        //  3. Italic: slanted glyphs, no right-edge clipping
        //  4. Faint: reduced opacity (~50%)
        //  5. Inverse: swapped fg/bg colors
        //  6. BG color: green background behind text
        //  7. Ligatures: => ≠ ≡≡≡ shaped as single glyphs
        const cols = 25;
        const rows = 7;
        final terminal = Terminal(cols: cols, rows: rows);
        terminal.writeUtf8(
          'Normal text\r\n'
          '\x1b[1mBold text\x1b[0m\r\n'
          '\x1b[3mItalic text\x1b[0m\r\n'
          '\x1b[2mFaint text\x1b[0m\r\n'
          '\x1b[7mInverse text\x1b[0m\r\n'
          '\x1b[42;30m BG color \x1b[0m\r\n'
          'a => b != c === d',
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          _wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_styles.png'),
        );
        terminal.dispose();
      });
    });

    group('text decorations', () {
      testWidgets('decoration styles', (tester) async {
        // Each row demonstrates one decoration type. Inspect for:
        //  1-5. Underline variants: line below text, no overlap
        //  6. Colored underline: red (#FF5050) line
        //  7. Strikethrough: centered horizontal line through text
        //  8. Overline: line at cell top edge
        //  9. Combined: underline + strikethrough together
        // 10. Italic underline: decoration under slanted text
        // 11. Italic curly: wavy line under slanted text
        // 12. Italic double: two lines under slanted text
        const cols = 25;
        const rows = 12;
        final terminal = Terminal(cols: cols, rows: rows);
        terminal.writeUtf8(
          '\x1b[4mSingle underline\x1b[0m\r\n'
          '\x1b[4:2mDouble underline\x1b[0m\r\n'
          '\x1b[4:3mCurly underline\x1b[0m\r\n'
          '\x1b[4:4mDotted underline\x1b[0m\r\n'
          '\x1b[4:5mDashed underline\x1b[0m\r\n'
          '\x1b[4m\x1b[58;2;255;80;80mColored underline\x1b[0m\r\n'
          '\x1b[9mStrikethrough\x1b[0m\r\n'
          '\x1b[53mOverline\x1b[0m\r\n'
          '\x1b[4;9mUnder+Strike\x1b[0m\r\n'
          '\x1b[3;4mItalic underline\x1b[0m\r\n'
          '\x1b[3;4:3mItalic curly\x1b[0m\r\n'
          '\x1b[3;4:2mItalic double\x1b[0m',
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          _wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_decorations.png'),
        );
        terminal.dispose();
      });
    });

    group('wide characters', () {
      testWidgets('CJK mixed with ASCII', (tester) async {
        // Row 1: ASCII label + CJK chars (日本語) in double-width cells.
        // Row 2: interleaved ASCII and CJK to verify grid alignment.
        final cjk24 = _cjkTheme.copyWith(fontSize: 24.0);
        final cjkMetrics = measureCellMetrics(
          fontFamily: cjk24.fontFamily,
          fontSize: cjk24.fontSize,
          fontData: jetBrainsMonoBytes,
        );
        const cols = 25;
        const rows = 2;
        final terminal = Terminal(cols: cols, rows: rows);
        terminal.write(
          Uint8List.fromList([
            0x57, 0x69, 0x64, 0x65, 0x3A, 0x20, // 'Wide: '
            0xE6, 0x97, 0xA5, // 日
            0xE6, 0x9C, 0xAC, // 本
            0xE8, 0xAA, 0x9E, // 語
            0x0D, 0x0A, // \r\n
            ...utf8.encode('A'),
            0xE6, 0x97, 0xA5, // 日
            ...utf8.encode('B'),
            0xE6, 0x9C, 0xAC, // 本
            ...utf8.encode('C'),
          ]),
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          _wrap(
            terminal,
            theme: cjk24,
            metrics: cjkMetrics,
            maxWidth: cols * cjkMetrics.cellWidth,
            maxHeight: rows * cjkMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_wide_cjk.png'),
        );
        terminal.dispose();
      });

      testWidgets('emoji mixed with ASCII', (tester) async {
        // Row 1: OK✅NO❌ (emoji adjacent to ASCII).
        // Row 2: alternating A✅B❌C✅D to verify no text drift.
        final emoji24 = _emojiTheme.copyWith(fontSize: 24.0);
        final emojiMetrics = measureCellMetrics(
          fontFamily: emoji24.fontFamily,
          fontSize: emoji24.fontSize,
          fontData: jetBrainsMonoBytes,
        );
        const cols = 25;
        const rows = 2;
        final terminal = Terminal(cols: cols, rows: rows);
        terminal.write(
          Uint8List.fromList([
            ...utf8.encode('OK'),
            0xE2, 0x9C, 0x85, // ✅
            ...utf8.encode('NO'),
            0xE2, 0x9D, 0x8C, // ❌
            0x0D, 0x0A, // \r\n
            ...utf8.encode('A'),
            0xE2, 0x9C, 0x85, // ✅
            ...utf8.encode('B'),
            0xE2, 0x9D, 0x8C, // ❌
            ...utf8.encode('C'),
            0xE2, 0x9C, 0x85, // ✅
            ...utf8.encode('D'),
          ]),
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          _wrap(
            terminal,
            theme: emoji24,
            metrics: emojiMetrics,
            maxWidth: cols * emojiMetrics.cellWidth,
            maxHeight: rows * emojiMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/text_emoji.png'),
        );
        terminal.dispose();
      });
    });

    group('selection', () {
      testWidgets('single row', (tester) async {
        terminal.writeUtf8('Hello, World!');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 0,
            endRow: 0,
            endCol: 5,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_single_row.png'),
        );
      });

      testWidgets('multi-row', (tester) async {
        terminal.writeUtf8('Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 5,
            endRow: 1,
            endCol: 4,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_multi_row.png'),
        );
      });

      testWidgets('reversed direction', (tester) async {
        terminal.writeUtf8('Hello, World!');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 5,
            endRow: 0,
            endCol: 0,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_reversed.png'),
        );
      });

      testWidgets('spanning three rows', (tester) async {
        terminal.writeUtf8('Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 5,
            endRow: 2,
            endCol: 4,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_three_rows.png'),
        );
      });

      testWidgets('multi-row reversed', (tester) async {
        terminal.writeUtf8('Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 2,
            startCol: 4,
            endRow: 0,
            endCol: 5,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_multi_row_reversed.png'),
        );
      });

      testWidgets('full row', (tester) async {
        terminal.writeUtf8('Hello, World!');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 0,
            endRow: 0,
            endCol: _cols,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_full_row.png'),
        );
      });

      testWidgets('single cell', (tester) async {
        terminal.writeUtf8('Hello, World!');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 3,
            endRow: 0,
            endCol: 4,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_single_cell.png'),
        );
      });

      testWidgets('first row full-width in multi-row', (tester) async {
        terminal.writeUtf8('Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 0,
            endRow: 2,
            endCol: 4,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_first_row_full_width.png'),
        );
      });

      testWidgets('last row full-width in multi-row', (tester) async {
        terminal.writeUtf8('Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 5,
            endRow: 2,
            endCol: _cols,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_last_row_full_width.png'),
        );
      });

      testWidgets('beyond grid bounds', (tester) async {
        terminal.writeUtf8('Hello, World!');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: -1,
            startCol: -2,
            endRow: 1,
            endCol: 30,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_beyond_bounds.png'),
        );
      });
    });

    group('block selection', () {
      testWidgets('single row', (tester) async {
        terminal.writeUtf8('Hello, World!');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 2,
            endRow: 0,
            endCol: 7,
            mode: TerminalSelectionMode.block,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_single_row.png'),
        );
      });

      testWidgets('multi-row', (tester) async {
        terminal.writeUtf8('Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 2,
            endRow: 2,
            endCol: 7,
            mode: TerminalSelectionMode.block,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_multi_row.png'),
        );
      });

      testWidgets('reversed', (tester) async {
        terminal.writeUtf8('Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 2,
            startCol: 7,
            endRow: 0,
            endCol: 2,
            mode: TerminalSelectionMode.block,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_reversed.png'),
        );
      });

      testWidgets('single cell', (tester) async {
        terminal.writeUtf8('Hello, World!');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 3,
            endRow: 0,
            endCol: 4,
            mode: TerminalSelectionMode.block,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_single_cell.png'),
        );
      });

      testWidgets('single-row reversed', (tester) async {
        terminal.writeUtf8('Hello, World!');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 7,
            endRow: 0,
            endCol: 2,
            mode: TerminalSelectionMode.block,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_single_row_reversed.png'),
        );
      });

      testWidgets('beyond grid bounds keeps columns', (tester) async {
        terminal.writeUtf8('Line one\r\nLine two\r\nLine three');
        await pump(
          tester,
          selection: const TerminalSelection(
            startRow: -1,
            startCol: 2,
            endRow: 5,
            endCol: 7,
            mode: TerminalSelectionMode.block,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/selection_block_beyond_bounds.png'),
        );
      });
    });

    group('theme rendering', () {
      testWidgets('color modes', (tester) async {
        // Merged test for all color modes using the default dark theme.
        //  1. ANSI colors: Red, Green, Blue foreground
        //  2. Bold bright: bold+red → bright red
        //  3. Extended palette: colors 100 and 200
        //  4. Grayscale ramp: 232, 240, 248, 255
        //  5. True color RGB: orange, teal
        //  6. BG palette: red and blue backgrounds
        const cols = 30;
        const rows = 6;
        final terminal = Terminal(cols: cols, rows: rows);
        terminal.writeUtf8(
          '\x1b[31mRed\x1b[0m \x1b[32mGreen\x1b[0m \x1b[34mBlue\x1b[0m\r\n'
          '\x1b[1;31mBold Red (bright)\x1b[0m\r\n'
          '\x1b[38;5;100mColor 100\x1b[0m \x1b[38;5;200mColor 200\x1b[0m\r\n'
          '\x1b[38;5;232m232\x1b[0m '
          '\x1b[38;5;240m240\x1b[0m '
          '\x1b[38;5;248m248\x1b[0m '
          '\x1b[38;5;255m255\x1b[0m\r\n'
          '\x1b[38;2;255;128;0mOrange\x1b[0m '
          '\x1b[38;2;0;200;100mTeal\x1b[0m\r\n'
          '\x1b[48;5;1;37m Red BG \x1b[0m \x1b[48;5;4;37m Blue BG \x1b[0m',
        );
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          _wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_colors.png'),
        );
        terminal.dispose();
      });

      testWidgets('selection background color', (tester) async {
        terminal.writeUtf8('Selected text here');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            selection: const SelectionTheme(
              background: DynamicColor.fixed(Color(0x80FF0000)),
            ),
          ),
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 0,
            endRow: 0,
            endCol: 13,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_selection_bg.png'),
        );
      });

      testWidgets('faint text uses theme opacity', (tester) async {
        terminal.writeUtf8('\x1b[2mFaint text\x1b[0m Normal');
        await pump(tester, overrideTheme: theme.copyWith(faintOpacity: 0.2));
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_faint_opacity.png'),
        );
      });

      testWidgets('cursor opacity', (tester) async {
        terminal.writeUtf8('X');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            cursor: const CursorTheme(opacity: 0.3),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_cursor_opacity.png'),
        );
      });

      testWidgets('cursor color', (tester) async {
        terminal.writeUtf8('X');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            cursor: const CursorTheme(
              color: DynamicColor.fixed(Color(0xFFFF0000)),
            ),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_cursor_color.png'),
        );
      });

      testWidgets('cursor text color', (tester) async {
        terminal.writeUtf8('AB');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            cursor: const CursorTheme(
              color: DynamicColor.fixed(Color(0xFFFFFFFF)),
              text: DynamicColor.fixed(Color(0xFFFF00FF)),
            ),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_cursor_text.png'),
        );
      });

      testWidgets('cursor color tracks cell foreground', (tester) async {
        terminal.writeUtf8('\x1b[31mR\x1b[0m\x1b[34mB\x1b[0m');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            cursor: const CursorTheme(color: DynamicColor.cellForeground()),
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_cursor_cell_fg.png'),
        );
      });

      testWidgets('selection foreground tints selected text', (tester) async {
        terminal.writeUtf8('\x1b[31mRed\x1b[0m \x1b[32mGreen\x1b[0m');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            selection: const SelectionTheme(
              background: DynamicColor.fixed(Color(0x80888888)),
              foreground: DynamicColor.fixed(Color(0xFFFFFF00)),
            ),
          ),
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 0,
            endRow: 0,
            endCol: 9,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_selection_fg.png'),
        );
      });

      testWidgets('selection foreground tracks cell background', (
        tester,
      ) async {
        terminal.writeUtf8('\x1b[41mA\x1b[0m\x1b[44mB\x1b[0m');
        await pump(
          tester,
          overrideTheme: theme.copyWith(
            selection: const SelectionTheme(
              background: DynamicColor.fixed(Color(0x80888888)),
              foreground: DynamicColor.cellBackground(),
            ),
          ),
          selection: const TerminalSelection(
            startRow: 0,
            startCol: 0,
            endRow: 0,
            endCol: 2,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_selection_fg_cell_bg.png'),
        );
      });

      testWidgets('boldColor overrides bold foreground', (tester) async {
        terminal.writeUtf8('\x1b[31mRed\x1b[0m \x1b[1;31mBold Red\x1b[0m');
        await pump(
          tester,
          overrideTheme: theme.copyWith(boldColor: const Color(0xFF00FFFF)),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_bold_color.png'),
        );
      });

      testWidgets('custom ANSI colors', (tester) async {
        terminal.writeUtf8('\x1b[31mThis should be cyan\x1b[0m');
        await pump(
          tester,
          overrideTheme: TerminalTheme(
            palette: ColorPalette(
              ansiColors: _customAnsiColors,
              background: theme.background,
              foreground: theme.foreground,
            ),
            fontSize: 24.0,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_custom_ansi.png'),
        );
      });

      testWidgets('custom foreground and background', (tester) async {
        terminal.writeUtf8('Hello world');
        await pump(
          tester,
          overrideTheme: TerminalTheme(
            palette: ColorPalette(
              ansiColors: _customAnsiColors,
              background: const Color(0xFF000080),
              foreground: const Color(0xFF00FF00),
            ),
            fontSize: 24.0,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_custom_fg_bg.png'),
        );
      });

      testWidgets('bold text with boldIsBright false', (tester) async {
        terminal.writeUtf8('\x1b[1;31mBold Red\x1b[0m');
        await pump(tester, overrideTheme: theme.copyWith(boldIsBright: false));
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_bold_not_bright.png'),
        );
      });

      testWidgets('256-color palette', (tester) async {
        // Full 256-color palette with auto-contrast foreground labels.
        // Layout: 16 standard colors (2 rows of 8), blank, 216-cube colors
        // (12 rows of 18), blank, 24 grayscale (2 rows of 12).
        // Each cell is 4 chars: right-padded index number.
        const cols = 72;
        const rows = 19;
        final terminal = Terminal(cols: cols, rows: rows);
        final buf = StringBuffer();

        for (var i = 0; i < 8; i++) {
          final fg = _needsWhiteFg(theme.palette, i) ? '38;5;15' : '38;5;0';
          buf.write('\x1b[$fg;48;5;${i}m${i.toString().padLeft(3)} \x1b[0m');
        }
        buf.write('\r\n');

        for (var i = 8; i < 16; i++) {
          final fg = _needsWhiteFg(theme.palette, i) ? '38;5;15' : '38;5;0';
          buf.write('\x1b[$fg;48;5;${i}m${i.toString().padLeft(3)} \x1b[0m');
        }
        buf.write('\r\n');

        buf.write('\r\n');

        for (var i = 16; i < 232; i++) {
          final fg = _needsWhiteFg(theme.palette, i) ? '38;5;15' : '38;5;0';
          buf.write('\x1b[$fg;48;5;${i}m${i.toString().padLeft(3)} \x1b[0m');
          if ((i - 16 + 1) % 18 == 0) buf.write('\r\n');
        }

        buf.write('\r\n');

        for (var i = 232; i < 256; i++) {
          final fg = _needsWhiteFg(theme.palette, i) ? '38;5;15' : '38;5;0';
          buf.write('\x1b[$fg;48;5;${i}m${i.toString().padLeft(3)} \x1b[0m');
          if ((i - 232 + 1) % 12 == 0 && i < 255) buf.write('\r\n');
        }

        terminal.writeUtf8(buf.toString());
        tester.view.devicePixelRatio = 1.0;
        await tester.pumpWidget(
          _wrap(
            terminal,
            theme: theme,
            metrics: goldenMetrics,
            maxWidth: cols * goldenMetrics.cellWidth,
            maxHeight: rows * goldenMetrics.cellHeight,
          ),
        );
        await expectLater(
          find.byType(TerminalRenderer),
          matchesGoldenFile('goldens/theme_256_colors.png'),
        );
        terminal.dispose();
      });
    });
  });
}

const _cols = 25;
const _customAnsiColors = [
  Color(0xFF282828),
  Color(0xFF00FFFF),
  Color(0xFF66994C),
  Color(0xFFE5B566),
  Color(0xFF668ECC),
  Color(0xFFB266B2),
  Color(0xFF4CB2B2),
  Color(0xFFAAAAAA),
  Color(0xFF505050),
  Color(0xFFE66464),
  Color(0xFF8CBE6E),
  Color(0xFFF0C878),
  Color(0xFF82A0DC),
  Color(0xFFC882C8),
  Color(0xFF64C8C8),
  Color(0xFFDCDCDC),
];
const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);
const _rows = 5;

final _cjkTheme = TerminalTheme.dark().copyWith(
  fontFamilyFallback: const ['Noto Sans JP', 'JetBrains Mono'],
);

final _emojiTheme = TerminalTheme.dark().copyWith(
  fontFamilyFallback: const ['Noto Emoji', 'JetBrains Mono'],
);

/// Returns true if the cell at [colorIndex] has a dark enough background
/// that white foreground text reads better than black.
bool _needsWhiteFg(ColorPalette palette, int colorIndex) {
  final c = palette[colorIndex];
  // sRGB luma (< 128 on 0-255 scale).
  return (0.299 * c.r * 255 + 0.587 * c.g * 255 + 0.114 * c.b * 255) < 128;
}

Widget _wrap(
  Terminal terminal, {
  TerminalTheme? theme,
  CellMetrics metrics = _metrics,
  TerminalSelection? selection,
  double? maxWidth,
  double? maxHeight,
  bool focused = true,
  bool blinkVisible = true,
  OnResize? onResize,
}) {
  final width = maxWidth ?? _cols * metrics.cellWidth;
  final height = maxHeight ?? _rows * metrics.cellHeight;
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: height),
        child: TerminalRenderer(
          terminal: terminal,
          theme:
              theme ??
              TerminalTheme.dark().copyWith(
                fontFamilyFallback: bundledFontFamilyFallback,
              ),
          metrics: metrics,
          offset: ViewportOffset.zero(),
          renderObserver: _TestRenderObserver(
            selection: selection,
            hasFocus: focused,
          ),
          blinkVisible: blinkVisible,
          onResize: onResize,
        ),
      ),
    ),
  );
}

class _TestRenderObserver implements TerminalRenderObserver {
  @override
  final TerminalSelection? selection;

  @override
  final bool hasFocus;

  const _TestRenderObserver({this.selection, this.hasFocus = true});

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

extension on Terminal {
  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}
