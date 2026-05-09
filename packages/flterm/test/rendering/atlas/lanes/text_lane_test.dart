import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flterm/src/rendering/atlas/atlas_entry.dart';
import 'package:flterm/src/rendering/atlas/atlas_texture.dart';
import 'package:flterm/src/rendering/atlas/lanes/text_lane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextLane', () {
    late TextLane lane;

    setUp(() {
      lane = TextLane(initialSize: 32, maxSize: 128)..configure(_config());
    });

    tearDown(() {
      lane.dispose();
    });

    test('rasterizeText allocates a pending text entry', () {
      final entry = lane.rasterizeText('A', bold: false, italic: false);

      expect(entry.lane, AtlasEntryLane.text);
      expect(entry.srcRight, greaterThan(entry.srcLeft));
      expect(lane.hasPending, isTrue);
      expect(lane.image, isNull);
    });

    test('ensureImage creates the atlas image and clears pending text', () {
      lane.rasterizeText('A', bold: false, italic: false);

      lane.ensureImage();

      expect(lane.image, isNotNull);
      expect(lane.hasPending, isFalse);
    });

    test('clear drops pending text and releases the image', () {
      lane.rasterizeText('A', bold: false, italic: false);
      lane.ensureImage();
      lane.rasterizeText('B', bold: false, italic: false);

      lane.clear();

      expect(lane.hasPending, isFalse);
      expect(lane.image, isNull);
    });

    test('throws when a single slot exceeds the max atlas size', () {
      final lane = TextLane(initialSize: 16, maxSize: 32)
        ..configure(
          _config(
            metrics: const CellMetrics(
              cellWidth: 32,
              cellHeight: 8,
              baseline: 6,
            ),
          ),
        );
      addTearDown(lane.dispose);

      expect(
        () => lane.rasterizeText('A', bold: false, italic: false),
        throwsA(isA<AtlasFullException>()),
      );
    });

    test('throws before returning out-of-bounds entries when full', () {
      final lane = TextLane(initialSize: 16, maxSize: 32)
        ..configure(
          _config(
            metrics: const CellMetrics(
              cellWidth: 8,
              cellHeight: 8,
              baseline: 6,
            ),
          ),
        );
      addTearDown(lane.dispose);

      var added = 0;
      AtlasFullException? full;
      for (var i = 0; i < 64; i++) {
        try {
          final entry = lane.rasterizeText(
            String.fromCharCode(0x41 + i),
            bold: false,
            italic: false,
          );
          expect(entry.srcRight, lessThanOrEqualTo(32));
          expect(entry.srcBottom, lessThanOrEqualTo(32));
          added++;
        } on AtlasFullException catch (error) {
          full = error;
          break;
        }
      }

      expect(added, greaterThan(0));
      expect(full, isNotNull);
    });
  });
}

AtlasConfig _config({
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
