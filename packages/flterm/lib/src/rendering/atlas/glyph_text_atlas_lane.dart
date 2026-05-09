import 'glyph_entry.dart';
import 'glyph_text_rasterizer.dart';

/// Lookup key for a cached glyph. Two glyphs with the same text, bold,
/// and italic state share the same atlas entry.
typedef TextGlyphKey = ({String text, bool bold, bool italic});

typedef _CodepointGlyphKey = ({
  int codepoint,
  bool bold,
  bool italic,
  int span,
});
typedef _GlyphCacheKey = ({String text, bool bold, bool italic, int span});

/// Atlas lane for font-rasterized text and emoji glyphs.
class GlyphTextAtlasLane {
  final GlyphTextRasterizer _textRasterizer;
  final GlyphTextRasterizer _emojiRasterizer;
  final Map<_GlyphCacheKey, GlyphEntry> _text = {};
  final Map<_GlyphCacheKey, GlyphEntry> _emoji = {};
  final Map<_CodepointGlyphKey, GlyphEntry> _codepoints = {};

  GlyphTextAtlasLane({
    required GlyphTextRasterizer textRasterizer,
    required GlyphTextRasterizer emojiRasterizer,
  }) : _textRasterizer = textRasterizer,
       _emojiRasterizer = emojiRasterizer;

  int get size => _text.length + _emoji.length;

  /// Dispatches to [addEmoji] when [emoji] is true, otherwise [addText].
  GlyphEntry add(TextGlyphKey key, {int span = 1, bool emoji = false}) {
    return emoji ? addEmoji(key, span: span) : addText(key, span: span);
  }

  /// Returns or creates a glyph for a single non-sprite [codepoint].
  ///
  /// [_codepoints] acts as a write-through memo over [addText]: a fast path
  /// that avoids allocating `String.fromCharCode` on cache hit, with the
  /// actual entry living in `_glyphs` so it stays shared with text-keyed
  /// callers.
  GlyphEntry addCodepoint(
    int codepoint, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    final key = (codepoint: codepoint, bold: bold, italic: italic, span: span);
    final existing = _codepoints[key];
    if (existing != null) return existing;

    final entry = addText((
      text: String.fromCharCode(codepoint),
      bold: bold,
      italic: italic,
    ), span: span);
    _codepoints[key] = entry;
    return entry;
  }

  /// Returns or creates an emoji glyph for [key].
  GlyphEntry addEmoji(TextGlyphKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    return _emoji[cacheKey] ??= _emojiRasterizer.rasterizeEmoji(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
  }

  /// Returns or creates a text glyph for [key].
  GlyphEntry addText(TextGlyphKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    return _text[cacheKey] ??= _textRasterizer.rasterizeText(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
  }

  void clear() {
    _text.clear();
    _emoji.clear();
    _codepoints.clear();
  }

  void preseedAscii() {
    for (final (bold, italic) in [
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    ]) {
      for (var codepoint = 0x21; codepoint <= 0x7E; codepoint++) {
        addCodepoint(codepoint, bold: bold, italic: italic);
      }
    }
  }
}
