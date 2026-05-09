import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import 'glyph_entry.dart';
import 'glyph_sprite_atlas_lane.dart';
import 'glyph_sprite_rasterizer.dart';
import 'glyph_text_atlas_lane.dart';
import 'glyph_text_rasterizer.dart';

export 'glyph_text_atlas_lane.dart' show TextGlyphKey;

/// Caches glyph atlas entries and delegates rasterization on cache miss.
class GlyphAtlasCache {
  final GlyphTextAtlasLane _text;
  final GlyphSpriteAtlasLane _sprites;

  GlyphAtlasCache({
    required GlyphTextRasterizer textRasterizer,
    required GlyphSpriteRasterizer spriteRasterizer,
  }) : _text = GlyphTextAtlasLane(textRasterizer),
       _sprites = GlyphSpriteAtlasLane(spriteRasterizer);

  int get size => _text.size + _sprites.size;

  /// Dispatches to [addEmoji] when [emoji] is true, otherwise [addText].
  GlyphEntry add(TextGlyphKey key, {int span = 1, bool emoji = false}) {
    return _text.add(key, span: span, emoji: emoji);
  }

  /// Returns or creates a glyph for a single [codepoint].
  ///
  /// Built-in sprite codepoints bypass font rasterization entirely and
  /// render from geometry. Non-sprite codepoints route through the text
  /// lane so single-codepoint and text-keyed callers share entries.
  GlyphEntry addCodepoint(
    int codepoint, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    return _sprites.addCodepoint(codepoint, span: span) ??
        _text.addCodepoint(codepoint, bold: bold, italic: italic, span: span);
  }

  /// Returns or creates a decoration sprite for the given underline [style].
  GlyphEntry addDecoration(UnderlineStyle style) {
    return _sprites.addDecoration(style);
  }

  void clear() {
    _text.clear();
    _sprites.clear();
  }

  bool hasSprite(int codepoint) => _sprites.hasCodepoint(codepoint);

  /// Pre-seeds glyphs that are expected to appear in nearly every terminal.
  ///
  /// Text and sprite lanes own their specific preseed rules so callers do
  /// not need to know which codepoints are font-rasterized vs. built-in
  /// geometry.
  void preseedCommonGlyphs() {
    _text.preseedAscii();
    _sprites.preseedCodepoints();
    _sprites.preseedDecorations();
  }
}
