import 'dart:ui';

import 'glyph_atlas_config.dart';
import 'glyph_atlas_texture.dart';
import 'glyph_sprite_rasterizer.dart';
import 'glyph_text_rasterizer.dart';

export 'glyph_atlas_texture.dart' show GlyphAtlasFullException;

/// Rasterizes glyphs into a packed atlas texture.
///
/// Owns the shared [GlyphAtlasTexture] and coordinates specialized
/// rasterizers for text/emoji and built-in sprites/decorations. The atlas
/// starts at 1024x1024 and grows up to 4096x4096 as glyphs are added.
class GlyphRasterizer {
  final GlyphAtlasTexture _texture;
  late final _text = GlyphTextRasterizer(_texture);
  late final _sprites = GlyphSpriteRasterizer(_texture);

  GlyphRasterizer({
    int initialSize = GlyphAtlasTexture.defaultInitialSize,
    int maxSize = GlyphAtlasTexture.defaultMaxSize,
  }) : _texture = GlyphAtlasTexture(initialSize: initialSize, maxSize: maxSize);

  Image? get decorationImage => _texture.image;

  Image? get emojiImage => _texture.image;

  Image? get image => _texture.image;

  Image? get spriteImage => _texture.image;

  GlyphSpriteRasterizer get spriteRasterizer => _sprites;

  Image? get textImage => _texture.image;

  GlyphTextRasterizer get textRasterizer => _text;

  void clear() {
    _text.clear();
    _sprites.clear();
    _texture.clear();
  }

  void configure(GlyphAtlasConfig config) {
    _text.configure(config);
    _sprites.configure(config);
  }

  void dispose() {
    _text.clear();
    _sprites.clear();
    _texture.dispose();
  }

  /// Composites pending glyphs and decorations into the atlas image.
  void ensureImage() {
    if (!_text.hasPending && !_sprites.hasPending) return;

    _texture.replaceImage((canvas) {
      _text.compositePending(canvas);
      _sprites.compositePending(canvas);
    });
  }
}
