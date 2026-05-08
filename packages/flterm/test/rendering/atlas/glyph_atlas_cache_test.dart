import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_cache.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_rasterizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlyphAtlasCache', () {
    late GlyphRasterizer rasterizer;
    late GlyphAtlasCache cache;

    setUp(() {
      rasterizer = GlyphRasterizer()..configure(_config());
      cache = GlyphAtlasCache(rasterizer);
    });

    tearDown(() => rasterizer.dispose());

    test('shares text entries for matching keys', () {
      const key = (text: 'A', bold: false, italic: false);

      final first = cache.addText(key);
      final second = cache.addText(key);

      expect(second, same(first));
      expect(cache.size, 1);
    });

    test('shares codepoint entries with text entries', () {
      const key = (text: 'A', bold: false, italic: false);

      final text = cache.addText(key);
      final codepoint = cache.addCodepoint(0x41, bold: false, italic: false);

      expect(codepoint, same(text));
      expect(cache.size, 1);
    });

    test('sprite codepoints are independent from text style', () {
      final plain = cache.addCodepoint(0x2500, bold: false, italic: false);
      final styled = cache.addCodepoint(0x2500, bold: true, italic: true);

      expect(styled, same(plain));
      expect(cache.size, 1);
    });

    test('clear removes cached entries', () {
      cache.addText((text: 'A', bold: false, italic: false));
      expect(cache.size, 1);

      cache.clear();

      expect(cache.size, 0);
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
