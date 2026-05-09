import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_rasterizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlyphRasterizer', () {
    group('ensureImage', () {
      test('composites pending text through the shared texture', () {
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

        final entry = rasterizer.textRasterizer.rasterizeText(
          'A',
          bold: false,
          italic: false,
        );
        rasterizer.ensureImage();

        expect(entry.srcRight, lessThanOrEqualTo(rasterizer.image!.width));
        expect(entry.srcBottom, lessThanOrEqualTo(rasterizer.image!.height));
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
