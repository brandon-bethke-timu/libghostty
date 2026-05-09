import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_cache.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_rasterizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('GlyphAtlasCache', () {
    late GlyphRasterizer rasterizer;
    late GlyphAtlasCache cache;

    setUp(() {
      rasterizer = GlyphRasterizer()..configure(_config());
      cache = GlyphAtlasCache(
        textRasterizer: rasterizer.textRasterizer,
        emojiRasterizer: rasterizer.emojiRasterizer,
        spriteRasterizer: rasterizer.spriteRasterizer,
        decorationRasterizer: rasterizer.decorationRasterizer,
      );
    });

    tearDown(() => rasterizer.dispose());

    test('shares text entries for matching keys', () {
      const key = (text: 'A', bold: false, italic: false);

      final first = cache.add(key);
      final second = cache.add(key);

      expect(second, same(first));
      expect(cache.size, 1);
    });

    test('shares codepoint entries with text entries', () {
      const key = (text: 'A', bold: false, italic: false);

      final text = cache.add(key);
      final codepoint = cache.addCodepoint(0x41, bold: false, italic: false);

      expect(codepoint, same(text));
      expect(cache.size, 1);
    });

    test('keeps text and emoji entries separate for matching keys', () {
      const key = (text: '\u{1F600}', bold: false, italic: false);

      final text = cache.add(key);
      final emoji = cache.add(key, emoji: true);

      expect(emoji, isNot(same(text)));
      expect(cache.size, 2);
    });

    test('sprite codepoints are independent from text style', () {
      final plain = cache.addCodepoint(0x2500, bold: false, italic: false);
      final styled = cache.addCodepoint(0x2500, bold: true, italic: true);

      expect(styled, same(plain));
      expect(cache.size, 1);
    });

    test('sprite and text lanes keep separate entries', () {
      final text = cache.add((text: '\u2500', bold: false, italic: false));
      final sprite = cache.addCodepoint(0x2500, bold: false, italic: false);

      expect(sprite, isNot(same(text)));
      expect(cache.size, 2);
    });

    test('shares decoration entries for matching styles', () {
      final first = cache.addDecoration(UnderlineStyle.single);
      final second = cache.addDecoration(UnderlineStyle.single);

      expect(second, same(first));
    });

    test('clear removes cached entries', () {
      cache.add((text: 'A', bold: false, italic: false));
      expect(cache.size, 1);

      cache.clear();

      expect(cache.size, 0);
    });

    test('preseedCommonGlyphs delegates common preseed work to lanes', () {
      cache.preseedCommonGlyphs();

      expect(cache.size, greaterThan(94 * 4));
      final ascii = cache.addCodepoint(0x41, bold: false, italic: false);
      final sprite = cache.addCodepoint(0x2500, bold: false, italic: false);
      final decoration = cache.addDecoration(UnderlineStyle.single);

      expect(ascii, isNotNull);
      expect(sprite, isNotNull);
      expect(decoration, isNotNull);
      expect(cache.size, greaterThan(94 * 4));
    });
  });
}

GlyphAtlasConfig _config() {
  return GlyphAtlasConfig(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: 'monospace',
    fontFamilyFallback: const [],
    metrics: const CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12),
    devicePixelRatio: 1.0,
  );
}
