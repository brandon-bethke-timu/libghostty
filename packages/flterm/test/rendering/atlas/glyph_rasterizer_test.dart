import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_rasterizer.dart';
import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart' show UnderlineStyle;

void main() {
  group('GlyphRasterizer', () {
    group('ensureImage', () {
      test('composites pending text through the text texture', () {
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

        expect(entry.srcRight, lessThanOrEqualTo(rasterizer.textImage!.width));
        expect(
          entry.srcBottom,
          lessThanOrEqualTo(rasterizer.textImage!.height),
        );
        expect(rasterizer.image, same(rasterizer.textImage));
      });

      test('keeps lane textures physically separate', () {
        final rasterizer = GlyphRasterizer(initialSize: 16, maxSize: 64)
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

        rasterizer.textRasterizer.rasterizeText(
          'A',
          bold: false,
          italic: false,
        );
        rasterizer.emojiRasterizer.rasterizeEmoji(
          '\u{1F600}',
          bold: false,
          italic: false,
        );
        rasterizer.spriteRasterizer.rasterizeSprite(
          SpriteFace().glyphFor(0x2500)!,
        );
        rasterizer.decorationRasterizer.rasterizeDecoration(
          UnderlineStyle.single,
        );

        rasterizer.ensureImage();

        expect(rasterizer.textImage, isNotNull);
        expect(rasterizer.emojiImage, isNotNull);
        expect(rasterizer.spriteImage, isNotNull);
        expect(rasterizer.decorationImage, isNotNull);
        expect(rasterizer.emojiImage, isNot(same(rasterizer.textImage)));
        expect(rasterizer.spriteImage, isNot(same(rasterizer.textImage)));
        expect(rasterizer.decorationImage, isNot(same(rasterizer.spriteImage)));
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
