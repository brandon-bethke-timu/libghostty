import 'dart:ui';

import 'glyph_atlas_config.dart';
import 'glyph_atlas_texture.dart';
import 'glyph_sprite_rasterizer.dart';
import 'glyph_text_rasterizer.dart';

export 'glyph_atlas_texture.dart' show GlyphAtlasFullException;

/// Rasterizes glyphs into lane-specific packed atlas textures.
///
/// Owns the backing textures for text, emoji, built-in sprites, and
/// decorations. Each texture starts at 256x256 and grows up to 4096x4096
/// as glyphs are added.
class GlyphRasterizer {
  final GlyphAtlasTexture _textTexture;
  final GlyphAtlasTexture _emojiTexture;
  final GlyphAtlasTexture _spriteTexture;
  final GlyphAtlasTexture _decorationTexture;

  late final _text = GlyphTextRasterizer(_textTexture);
  late final _emoji = GlyphTextRasterizer(_emojiTexture);
  late final _sprites = GlyphSpriteRasterizer(_spriteTexture);
  late final _decorations = GlyphSpriteRasterizer(_decorationTexture);

  GlyphRasterizer({
    int initialSize = GlyphAtlasTexture.defaultInitialSize,
    int maxSize = GlyphAtlasTexture.defaultMaxSize,
  }) : _textTexture = GlyphAtlasTexture(
         initialSize: initialSize,
         maxSize: maxSize,
       ),
       _emojiTexture = GlyphAtlasTexture(
         initialSize: initialSize,
         maxSize: maxSize,
       ),
       _spriteTexture = GlyphAtlasTexture(
         initialSize: initialSize,
         maxSize: maxSize,
       ),
       _decorationTexture = GlyphAtlasTexture(
         initialSize: initialSize,
         maxSize: maxSize,
       );

  GlyphSpriteRasterizer get decorationRasterizer => _decorations;

  Image? get decorationImage => _decorationTexture.image;

  GlyphTextRasterizer get emojiRasterizer => _emoji;

  Image? get emojiImage => _emojiTexture.image;

  Image? get spriteImage => _spriteTexture.image;

  GlyphSpriteRasterizer get spriteRasterizer => _sprites;

  Image? get textImage => _textTexture.image;

  GlyphTextRasterizer get textRasterizer => _text;

  void clear() {
    _text.clear();
    _emoji.clear();
    _sprites.clear();
    _decorations.clear();
    _textTexture.clear();
    _emojiTexture.clear();
    _spriteTexture.clear();
    _decorationTexture.clear();
  }

  void configure(GlyphAtlasConfig config) {
    _text.configure(config);
    _emoji.configure(config);
    _sprites.configure(config);
    _decorations.configure(config);
  }

  void dispose() {
    _text.clear();
    _emoji.clear();
    _sprites.clear();
    _decorations.clear();
    _textTexture.dispose();
    _emojiTexture.dispose();
    _spriteTexture.dispose();
    _decorationTexture.dispose();
  }

  /// Composites pending glyphs and decorations into their lane images.
  void ensureImage() {
    if (_text.hasPending) _textTexture.replaceImage(_text.compositePending);
    if (_emoji.hasPending) _emojiTexture.replaceImage(_emoji.compositePending);
    if (_sprites.hasPending) {
      _spriteTexture.replaceImage(_sprites.compositePending);
    }
    if (_decorations.hasPending) {
      _decorationTexture.replaceImage(_decorations.compositePending);
    }
  }
}
