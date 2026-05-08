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
/// Caches rasterized glyphs by [TextGlyphKey] for text/emoji runs and by
/// codepoint for the single-codepoint fast path. On first use with new
/// cell dimensions, pre-seeds all printable ASCII (0x21-0x7E) in every
/// bold/italic combination, the entire built-in sprite registry, and every
/// underline decoration style.
///
/// Lifecycle: construct with a [GlyphAtlasConfig],
/// [addText]/[addEmoji]/[addCodepoint] per frame, [ensureImage] to composite
/// pending glyphs, [dispose] when detached.
class GlyphAtlas {
  final _rasterizer = GlyphRasterizer();
  late final _cache = GlyphAtlasCache(_rasterizer);

  final GlyphAtlasConfig _config;

  GlyphAtlas(this._config) {
    _rasterizer.configure(_config);
    if (_config.metrics.cellWidth > 0 && _config.metrics.cellHeight > 0) {
      _preseed();
    }
  }

  int get cacheSize => _cache.size;

  double get devicePixelRatio => _config.devicePixelRatio;

  Image? get image => _rasterizer.image;

  /// Dispatches to [addEmoji] when [emoji] is true, otherwise [addText].
  ///
  /// Convenience for call sites that classify text vs. emoji at runtime
  /// (e.g. wide-cell dispatch) and want to defer the branch to the atlas.
  GlyphEntry add(TextGlyphKey key, {int span = 1, bool emoji = false}) =>
      _cache.add(key, span: span, emoji: emoji);

  /// Returns or creates a glyph for a single [codepoint].
  ///
  /// Built-in sprite codepoints bypass font rasterization entirely and
  /// render from geometry. For non-sprite codepoints, [_codepoints] acts
  /// as a write-through memo over [addText]: a fast path that avoids
  /// allocating `String.fromCharCode` on cache hit, with the actual entry
  /// living in `_glyphs` so it stays shared with text-keyed callers.
  GlyphEntry addCodepoint(
    int codepoint, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) => _cache.addCodepoint(codepoint, bold: bold, italic: italic, span: span);

  /// Returns or creates a decoration sprite for the given underline [style].
  GlyphEntry addDecoration(UnderlineStyle style) => _cache.addDecoration(style);

  /// Returns or creates an emoji glyph for [key].
  ///
  /// Shares the same cache slot as [addText] for matching
  /// `(text, bold, italic, span)`: classification of a given grapheme is
  /// consistent within a frame, so the first writer wins and later
  /// callers reuse the same atlas region. This is what lets the cursor
  /// reuse the cell's atlas slot instead of rasterizing a duplicate that
  /// wouldn't be composited yet.
  GlyphEntry addEmoji(TextGlyphKey key, {int span = 1}) =>
      _cache.addEmoji(key, span: span);

  /// Returns or creates a text glyph for [key].
  GlyphEntry addText(TextGlyphKey key, {int span = 1}) =>
      _cache.addText(key, span: span);

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
  /// The entire sprite registry is also pre-seeded: lazy-rasterizing
  /// sprites would shift every later glyph's atlas position, and Skia's
  /// hinted text rasterization is not invariant under that shift, which
  /// drifts emoji/CJK anti-aliasing and breaks goldens that have nothing
  /// to do with the sprite path. All underline styles are pre-seeded too
  /// so decoration rendering never triggers a mid-frame atlas composite.
  void _preseed() {
    for (final (bold, italic) in [
      (false, false),
      (true, false),
      (false, true),
      (true, true),
    ]) {
      for (var cp = 0x21; cp <= 0x7E; cp++) {
        addCodepoint(cp, bold: bold, italic: italic);
      }
    }

    for (final cp in _cache.supportedSpriteCodepoints) {
      addCodepoint(cp, bold: false, italic: false);
    }

    for (final style in UnderlineStyle.values) {
      if (style != .none) addDecoration(style);
    }

    ensureImage();
  }
}
