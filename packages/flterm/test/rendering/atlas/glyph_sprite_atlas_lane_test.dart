import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_rasterizer.dart';
import 'package:flterm/src/rendering/atlas/glyph_sprite_atlas_lane.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('GlyphSpriteAtlasLane', () {
    late GlyphRasterizer rasterizer;
    late GlyphSpriteAtlasLane lane;

    setUp(() {
      rasterizer = GlyphRasterizer()..configure(_config());
      lane = GlyphSpriteAtlasLane(
        spriteRasterizer: rasterizer.spriteRasterizer,
        decorationRasterizer: rasterizer.decorationRasterizer,
      );
    });

    tearDown(() => rasterizer.dispose());

    test('reports supported codepoints', () {
      expect(lane.supportedCodepoints, contains(0x2500));
      expect(lane.hasCodepoint(0x2500), isTrue);
      expect(lane.hasCodepoint(0x41), isFalse);
    });

    test('returns null for unsupported codepoints', () {
      final entry = lane.addCodepoint(0x41);

      expect(entry, isNull);
      expect(lane.size, 0);
    });

    test('shares sprite entries for matching codepoint and span', () {
      final first = lane.addCodepoint(0x2500);
      final second = lane.addCodepoint(0x2500);

      expect(first, isNotNull);
      expect(second, same(first));
      expect(lane.size, 1);
    });

    test('keeps span in the sprite cache key', () {
      final single = lane.addCodepoint(0x2500);
      final wide = lane.addCodepoint(0x2500, span: 2);

      expect(wide, isNot(same(single)));
      expect(lane.size, 2);
    });

    test('shares decoration entries for matching styles', () {
      final first = lane.addDecoration(UnderlineStyle.single);
      final second = lane.addDecoration(UnderlineStyle.single);

      expect(second, same(first));
      expect(lane.size, 1);
    });

    test('clear removes cached sprites and decorations', () {
      final spriteBefore = lane.addCodepoint(0x2500);
      final decorationBefore = lane.addDecoration(UnderlineStyle.single);
      expect(lane.size, 2);

      lane.clear();

      expect(lane.size, 0);
      final spriteAfter = lane.addCodepoint(0x2500);
      final decorationAfter = lane.addDecoration(UnderlineStyle.single);
      expect(spriteAfter, isNot(same(spriteBefore)));
      expect(decorationAfter, isNot(same(decorationBefore)));
    });

    test(
      'preseedCodepoints creates one entry for every supported codepoint',
      () {
        final supportedCount = lane.supportedCodepoints.length;

        lane.preseedCodepoints();

        expect(lane.size, supportedCount);
        final preseeded = lane.addCodepoint(0x2500);
        expect(lane.size, supportedCount);
        expect(preseeded, isNotNull);
      },
    );

    test('preseedDecorations creates reusable decoration entries', () {
      lane.preseedDecorations();

      final single = lane.addDecoration(UnderlineStyle.single);
      final singleAgain = lane.addDecoration(UnderlineStyle.single);
      final curly = lane.addDecoration(UnderlineStyle.curly);

      expect(singleAgain, same(single));
      expect(curly, isNot(same(single)));
      expect(lane.size, UnderlineStyle.values.length - 1);
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
