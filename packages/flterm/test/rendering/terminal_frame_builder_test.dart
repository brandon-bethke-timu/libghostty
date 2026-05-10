@Tags(['ffi'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/foundation/terminal_selection.dart';
import 'package:flterm/src/foundation/terminal_theme.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/atlas/sprite_buffer.dart';
import 'package:flterm/src/rendering/paint_state.dart';
import 'package:flterm/src/rendering/terminal_frame_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('TerminalFrameBuilder', () {
    late Terminal terminal;
    late Atlas atlas;
    late SpriteBuffer sprites;
    late TerminalPaintState state;
    late TerminalFrameBuilder builder;

    setUp(() {
      terminal = Terminal(cols: 8, rows: 2);
      atlas = Atlas(_config());
      sprites = SpriteBuffer();
      state = TerminalPaintState(TerminalTheme.dark(), _metrics)
        ..cols = 8
        ..rows = 2;
      builder = TerminalFrameBuilder(atlas, sprites, state)..configure(2, 8);
    });

    tearDown(() {
      builder.dispose();
      sprites.dispose();
      atlas.dispose();
      terminal.dispose();
    });

    test('sync emits text, sprite, and emoji channels', () {
      terminal.writeUtf8('A\u2500\u{1F600}');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.regular.count, greaterThan(0));
      expect(sprites.sprite.count, greaterThan(0));
      expect(sprites.emoji.count, greaterThan(0));
      expect(atlas.spriteImage, isNotNull);
      expect(atlas.emojiImage, isNotNull);
    });

    test('sync emits operator ligatures without adding text atlas entries', () {
      final initialCacheSize = atlas.cacheSize;
      terminal.writeUtf8('=> !=');

      builder.sync(terminal, terminalDirty: true);

      expect(sprites.shaped.count, 2);
      expect(atlas.cacheSize, initialCacheSize);
    });

    test(
      'sync emits selection background without terminal access in paint',
      () {
        terminal.writeUtf8('hello');
        state.selection = const TerminalSelection(
          startRow: 0,
          startCol: 1,
          endRow: 0,
          endCol: 3,
        );

        builder.sync(terminal, terminalDirty: true);

        expect(sprites.background.count, greaterThan(0));
      },
    );

    test('sync resolves block cursor glyph from cached frame state', () {
      terminal.writeUtf8('A\x1b[1;1H');
      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursor.col, 0);
      expect(state.cursorAtlasEntry, isNotNull);
    });

    test('sync skips cursor glyph on empty cells', () {
      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorAtlasEntry, isNull);
    });

    test('sync skips cursor glyph when the terminal is unfocused', () {
      state.cursorFocused = false;
      terminal.writeUtf8('A\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorAtlasEntry, isNull);
    });

    test('sync skips cursor glyph for non-block cursors', () {
      state.updateTheme(
        TerminalTheme.dark().copyWith(
          cursor: const CursorTheme(shape: CursorShape.underline),
        ),
      );
      terminal.writeUtf8('A\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursor.shape, CursorShape.underline);
      expect(state.cursorAtlasEntry, isNull);
    });

    test('sync skips cursor glyph on invisible text', () {
      terminal.writeUtf8('\x1b[8mA\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorAtlasEntry, isNull);
    });

    test('sync skips cursor glyph on blink-hidden text', () {
      state.blinkVisible = false;
      terminal.writeUtf8('\x1b[5mA\x1b[1;1H');

      builder.sync(terminal, terminalDirty: true);

      expect(state.cursor.visible, isTrue);
      expect(state.cursorAtlasEntry, isNull);
    });
  });
}

const _metrics = CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12);

AtlasConfig _config() {
  return AtlasConfig(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: 'monospace',
    fontFamilyFallback: const [],
    metrics: _metrics,
    devicePixelRatio: 1.0,
  );
}

extension on Terminal {
  void writeUtf8(String text) => write(Uint8List.fromList(utf8.encode(text)));
}
