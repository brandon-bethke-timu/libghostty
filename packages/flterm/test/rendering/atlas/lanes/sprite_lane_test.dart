import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/lanes/sprite_lane.dart';
import 'package:flterm/src/rendering/sprite/sprite_face.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpriteLane', () {
    late SpriteLane lane;

    setUp(() {
      lane = SpriteLane(initialSize: 32, maxSize: 128)..configure(_config());
    });

    tearDown(() {
      lane.dispose();
    });

    test('rasterizeSprite allocates a pending sprite entry', () {
      final glyph = SpriteFace().glyphFor(0x2500)!;

      final entry = lane.rasterizeSprite(glyph);

      expect(entry.srcRight, greaterThan(entry.srcLeft));
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
  });
}

AtlasConfig _config() {
  return AtlasConfig(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: 'monospace',
    fontFamilyFallback: const [],
    metrics: const CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12),
    devicePixelRatio: 1.0,
  );
}
