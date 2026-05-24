import 'dart:typed_data';
import 'dart:ui' show FontWeight;

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/lanes/sprite_lane.dart';
import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpriteLane', () {
    AtlasConfig config({
      CellMetrics metrics = const CellMetrics(
        cellWidth: 8,
        cellHeight: 16,
        baseline: 12,
      ),
    }) {
      return AtlasConfig(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        fontFamily: 'monospace',
        fontFamilyFallback: const [],
        metrics: metrics,
        devicePixelRatio: 1.0,
      );
    }

    late SpriteLane lane;

    setUp(() {
      lane = SpriteLane(initialSize: 32, maxSize: 128)..configure(config());
    });

    tearDown(() {
      lane.dispose();
    });

    void configureLargeCells() {
      lane.configure(
        config(
          metrics: const CellMetrics(
            cellWidth: 16,
            cellHeight: 32,
            baseline: 24,
          ),
        ),
      );
    }

    Future<(AtlasEntry, Uint8List, int)> rasterizeGlyph(int codepoint) async {
      final glyph = SpriteFace().glyphFor(codepoint)!;
      final entry = lane.rasterizeSprite(glyph);

      lane.ensureImage();
      final bytes = await lane.image!.toByteData();

      return (entry, bytes!.buffer.asUint8List(), lane.image!.width);
    }

    test('rasterizeSprite allocates a cell-sized pending sprite entry', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;

      final entry = lane.rasterizeSprite(glyph);

      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(entry.srcLeft, 1);
      expect(entry.srcTop, 1);
      expect(entry.srcRight - entry.srcLeft, 8);
      expect(entry.srcBottom - entry.srcTop, 16);
      expect(entry.lane, AtlasEntryLane.sprite);
      expect(lane.hasPending, isTrue);
      expect(lane.image, isNull);
    });

    test('ensureImage creates the atlas image and clears pending sprites', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;
      lane.rasterizeSprite(glyph);

      lane.ensureImage();

      expect(lane.image, isNotNull);
      expect(lane.hasPending, isFalse);
    });

    test('clear removes pending sprites without creating an image', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;
      lane.rasterizeSprite(glyph);

      lane.clear();

      expect(lane.hasPending, isFalse);
      expect(lane.image, isNull);
    });

    test('solid block sprites populate atlas gutter', () async {
      configureLargeCells();

      final (entry, rgba, width) = await rasterizeGlyph(0x2588);
      final leftAlpha = _alphaAt(rgba, width, entry.srcLeft.toInt() - 1, 16);
      final rightAlpha = _alphaAt(rgba, width, entry.srcRight.toInt(), 16);

      expect(leftAlpha, 255);
      expect(rightAlpha, 255);
    });

    test('composite block sprites populate atlas gutter', () async {
      configureLargeCells();

      final (entry, rgba, width) = await rasterizeGlyph(0x1FB7C);
      final alpha = _alphaAt(rgba, width, entry.srcLeft.toInt() - 1, 16);

      expect(alpha, 255);
    });

    test('fractional block sprites keep visible source geometry', () async {
      configureLargeCells();

      final (entry, rgba, width) = await rasterizeGlyph(0x2581);
      final x = entry.srcLeft.toInt() + 8;
      final top = entry.srcTop.toInt();
      final beforeBlockAlpha = _alphaAt(rgba, width, x, top + 27);
      final firstBlockAlpha = _alphaAt(rgba, width, x, top + 28);

      expect(beforeBlockAlpha, 0);
      expect(firstBlockAlpha, 255);
    });
  });
}

int _alphaAt(Uint8List rgba, int width, int x, int y) {
  return rgba[(y * width + x) * 4 + 3];
}
