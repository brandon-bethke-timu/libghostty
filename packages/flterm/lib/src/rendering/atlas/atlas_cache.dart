import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import '../sprite/sprite_face.dart';
import 'atlas_entry.dart';
import 'lanes/decoration_lane.dart';
import 'lanes/emoji_lane.dart';
import 'lanes/sprite_lane.dart';
import 'lanes/text_lane.dart';

/// Lookup key for a cached text glyph. Two glyphs with the same text, bold,
/// and italic state share the same atlas entry.
typedef TextAtlasKey = ({String text, bool bold, bool italic});
typedef _CodepointKey = ({int codepoint, bool bold, bool italic, int span});
typedef _TextKey = ({String text, bool bold, bool italic, int span});
typedef _SpriteKey = ({int codepoint, int span});

/// Caches atlas entries and delegates rasterization on cache miss.
class AtlasCache {
  final SpriteFace _spriteFace;
  final TextLane _textLane;
  final EmojiLane _emojiLane;
  final SpriteLane _spriteLane;
  final DecorationLane _decorationLane;

  final Map<_TextKey, AtlasEntry> _text = {};
  final Map<_TextKey, AtlasEntry> _emoji = {};
  final Map<_SpriteKey, AtlasEntry> _sprites = {};
  final Map<_CodepointKey, AtlasEntry> _codepoints = {};
  final Map<UnderlineStyle, AtlasEntry> _decorations = {};

  AtlasCache({
    required TextLane textLane,
    required EmojiLane emojiLane,
    required SpriteLane spriteLane,
    required DecorationLane decorationLane,
    SpriteFace? spriteFace,
  }) : _textLane = textLane,
       _emojiLane = emojiLane,
       _spriteLane = spriteLane,
       _decorationLane = decorationLane,
       _spriteFace = spriteFace ?? SpriteFace();

  int get size {
    return _text.length + _emoji.length + _sprites.length + _decorations.length;
  }

  /// Returns or creates a text or emoji glyph for [key].
  AtlasEntry add(TextAtlasKey key, {int span = 1, bool emoji = false}) {
    return emoji ? _addEmoji(key, span: span) : _addText(key, span: span);
  }

  /// Returns or creates a glyph for a single [codepoint].
  ///
  /// Built-in sprite codepoints bypass font rasterization entirely and
  /// render from geometry. Non-sprite codepoints route through the text
  /// lane so single-codepoint and text-keyed callers share entries.
  AtlasEntry addCodepoint(
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
  AtlasEntry addDecoration(UnderlineStyle style) {
    return _decorations[style] ??= _decorationLane.rasterizeDecoration(style);
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
  void preseedCommonEntries() {
    _preseedAscii();
    _preseedDecorations();
  }

  AtlasEntry _addEmoji(TextAtlasKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    return _emoji[cacheKey] ??= _emojiLane.rasterizeEmoji(
      key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
  }

  AtlasEntry? _addSpriteCodepoint(int codepoint, {int span = 1}) {
    final glyph = _spriteFace.glyphFor(codepoint);
    if (glyph == null) return null;

    final key = (codepoint: codepoint, span: span);
    return _sprites[key] ??= _spriteLane.rasterizeSprite(glyph, span: span);
  }

  AtlasEntry _addText(TextAtlasKey key, {int span = 1}) {
    final cacheKey = (
      text: key.text,
      bold: key.bold,
      italic: key.italic,
      span: span,
    );
    return _text[cacheKey] ??= _textLane.rasterizeText(
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
