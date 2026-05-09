import 'dart:ui';

import 'package:flterm/src/foundation.dart';
import 'package:flterm/src/rendering/atlas/atlas_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtlasConfig', () {
    test('equality includes font, metrics, fallback, and DPR', () {
      final first = _config();
      final second = _config();

      expect(second, first);
      expect(second.hashCode, first.hashCode);
      expect(_config(fontSize: 16), isNot(first));
      expect(_config(devicePixelRatio: 2), isNot(first));
      expect(_config(fallback: const ['serif']), isNot(first));
    });

    test('defensively copies fallback list', () {
      final fallback = ['serif'];
      final config = _config(fallback: fallback);

      fallback.add('emoji');

      expect(config.fontFamilyFallback, ['serif']);
      expect(
        () => config.fontFamilyFallback.add('emoji'),
        throwsUnsupportedError,
      );
    });

    test(
      'copyWith preserves existing values and replaces requested fields',
      () {
        final original = _config();
        final changed = original.copyWith(fontSize: 16);

        expect(changed.fontSize, 16);
        expect(changed.fontWeight, original.fontWeight);
        expect(changed.fontFamily, original.fontFamily);
        expect(changed.fontFamilyFallback, original.fontFamilyFallback);
        expect(changed.metrics, original.metrics);
        expect(changed.devicePixelRatio, original.devicePixelRatio);
      },
    );
  });
}

AtlasConfig _config({
  double fontSize = 14,
  double devicePixelRatio = 1,
  List<String> fallback = const [],
}) {
  return AtlasConfig(
    fontSize: fontSize,
    fontWeight: FontWeight.normal,
    fontFamily: 'monospace',
    fontFamilyFallback: fallback,
    metrics: const CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12),
    devicePixelRatio: devicePixelRatio,
  );
}
