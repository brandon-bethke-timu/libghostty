import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import '../sprite/sprite_face.dart';
import 'glyph_entry.dart';
import 'glyph_sprite_rasterizer.dart';

typedef _SpriteKey = ({int codepoint, int span});

/// Atlas lane for built-in sprite glyphs and generated decoration sprites.
class GlyphSpriteAtlasLane {
  final SpriteFace _spriteFace;
  final GlyphSpriteRasterizer _spriteRasterizer;
  final GlyphSpriteRasterizer _decorationRasterizer;
  final Map<_SpriteKey, GlyphEntry> _codepoints = {};
  final Map<UnderlineStyle, GlyphEntry> _decorations = {};

  GlyphSpriteAtlasLane({
    required GlyphSpriteRasterizer spriteRasterizer,
    required GlyphSpriteRasterizer decorationRasterizer,
    SpriteFace? spriteFace,
  }) : _spriteRasterizer = spriteRasterizer,
       _decorationRasterizer = decorationRasterizer,
       _spriteFace = spriteFace ?? SpriteFace();

  int get size => _codepoints.length + _decorations.length;

  Iterable<int> get supportedCodepoints => _spriteFace.supportedCodepoints;

  GlyphEntry? addCodepoint(int codepoint, {int span = 1}) {
    final glyph = _spriteFace.glyphFor(codepoint);
    if (glyph == null) return null;

    final key = (codepoint: codepoint, span: span);
    return _codepoints[key] ??= _spriteRasterizer.rasterizeSprite(
      glyph,
      span: span,
    );
  }

  /// Returns or creates a decoration sprite for the given underline [style].
  GlyphEntry addDecoration(UnderlineStyle style) {
    return _decorations[style] ??= _decorationRasterizer.rasterizeDecoration(
      style,
    );
  }

  void clear() {
    _codepoints.clear();
    _decorations.clear();
  }

  bool hasCodepoint(int codepoint) => _spriteFace.hasCodepoint(codepoint);

  void preseedCodepoints() {
    for (final codepoint in supportedCodepoints) {
      addCodepoint(codepoint);
    }
  }

  void preseedDecorations() {
    for (final style in UnderlineStyle.values) {
      if (style != .none) addDecoration(style);
    }
  }
}
