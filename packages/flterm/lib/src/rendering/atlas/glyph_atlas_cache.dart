import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import '../sprite/sprite_face.dart';
import 'glyph_entry.dart';
import 'glyph_sprite_rasterizer.dart';
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
typedef _SpriteKey = ({int codepoint, int span});

/// Caches glyph atlas entries and delegates rasterization on cache miss.
class GlyphAtlasCache {
  final GlyphTextRasterizer _textRasterizer;
  final GlyphTextRasterizer _emojiRasterizer;
  final GlyphSpriteRasterizer _spriteRasterizer;
  final GlyphSpriteRasterizer _decorationRasterizer;
  final SpriteFace _spriteFace;

  final Map<_GlyphCacheKey, GlyphEntry> _text = {};
  final Map<_GlyphCacheKey, GlyphEntry> _emoji = {};
  final Map<_CodepointGlyphKey, GlyphEntry> _codepoints = {};
  final Map<_SpriteKey, GlyphEntry> _sprites = {};
  final Map<UnderlineStyle, GlyphEntry> _decorations = {};

  GlyphAtlasCache({
    required GlyphTextRasterizer textRasterizer,
    required GlyphTextRasterizer emojiRasterizer,
    required GlyphSpriteRasterizer spriteRasterizer,
    required GlyphSpriteRasterizer decorationRasterizer,
    SpriteFace? spriteFace,
  }) : _textRasterizer = textRasterizer,
       _emojiRasterizer = emojiRasterizer,
       _spriteRasterizer = spriteRasterizer,
       _decorationRasterizer = decorationRasterizer,
       _spriteFace = spriteFace ?? SpriteFace();

  int get size =>
      _text.length + _emoji.length + _sprites.length + _decorations.length;

  /// Returns or creates a text or emoji glyph for [key].
  GlyphEntry add(TextGlyphKey key, {int span = 1, bool emoji = false}) {
    return emoji ? _addEmoji(key, span: span) : _addText(key, span: span);
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
    final sprite = _addSpriteCodepoint(codepoint, span: span);
    if (sprite != null) return sprite;

    final key = (codepoint: codepoint, bold: bold, italic: italic, span: span);
    final existing = _codepoints[key];
    if (existing != null) return existing;

    final entry = _addText((
      text: String.fromCharCode(codepoint),
      bold: bold,
      italic: italic,
    ), span: span);
    _codepoints[key] = entry;
    return entry;
  }

  /// Returns or creates a decoration sprite for the given underline [style].
  GlyphEntry addDecoration(UnderlineStyle style) {
    return _decorations[style] ??= _decorationRasterizer.rasterizeDecoration(
      style,
    );
  }

  void clear() {
    _text.clear();
    _emoji.clear();
    _codepoints.clear();
    _sprites.clear();
    _decorations.clear();
  }

  bool hasSprite(int codepoint) => _spriteFace.hasCodepoint(codepoint);

  /// Pre-seeds glyphs that are expected to appear in nearly every terminal.
  ///
  /// Printable ASCII is seeded for every style because it appears in nearly
  /// every frame. Built-in sprites stay lazy so they do not consume memory
  /// until a terminal actually renders them. Decorations are seeded because
  /// they are few and avoid mid-frame atlas composites.
  void preseedCommonGlyphs() {
    _preseedAscii();
    _preseedDecorations();
  }

  GlyphEntry _addEmoji(TextGlyphKey key, {int span = 1}) {
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

  GlyphEntry? _addSpriteCodepoint(int codepoint, {int span = 1}) {
    final glyph = _spriteFace.glyphFor(codepoint);
    if (glyph == null) return null;

    final key = (codepoint: codepoint, span: span);
    return _sprites[key] ??= _spriteRasterizer.rasterizeSprite(
      glyph,
      span: span,
    );
  }

  GlyphEntry _addText(TextGlyphKey key, {int span = 1}) {
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

  void _preseedAscii() {
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

  void _preseedDecorations() {
    for (final style in UnderlineStyle.values) {
      if (style != .none) addDecoration(style);
    }
  }
}
