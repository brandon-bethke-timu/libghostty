import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_rasterizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlyphRasterizer', () {
    group('rasterizeText', () {
      test('grows until a large slot fits within bounds', () {
        final rasterizer = GlyphRasterizer(initialSize: 16, maxSize: 64)
          ..configure(
            _config(
              metrics: const CellMetrics(
                cellWidth: 40,
                cellHeight: 8,
                baseline: 6,
              ),
            ),
          );
        addTearDown(rasterizer.dispose);

        final entry = rasterizer.rasterizeText('A', bold: false, italic: false);
        rasterizer.ensureImage();

        expect(entry.srcRight, lessThanOrEqualTo(rasterizer.image!.width));
        expect(entry.srcBottom, lessThanOrEqualTo(rasterizer.image!.height));
      });

      test('throws when a single slot exceeds the max atlas size', () {
        final rasterizer = GlyphRasterizer(initialSize: 16, maxSize: 32)
          ..configure(
            _config(
              metrics: const CellMetrics(
                cellWidth: 32,
                cellHeight: 8,
                baseline: 6,
              ),
            ),
          );
        addTearDown(rasterizer.dispose);

        expect(
          () => rasterizer.rasterizeText('A', bold: false, italic: false),
          throwsA(isA<GlyphAtlasFullException>()),
        );
      });

      test('throws before returning out-of-bounds entries when full', () {
        final rasterizer = GlyphRasterizer(initialSize: 16, maxSize: 32)
          ..configure(
            _config(
              metrics: const CellMetrics(
                cellWidth: 8,
                cellHeight: 8,
                baseline: 6,
              ),
            ),
          );
        addTearDown(rasterizer.dispose);

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
  });
}

GlyphAtlasConfig _config({required CellMetrics metrics}) {
  return GlyphAtlasConfig(
    fontSize: 8,
    fontWeight: FontWeight.normal,
    fontFamily: 'monospace',
    fontFamilyFallback: const [],
    metrics: metrics,
    devicePixelRatio: 1.0,
  );
}
