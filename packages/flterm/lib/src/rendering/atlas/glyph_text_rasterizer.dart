import 'dart:math';
import 'dart:ui';

import 'glyph_atlas_config.dart';
import 'glyph_atlas_texture.dart';
import 'glyph_entry.dart';

/// Rasterizes font-backed text or emoji glyphs into an atlas texture.
class GlyphTextRasterizer {
  final GlyphAtlasTexture _texture;
  final List<(Paragraph, GlyphEntry)> _pending = [];

  var _fontFamily = '';
  var _fontWeight = FontWeight.normal;
  var _fontFamilyFallback = const <String>[];
  var _pxCellWidth = 0.0;
  var _pxCellHeight = 0.0;
  var _pxFontSize = 0.0;
  var _pxBaseline = 0.0;
  var _pxItalicOverhang = 0.0;

  GlyphTextRasterizer(this._texture);

  bool get hasPending => _pending.isNotEmpty;

  void clear() {
    for (final (paragraph, _) in _pending) {
      paragraph.dispose();
    }
    _pending.clear();
  }

  void configure(GlyphAtlasConfig config) {
    _fontFamily = config.fontFamily;
    _fontWeight = config.fontWeight;
    _fontFamilyFallback = config.fontFamilyFallback;
    _pxCellWidth = config.metrics.cellWidth * config.devicePixelRatio;
    _pxCellHeight = config.metrics.cellHeight * config.devicePixelRatio;
    _pxBaseline = config.metrics.baseline * config.devicePixelRatio;
    _pxFontSize = config.fontSize * config.devicePixelRatio;
    _pxItalicOverhang = max(1.0, (_pxFontSize * 0.15).ceilToDouble());
  }

