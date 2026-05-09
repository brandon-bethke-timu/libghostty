import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/lanes/emoji_lane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmojiLane', () {
    late EmojiLane lane;

    setUp(() {
      lane = EmojiLane(initialSize: 32, maxSize: 128)..configure(_config());
    });

    tearDown(() {
      lane.dispose();
    });

    test('rasterizeEmoji allocates a pending emoji entry', () {
      final entry = lane.rasterizeEmoji(
        '\u{1F600}',
        bold: false,
        italic: false,
      );

      expect(entry.lane, AtlasEntryLane.emoji);
      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(lane.hasPending, isTrue);
      expect(lane.image, isNull);
    });

    test('ensureImage creates the atlas image and clears pending emoji', () {
      lane.rasterizeEmoji('\u{1F600}', bold: false, italic: false);

      lane.ensureImage();

      expect(lane.image, isNotNull);
      expect(lane.hasPending, isFalse);
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
