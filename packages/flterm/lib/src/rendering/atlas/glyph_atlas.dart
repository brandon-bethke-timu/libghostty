import 'dart:ui' show Image;

import 'package:libghostty/libghostty.dart';

import 'glyph_atlas_cache.dart';
import 'glyph_atlas_config.dart';
import 'glyph_entry.dart';
import 'glyph_rasterizer.dart';

export 'glyph_atlas_cache.dart' show TextGlyphKey;
export 'glyph_atlas_config.dart';
export 'glyph_entry.dart';

/// Glyph cache backed by a [GlyphRasterizer] atlas texture.
///
/// Caches rasterized text, emoji, sprite, and decoration glyphs. On first
/// use with new cell dimensions, pre-seeds common glyphs so steady-state
/// rendering avoids the most common cache misses.
///
/// Lifecycle: construct with a [GlyphAtlasConfig],
/// [add]/[addCodepoint] per frame, [ensureImage] to composite pending glyphs,
/// [dispose] when detached.
class GlyphAtlas {
  final _rasterizer = GlyphRasterizer();
  late final _cache = GlyphAtlasCache(
    textRasterizer: _rasterizer.textRasterizer,
    emojiRasterizer: _rasterizer.emojiRasterizer,
    spriteRasterizer: _rasterizer.spriteRasterizer,
    decorationRasterizer: _rasterizer.decorationRasterizer,
  );

  final GlyphAtlasConfig _config;

  GlyphAtlas(this._config) {
    _rasterizer.configure(_config);
    if (_config.metrics.cellWidth > 0 && _config.metrics.cellHeight > 0) {
      _preseed();
    }
  }

  int get cacheSize => _cache.size;

  Image? get decorationImage => _rasterizer.decorationImage;

  double get devicePixelRatio => _config.devicePixelRatio;

  Image? get emojiImage => _rasterizer.emojiImage;

  Image? get spriteImage => _rasterizer.spriteImage;

  Image? get textImage => _rasterizer.textImage;

  Image? imageFor(GlyphEntry entry) => switch (entry.lane) {
    GlyphEntryLane.text => textImage,
    GlyphEntryLane.emoji => emojiImage,
    GlyphEntryLane.sprite => spriteImage,
    GlyphEntryLane.decoration => decorationImage,
  };

  /// Returns or creates a glyph for [key].
  ///
  /// Convenience for call sites that classify text vs. emoji at runtime
  /// (e.g. wide-cell dispatch) and want to defer the branch to the atlas.
  GlyphEntry add(TextGlyphKey key, {int span = 1, bool emoji = false}) =>
      _cache.add(key, span: span, emoji: emoji);

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
  }) => _cache.addCodepoint(codepoint, bold: bold, italic: italic, span: span);

  /// Returns or creates a decoration sprite for the given underline [style].
  GlyphEntry addDecoration(UnderlineStyle style) => _cache.addDecoration(style);

  void dispose() {
    _cache.clear();
    _rasterizer.dispose();
  }

  /// Composites pending glyphs into the atlas texture.
  void ensureImage() => _rasterizer.ensureImage();

  /// Whether [codepoint] has a built-in sprite glyph.
  ///
  /// Sprite codepoints render from geometry regardless of how libghostty
  /// classifies the cell (wide, emoji, etc.). Callers route through
  /// [addCodepoint] to retrieve the entry; this predicate lets callers
  /// pick the right output channel before calling.
  bool hasSprite(int codepoint) => _cache.hasSprite(codepoint);

  /// Pre-seeds the atlas with glyphs that will almost certainly be needed.
  ///
  /// Rasterizing all printable ASCII in every bold/italic combination up
  /// front avoids per-frame cache misses for the most common characters.
  /// Built-in sprite glyphs are rasterized lazily into their own atlas
  /// texture, so first use no longer shifts text/emoji atlas positions.
  /// All underline styles are pre-seeded so decoration rendering never
  /// triggers a mid-frame atlas composite.
  void _preseed() {
    _cache.preseedCommonGlyphs();
    ensureImage();
  }
}