  void compositePending(Canvas canvas) {
    for (final (paragraph, entry) in _pending) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          entry.srcLeft,
          entry.srcTop,
          entry.srcRight,
          entry.srcBottom,
        ),
      );
      if (entry.isEmoji) {
        _compositeEmoji(canvas, paragraph, entry);
      } else {
        canvas.drawParagraph(
          paragraph,
          Offset(entry.srcLeft + entry.bearingX, entry.srcTop + entry.bearingY),
        );
      }
      canvas.restore();
      paragraph.dispose();
    }
    _pending.clear();
  }

  /// Builds a full-color emoji paragraph for [text], packs it into the
  /// atlas, and returns a [GlyphEntry] with its source coordinates.
  ///
  /// Emoji are rasterized in color and composited with uniform scaling to
  /// fit within the cell bounds; tinting is not applied at draw time.
  GlyphEntry rasterizeEmoji(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    return _rasterizeText(
      text,
      bold: bold,
      italic: italic,
      span: span,
      emoji: true,
    );
  }

  /// Builds a paragraph for [text], packs it into the atlas, and returns
  /// a [GlyphEntry] with its source coordinates.
  ///
  /// The glyph is not composited into the atlas image until [compositePending]
  /// is called. [span] controls how many cell widths the glyph occupies
  /// (2 for wide/CJK characters).
  GlyphEntry rasterizeText(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    return _rasterizeText(text, bold: bold, italic: italic, span: span);
  }

  GlyphEntry _rasterizeText(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
    bool emoji = false,
  }) {
    final pxCellWidth = (_pxCellWidth * span).ceil().toDouble();
    final pxHeight = _pxCellHeight.ceil().toDouble();

    // The sprite is positioned at the cell origin; the overhang width
    // overlaps into the adjacent cell's space without shifting the glyph.
    final overhang = (italic && !emoji) ? _pxItalicOverhang : 0.0;
    final pxWidth = pxCellWidth + overhang;

    // Emoji: fit within the smaller of cell height and cell width, then
    // shrink 5% to prevent clipping at cell edges. Text: use font size.
    final size = emoji
        ? min(_pxCellHeight, _pxCellWidth * span) * 0.95
        : _pxFontSize;

    // All glyphs use textAlign: .start. Centering is handled separately
    // per glyph type: bearingX for CJK, _compositeEmoji for emoji.
    // Using .center here would conflict with both of those and produce
    // double-centering artifacts.
    //
    // The user's font family and fallbacks are always passed, even for
    // emoji. If the primary font has the emoji glyph (e.g. Nerd Fonts),
    // it will be used; otherwise Flutter falls through the fallback list
    // and ultimately to the system emoji font.
    final paragraph =
        (ParagraphBuilder(
                ParagraphStyle(
                  fontSize: size,
                  fontFamily: _fontFamily,
                  textAlign: .start,
                ),
              )
              ..pushStyle(
                TextStyle(
                  color: const Color(0xFFFFFFFF),
                  fontSize: size,
                  fontFamily: _fontFamily,
                  decoration: TextDecoration.none,
                  fontWeight: bold ? .bold : _fontWeight,
                  fontStyle: italic ? .italic : .normal,
                  fontFamilyFallback: _fontFamilyFallback,
                ),
              )
              ..addText(text)
              ..pop())
            .build()
          // Text uses unconstrained width so multi-character operator
          // runs (ligatures like =>, !=) never line-wrap; the clip rect
          // in compositePending() limits the visible area to the cell span.
          // Emoji use constrained width so Flutter sizes the glyph
          // relative to the cell before _compositeEmoji scales it.
          ..layout(
            ParagraphConstraints(width: emoji ? pxCellWidth : .infinity),
          );

    // Emoji are vertically centered within the cell. Text glyphs are
    // positioned by baseline alignment so all characters on a line share
    // a consistent baseline regardless of individual glyph height.
    final bearingY = emoji
        ? max(0.0, (_pxCellHeight - paragraph.height) / 2)
        : _pxBaseline - paragraph.alphabeticBaseline;

    // Wide (CJK) glyphs are centered horizontally within the multi-cell
    // sprite. Single-cell glyphs don't need this because monospace fonts
    // already position them correctly. Emoji centering is handled in
    // _compositeEmoji instead, since it also involves scaling.
    final bearingX = (!emoji && span > 1)
        ? max(0.0, (pxCellWidth - paragraph.maxIntrinsicWidth) / 2)
        : 0.0;

    late final GlyphEntry entry;
    try {
      entry = _texture.allocate(
        width: pxWidth,
        height: pxHeight,
        bearingY: bearingY,
        bearingX: bearingX,
        lane: emoji ? GlyphEntryLane.emoji : GlyphEntryLane.text,
      );
    } catch (_) {
      paragraph.dispose();
      rethrow;
    }

    _pending.add((paragraph, entry));
    return entry;
  }

  /// Scales and centers an emoji paragraph within its atlas cell.
  ///
  /// The emoji is uniformly scaled by whichever axis is tighter (width
  /// or height), then centered on both axes. This pairs with the
  /// `textAlign: .start` choice in [_rasterizeText]: the paragraph is
  /// left-aligned so all centering happens here. Using `.center` would
  /// double-center and shift the glyph off its intended position.
  ///
  /// Centering uses the actual rendered emoji dimensions
  /// (emojiWidth * scale) rather than cell dimensions, because when
  /// scaling is height-constrained the scaled width differs from the
  /// cell width.
  void _compositeEmoji(Canvas canvas, Paragraph paragraph, GlyphEntry entry) {
    final cellWidth = entry.srcRight - entry.srcLeft;
    final cellHeight = entry.srcBottom - entry.srcTop;
    final emojiWidth = max(paragraph.maxIntrinsicWidth, 1.0);
    final emojiHeight = max(paragraph.height, 1.0);
    final scale = min(
      1.0,
      min(cellWidth / emojiWidth, cellHeight / emojiHeight),
    );

    final dx = (cellWidth - emojiWidth * scale) / 2;
    final dy = (cellHeight - emojiHeight * scale) / 2;
    if (scale < 1.0) {
      canvas.translate(entry.srcLeft + dx, entry.srcTop + dy);
      canvas.scale(scale);
      canvas.drawParagraph(paragraph, Offset.zero);
    } else {
      canvas.drawParagraph(
        paragraph,
        Offset(entry.srcLeft + dx, entry.srcTop + dy),
      );
    }
  }
}
