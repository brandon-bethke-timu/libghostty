import 'dart:ui';

import 'package:flterm/src/foundation/cell_metrics.dart';
import 'package:flterm/src/rendering/atlas/glyph_atlas_config.dart';
import 'package:flterm/src/rendering/atlas/glyph_rasterizer.dart';
import 'package:flterm/src/rendering/atlas/glyph_text_atlas_lane.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlyphTextAtlasLane', () {
    late GlyphRasterizer rasterizer;
    late GlyphTextAtlasLane lane;

    setUp(() {
      rasterizer = GlyphRasterizer()..configure(_config());
      lane = GlyphTextAtlasLane(
        textRasterizer: rasterizer.textRasterizer,
        emojiRasterizer: rasterizer.emojiRasterizer,
      );
    });

    tearDown(() => rasterizer.dispose());

    test('shares text entries for matching keys', () {
      const key = (text: 'A', bold: false, italic: false);

      final first = lane.addText(key);
      final second = lane.addText(key);

      expect(second, same(first));
      expect(lane.size, 1);
    });

    test('shares codepoint entries with matching text entries', () {
      const key = (text: 'A', bold: false, italic: false);

      final text = lane.addText(key);
      final codepoint = lane.addCodepoint(0x41, bold: false, italic: false);

      expect(codepoint, same(text));
      expect(lane.size, 1);
    });

    test('keeps style and span in the cache key', () {
      final plain = lane.addCodepoint(0x41, bold: false, italic: false);
      final bold = lane.addCodepoint(0x41, bold: true, italic: false);
      final wide = lane.addCodepoint(0x41, bold: false, italic: false, span: 2);

      expect(bold, isNot(same(plain)));
      expect(wide, isNot(same(plain)));
      expect(lane.size, 3);
    });

    test('keeps text and emoji entries separate for matching keys', () {
      const key = (text: '\u{1F600}', bold: false, italic: false);

      final text = lane.addText(key);
      final emoji = lane.addEmoji(key);

      expect(emoji, isNot(same(text)));
      expect(lane.size, 2);
    });

    test('dispatches add through the requested text or emoji path', () {
      const textKey = (text: 'A', bold: false, italic: false);
      const emojiKey = (text: '\u{1F600}', bold: false, italic: false);

      final text = lane.add(textKey);
      final emoji = lane.add(emojiKey, emoji: true);

      expect(text.isEmoji, isFalse);
      expect(emoji.isEmoji, isTrue);
      expect(lane.size, 2);
    });

    test('clear removes cached text and codepoint entries', () {
      final before = lane.addCodepoint(0x41, bold: false, italic: false);
      expect(lane.size, 1);

      lane.clear();

      expect(lane.size, 0);
      final after = lane.addCodepoint(0x41, bold: false, italic: false);
      expect(after, isNot(same(before)));
    });

    test('preseedAscii creates printable ASCII entries for every style', () {
      lane.preseedAscii();

      expect(lane.size, 94 * 4);
      final plain = lane.addCodepoint(0x41, bold: false, italic: false);
      final bold = lane.addCodepoint(0x41, bold: true, italic: false);
      final italic = lane.addCodepoint(0x41, bold: false, italic: true);
      final boldItalic = lane.addCodepoint(0x41, bold: true, italic: true);

      expect(lane.size, 94 * 4);
      expect({plain, bold, italic, boldItalic}, hasLength(4));
    });
  });
}

GlyphAtlasConfig _config() {
  return GlyphAtlasConfig(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    fontFamily: 'monospace',
    fontFamilyFallback: const [],
    metrics: const CellMetrics(cellWidth: 8, cellHeight: 16, baseline: 12),
    devicePixelRatio: 1.0,
  );
}
