import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/atlas.dart';
import 'package:flterm/src/rendering/cursor_atlas_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libghostty/libghostty.dart';

void main() {
  group('CursorAtlasResolver', () {
    late Atlas atlas;
    late CursorAtlasResolver resolver;

    setUp(() {
      atlas = Atlas(_config());
      resolver = CursorAtlasResolver(atlas);
    });

    tearDown(() {
      atlas.dispose();
    });

    test('returns null when cursor content should not be painted', () {
      expect(
        resolver.resolve(
          cell: null,
          shape: .block,
          focused: true,
          blinkVisible: true,
        ),
        isNull,
      );
      expect(_resolve(resolver, focused: false), isNull);
      expect(_resolve(resolver, shape: .underline), isNull);
      expect(_resolve(resolver, content: ''), isNull);
      expect(_resolve(resolver, style: const Style(invisible: true)), isNull);
      expect(
        _resolve(
          resolver,
          style: const Style(blink: true),
          blinkVisible: false,
        ),
        isNull,
      );
    });

    test('routes narrow text through the text lane', () {
      final entry = _resolve(resolver)!;

      expect(entry.lane, AtlasEntryLane.text);
    });

    test('routes wide CJK through the text lane', () {
      final entry = _resolve(resolver, content: '\u4E00', wide: true)!;

      expect(entry.lane, AtlasEntryLane.text);
    });

    test('routes wide emoji through the emoji lane', () {
      final entry = _resolve(resolver, content: '\u{1F600}', wide: true)!;

      expect(entry.lane, AtlasEntryLane.emoji);
    });

    test('routes variation-selector emoji through the emoji lane', () {
      final entry = _resolve(resolver, content: '\u2764\uFE0F')!;

      expect(entry.lane, AtlasEntryLane.emoji);
    });

    test('routes built-in sprite codepoints through the sprite lane', () {
      final entry = _resolve(resolver, content: '\u2500', wide: true)!;

      expect(entry.lane, AtlasEntryLane.sprite);
    });
  });
}

AtlasEntry? _resolve(
  CursorAtlasResolver resolver, {
  String content = 'A',
  bool wide = false,
  Style style = const Style(),
  CursorShape shape = .block,
  bool focused = true,
  bool blinkVisible = true,
}) {
  return resolver.resolve(
    cell: CursorCell(content, style, wide: wide),
    shape: shape,
    focused: focused,
    blinkVisible: blinkVisible,
  );
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
