enum GlyphEntryLane { text, emoji, sprite, decoration }

/// Position and metadata of a rendered glyph in the atlas texture.
///
/// Coordinates are in physical pixels (logical pixels * device pixel ratio).
/// The source rectangle ([srcLeft], [srcTop], [srcRight], [srcBottom]) maps
/// directly to the [Canvas.drawRawAtlas] source rect parameter.
final class GlyphEntry {
  /// Left edge of the glyph region in the atlas, in physical pixels.
  final double srcLeft;

  /// Top edge of the glyph region in the atlas, in physical pixels.
  final double srcTop;

  /// Right edge of the glyph region in the atlas, in physical pixels.
  final double srcRight;

  /// Bottom edge of the glyph region in the atlas, in physical pixels.
  final double srcBottom;

  /// Vertical offset from the cell top to the glyph baseline.
  ///
  /// For text glyphs, computed as `baseline - alphabeticBaseline`.
  /// For emoji, centered vertically within the cell.
  final double bearingY;

  /// Horizontal offset to center the glyph within its cell span.
  ///
  /// Non-zero for wide characters (CJK) whose natural advance width
  /// differs from the allocated cell width.
  final double bearingX;

  /// Atlas lane that owns this entry's source pixels.
  final GlyphEntryLane lane;

  /// Whether this glyph is a full-color emoji.
  ///
  /// Emoji glyphs use [BlendMode.src] during painting (no tinting),
  /// while text glyphs use [BlendMode.modulate] for per-sprite coloring.
  bool get isEmoji => lane == GlyphEntryLane.emoji;

  /// Whether this glyph lives in the built-in sprite atlas.
  bool get isSprite => lane == GlyphEntryLane.sprite;

  const GlyphEntry({
    required this.srcLeft,
    required this.srcTop,
    required this.srcRight,
    required this.srcBottom,
    required this.bearingY,
    this.bearingX = 0.0,
    this.lane = GlyphEntryLane.text,
  });
}
