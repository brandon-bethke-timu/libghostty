import 'dart:ui' show FontWeight, Image;

import 'package:libghostty/libghostty.dart';

import '../../foundation.dart';
import '../sprite/sprite_face.dart';
import 'glyph_entry.dart';
import 'glyph_rasterizer.dart';

export 'glyph_entry.dart';

/// Lookup key for a cached glyph. Two glyphs with the same text, bold,
/// and italic state share the same atlas entry.
typedef TextGlyphKey = ({String text, bool bold, bool italic});

typedef _GlyphCacheKey = ({String text, bool bold, bool italic, int span});
typedef _CodepointGlyphKey = ({
  int codepoint,
  bool bold,
  bool italic,
  int span,
});
typedef _SpriteKey = ({int codepoint, int span});

/// Glyph cache backed by a [GlyphRasterizer] atlas texture.
///
/// Caches rasterized glyphs by [TextGlyphKey] for text/emoji runs and by
/// codepoint for the single-codepoint fast path. On first use with new
/// cell dimensions, pre-seeds all printable ASCII (0x21-0x7E) in every
/// bold/italic combination, the entire built-in sprite registry, and every
/// underline decoration style.
///
/// Lifecycle: construct, [configure] with DPR and cell dimensions,
/// [addText]/[addEmoji]/[addCodepoint] per frame, [ensureImage] to
/// composite pending glyphs, [updateFont] on theme change, [dispose] when
/// detached.
class GlyphAtlas {
  final Map<_GlyphCacheKey, GlyphEntry> _glyphs = {};
  final Map<UnderlineStyle, GlyphEntry> _decorations = {};
  final Map<_SpriteKey, GlyphEntry> _spriteCodepoints = {};
  final Map<_CodepointGlyphKey, GlyphEntry> _codepoints = {};
  final _rasterizer = GlyphRasterizer();
  final _spriteFace = SpriteFace();

  double _fontSize;
  String _fontFamily;
  FontWeight _fontWeight;
  List<String> _fontFamilyFallback;
  var _dpr = 1.0;
  var _metrics = const CellMetrics(cellWidth: 0, cellHeight: 0, baseline: 0);

  GlyphAtlas({
    required double fontSize,
    required String fontFamily,
    required List<String> fontFamilyFallback,
    FontWeight fontWeight = FontWeight.normal,
  }) : _fontSize = fontSize,
       _fontFamily = fontFamily,
       _fontWeight = fontWeight,
       _fontFamilyFallback = fontFamilyFallback;

  int get cacheSize => _glyphs.length + _spriteCodepoints.length;

  double get devicePixelRatio => _dpr;

  Image? get image => _rasterizer.image;

  /// Whether [codepoint] has a built-in sprite glyph.
  ///
  /// Sprite codepoints render from geometry regardless of how libghostty
  /// classifies the cell (wide, emoji, etc.). Callers route through
  /// [addCodepoint] to retrieve the entry; this predicate lets callers
  /// pick the right output channel before calling.
  bool hasSprite(int codepoint) => _spriteFace.hasCodepoint(codepoint);

  /// Returns or creates a text glyph for [key].
  GlyphEntry addText(TextGlyphKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    return _glyphs[cacheKey] ??= _rasterizer.rasterizeText(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
  }

  /// Returns or creates an emoji glyph for [key].
  ///
  /// Shares the same cache slot as [addText] for matching
  /// `(text, bold, italic, span)`: classification of a given grapheme is
  /// consistent within a frame, so the first writer wins and later
  /// callers reuse the same atlas region. This is what lets the cursor
  /// reuse the cell's atlas slot instead of rasterizing a duplicate that
  /// wouldn't be composited yet.
  GlyphEntry addEmoji(TextGlyphKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    return _glyphs[cacheKey] ??= _rasterizer.rasterizeEmoji(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
  }

  /// Dispatches to [addEmoji] when [emoji] is true, otherwise [addText].
  ///
  /// Convenience for call sites that classify text vs. emoji at runtime
  /// (e.g. wide-cell dispatch) and want to defer the branch to the atlas.
  GlyphEntry add(TextGlyphKey key, {int span = 1, bool emoji = false}) {
    return emoji ? addEmoji(key, span: span) : addText(key, span: span);
  }

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
  }) {
    final glyph = _spriteFace.glyphFor(codepoint);
    if (glyph != null) {
      final spriteKey = (codepoint: codepoint, span: span);
      return _spriteCodepoints[spriteKey] ??= _rasterizer.rasterizeSprite(
        glyph,
        span: span,
      );
    }

    final codepointKey = (
      codepoint: codepoint,
      bold: bold,
      italic: italic,
      span: span,
    );
    final existing = _codepoints[codepointKey];
    if (existing != null) return existing;

    final entry = addText((
      text: String.fromCharCode(codepoint),
      bold: bold,
      italic: italic,
    ), span: span);
    _codepoints[codepointKey] = entry;
    return entry;
  }

  /// Returns or creates a decoration sprite for the given underline [style].
  GlyphEntry addDecoration(UnderlineStyle style) {
    return _decorations[style] ??= _rasterizer.rasterizeDecoration(style);
  }

  void clear() {
    _glyphs.clear();
    _codepoints.clear();
    _spriteCodepoints.clear();
    _decorations.clear();
    _rasterizer.clear();
  }

  /// Sets DPR and cell dimensions. Returns true if changed.
  ///
  /// Clears all cached glyphs and pre-seeds the ASCII and box-drawing
  /// ranges when any parameter differs from the current configuration.
  bool configure({required double dpr, required CellMetrics metrics}) {
    if (dpr == _dpr && metrics == _metrics) return false;
    _dpr = dpr;
    _metrics = metrics;
    _reconfigure();
    return true;
  }

  void dispose() {
    _glyphs.clear();
    _codepoints.clear();
    _spriteCodepoints.clear();
    _decorations.clear();
    _rasterizer.dispose();
  }

  /// Composites pending glyphs into the atlas texture.
  void ensureImage() => _rasterizer.ensureImage();

  /// Updates the font and clears the atlas if changed.
  ///
  /// Returns true if the font was actually different and the atlas was cleared.
  bool updateFont({
    required double fontSize,
    required String fontFamily,
    required FontWeight fontWeight,
    required List<String> fontFamilyFallback,
  }) {
    if (fontSize == _fontSize &&
        fontWeight == _fontWeight &&
        fontFamily == _fontFamily &&
        _listEquals(_fontFamilyFallback, fontFamilyFallback)) {
      return false;
    }
    _fontSize = fontSize;
    _fontFamily = fontFamily;
    _fontWeight = fontWeight;
    _fontFamilyFallback = fontFamilyFallback;
    _reconfigure();
    return true;
  }

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

    for (final cp in _spriteFace.supportedCodepoints) {
      addCodepoint(cp, bold: false, italic: false);
    }

    for (final style in UnderlineStyle.values) {
      if (style != .none) addDecoration(style);
    }

    ensureImage();
  }

  /// Applies current font/metrics to the rasterizer, clears all caches,
  /// and pre-seeds if valid dimensions are available.
  void _reconfigure() {
    _rasterizer.configure(
      fontSize: _fontSize,
      fontWeight: _fontWeight,
      fontFamily: _fontFamily,
      fontFamilyFallback: _fontFamilyFallback,
      metrics: _metrics,
      dpr: _dpr,
    );
    clear();
    if (_metrics.cellWidth > 0 && _metrics.cellHeight > 0) _preseed();
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
