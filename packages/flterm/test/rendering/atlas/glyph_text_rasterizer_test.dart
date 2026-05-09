import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_texture.dart';
import 'package:flterm/src/rendering/atlas/glyph_text_rasterizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlyphTextRasterizer', () {
    late GlyphAtlasTexture texture;
    late GlyphTextRasterizer rasterizer;

    setUp(() {
      texture = GlyphAtlasTexture(initialSize: 32, maxSize: 128);
      rasterizer = GlyphTextRasterizer(texture)..configure(_config());
    });

    tearDown(() {
      rasterizer.clear();
      texture.dispose();
    });

    test('rasterizeText allocates a pending text entry', () {
      final entry = rasterizer.rasterizeText('A', bold: false, italic: false);

      expect(entry.isEmoji, isFalse);
      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(rasterizer.hasPending, isTrue);
    });

    test('rasterizeEmoji allocates a pending emoji entry', () {
      final entry = rasterizer.rasterizeEmoji(
        '\u{1F600}',
        bold: false,
        italic: false,
      );

      expect(entry.isEmoji, isTrue);
      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(rasterizer.hasPending, isTrue);
    });

    test(
      'compositePending creates the atlas image and clears pending text',
      () {
        rasterizer.rasterizeText('A', bold: false, italic: false);

        texture.replaceImage(rasterizer.compositePending);

        expect(texture.image, isNotNull);
        expect(rasterizer.hasPending, isFalse);
      },
    );

    test('clear disposes pending paragraphs without creating an image', () {
      rasterizer.rasterizeText('A', bold: false, italic: false);

      rasterizer.clear();

      expect(rasterizer.hasPending, isFalse);
      expect(texture.image, isNull);
    });

    test('throws when a single slot exceeds the max atlas size', () {
      final texture = GlyphAtlasTexture(initialSize: 16, maxSize: 32);
      final rasterizer = GlyphTextRasterizer(texture)
        ..configure(
          _config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 8,
              baseline: 6,
            ),
          ),
        );
      addTearDown(() {
        rasterizer.clear();
        texture.dispose();
      });

      expect(
        () => rasterizer.rasterizeText('A', bold: false, italic: false),
        throwsA(isA<GlyphAtlasFullException>()),
      );
    });

    test('throws before returning out-of-bounds entries when full', () {
      final texture = GlyphAtlasTexture(initialSize: 16, maxSize: 32);
      final rasterizer = GlyphTextRasterizer(texture)
        ..configure(
          _config(
            metrics: const CellMetrics(
              cellWidth: 8,
              cellHeight: 8,
              baseline: 6,
            ),
          ),
        );
      addTearDown(() {
        rasterizer.clear();
        texture.dispose();
      });

      var added = 0;
      GlyphAtlasFullException? full;
      for (var i = 0; i < 64; i++) {
        try {
          final entry = rasterizer.rasterizeText(
            String.fromCharCode(0x41 + i),
            bold: false,
            italic: false,
          );
          expect(entry.srcRight, lessThanOrEqualTo(32));
          expect(entry.srcBottom, lessThanOrEqualTo(32));
          added++;
        } on GlyphAtlasFullException catch (error) {
          full = error;
          break;
        }
      }

      expect(added, greaterThan(0));
      expect(full, isNotNull);
    });
  });
}

GlyphAtlasConfig _config({
  CellMetrics metrics = const CellMetrics(
    cellWidth: 8,
    cellHeight: 16,
    baseline: 12,
  ),
}) {
  return GlyphAtlasConfig(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: 'monospace',
    fontFamilyFallback: const [],
    metrics: metrics,
    devicePixelRatio: 1.0,
  );
}
