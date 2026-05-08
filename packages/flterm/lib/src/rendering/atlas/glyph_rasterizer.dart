import 'dart:math';
import 'dart:ui';

import 'package:libghostty/libghostty.dart' show UnderlineStyle;

import '../../foundation.dart';
import '../sprite/sprite_face.dart';
import 'glyph_entry.dart';

/// Rasterizes glyphs into a packed atlas texture.
///
/// Builds [Paragraph] objects, packs them into a row-based bin-packed grid,
/// and composites them into an offscreen [Image]. Used internally by
/// [GlyphAtlas] on cache miss.
///
/// The atlas starts at 1024x1024 and grows up to 4096x4096 as glyphs are
/// added. All glyphs are rasterized in white; text painters apply per-sprite
/// color tinting via [BlendMode.modulate]. Emoji are rasterized in full
/// color and composited with scaling to fit within the cell bounds.
class GlyphRasterizer {
  static const _initialSize = 1024;
  static const _maxSize = 4096;

  // Gap between atlas cells prevents sub-pixel bleed between sprites.
  static const _padding = 1.0;

  final List<(Paragraph, GlyphEntry)> _pending = [];
  final List<(SpriteGlyph, GlyphEntry)> _pendingSprites = [];
  final List<(UnderlineStyle, GlyphEntry)> _pendingDecorations = [];
  final _compositePaint = Paint();
  final _spriteContext = SpriteContext();

  var _width = _initialSize;
  var _height = _initialSize;
  var _packX = 0.0;
  var _packY = 0.0;
  var _rowHeight = 0.0;
  var _dirty = false;

  var _fontFamily = '';
  var _fontWeight = FontWeight.normal;
  var _fontFamilyFallback = const <String>[];

  // Physical pixel dimensions (logical * dpr), pre-computed in configure().
  var _pxCellWidth = 0.0;
  var _pxCellHeight = 0.0;
  var _pxFontSize = 0.0;
  var _pxBaseline = 0.0;
  var _pxUnderlinePosition = 0.0;
  var _pxUnderlineThickness = 1.0;

  // Bottom padding for decoration sprites (cell height / 4). Allows
  // curly and double underlines to extend below the cell boundary.
  var _pxDecorationPadding = 0.0;

  // Extra width added to italic glyph sprites so the slanted tops of
  // ascenders (which extend past the cell advance width) are captured
  // in the atlas source rect and not clipped by drawRawAtlas.
  var _pxItalicOverhang = 0.0;

  Image? image;

  void clear() {
    _disposePending();
    _pendingSprites.clear();
    _pendingDecorations.clear();
    image?.dispose();
    image = null;
    _dirty = false;
    _packX = 0;
    _packY = 0;
    _rowHeight = 0;
    _width = _initialSize;
    _height = _initialSize;
  }

  void configure({
    required double fontSize,
    required String fontFamily,
    required FontWeight fontWeight,
    required List<String> fontFamilyFallback,
    required CellMetrics metrics,
    required double dpr,
  }) {
    _fontFamily = fontFamily;
    _fontWeight = fontWeight;
    _fontFamilyFallback = fontFamilyFallback;
    _pxCellWidth = metrics.cellWidth * dpr;
    _pxCellHeight = metrics.cellHeight * dpr;
    _pxBaseline = metrics.baseline * dpr;
    _pxFontSize = fontSize * dpr;
    _pxUnderlinePosition = metrics.underlinePosition * dpr;
    _pxUnderlineThickness = max(
      1.0,
      (metrics.underlineThickness * dpr).ceilToDouble(),
    );
    _pxDecorationPadding = (_pxCellHeight / 4).ceilToDouble();
    _pxItalicOverhang = max(1.0, (_pxFontSize * 0.15).ceilToDouble());
  }

  void dispose() {
    _disposePending();
    _pendingSprites.clear();
    _pendingDecorations.clear();
    image?.dispose();
    image = null;
  }

  /// Composites pending glyphs and decorations into the atlas image.
  void ensureImage() {
    if (!_dirty ||
        (_pending.isEmpty &&
            _pendingSprites.isEmpty &&
            _pendingDecorations.isEmpty)) {
      return;
    }
    _dirty = false;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    if (image != null) canvas.drawImage(image!, Offset.zero, _compositePaint);

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

    for (final (glyph, entry) in _pendingSprites) {
      final rect = Rect.fromLTRB(
        entry.srcLeft,
        entry.srcTop,
        entry.srcRight,
        entry.srcBottom,
      );
      canvas.save();
      canvas.clipRect(rect);
      _spriteContext.reset();
      glyph.paint(canvas, rect, _spriteContext);
      canvas.restore();
    }
    _pendingSprites.clear();

    for (final (style, entry) in _pendingDecorations) {
      canvas.save();
      canvas.clipRect(
        Rect.fromLTRB(
          entry.srcLeft,
          entry.srcTop,
          entry.srcRight,
          entry.srcBottom,
        ),
      );
      _compositeDecoration(canvas, style, entry);
      canvas.restore();
    }
    _pendingDecorations.clear();

    final picture = recorder.endRecording();
    image?.dispose();
    image = picture.toImageSync(_width, _height);
    picture.dispose();
  }

  /// Builds a paragraph for [text], packs it into the atlas, and returns
  /// a [GlyphEntry] with its source coordinates.
  ///
  /// The glyph is not composited into the atlas image until [ensureImage]
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

  /// Reserves an atlas slot for [glyph] and returns its [GlyphEntry].
  ///
  /// The sprite is painted by its own geometry (no font rasterization) into
  /// the reserved rect on the next [ensureImage]. [span] controls how many
  /// cell widths the glyph occupies.
  GlyphEntry rasterizeSprite(SpriteGlyph glyph, {int span = 1}) {
    final pxWidth = (_pxCellWidth * span).ceil().toDouble();
    final pxHeight = _pxCellHeight.ceil().toDouble();
    _pack(pxWidth, pxHeight);

    final entry = GlyphEntry(
      srcLeft: _packX,
      srcTop: _packY,
      srcRight: _packX + pxWidth,
      srcBottom: _packY + pxHeight,
      bearingY: 0,
    );

    _pendingSprites.add((glyph, entry));
    _packX += pxWidth + _padding;
    _rowHeight = max(_rowHeight, pxHeight);
    _dirty = true;
    return entry;
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

    _pack(pxWidth, pxHeight);

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
          // in ensureImage() limits the visible area to the cell span.
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

    final entry = GlyphEntry(
      srcLeft: _packX,
      srcTop: _packY,
      srcRight: _packX + pxWidth,
      srcBottom: _packY + pxHeight,
      bearingY: bearingY,
      bearingX: bearingX,
      isEmoji: emoji,
    );

    _pending.add((paragraph, entry));
    _packX += pxWidth + _padding;
    _rowHeight = max(_rowHeight, pxHeight);
    _dirty = true;
    return entry;
  }

  /// Rasterizes an underline decoration sprite for the given [style].
  ///
  /// Draws the underline pattern into the atlas in white; per-sprite color
  /// tinting is applied at draw time via [BlendMode.modulate].
  ///
  /// Sprite height = cell height + padding, allowing curly and double
  /// underlines to extend below the cell boundary.
  GlyphEntry rasterizeDecoration(UnderlineStyle style) {
    final pxWidth = _pxCellWidth.ceil().toDouble();
    // Sprite is taller than cell to accommodate decorations extending below.
    final pxHeight = (_pxCellHeight + _pxDecorationPadding).ceil().toDouble();
    _pack(pxWidth, pxHeight);

    final entry = GlyphEntry(
      srcLeft: _packX,
      srcTop: _packY,
      srcRight: _packX + pxWidth,
      srcBottom: _packY + pxHeight,
      bearingY: 0,
    );

    _pendingDecorations.add((style, entry));
    _packX += pxWidth + _padding;
    _rowHeight = max(_rowHeight, pxHeight);
    _dirty = true;
    return entry;
  }

  /// Draws an underline decoration pattern into the atlas.
  ///
  /// Each style draws at the font's underline position, clamped so it
  /// stays within the sprite bounds (cell height + padding). The padding
  /// allows curly and double underlines to extend below the cell boundary
  /// without being clipped.
  void _compositeDecoration(
    Canvas canvas,
    UnderlineStyle style,
    GlyphEntry entry,
  ) {
    final width = entry.srcRight - entry.srcLeft;
    final ox = entry.srcLeft;
    final oy = entry.srcTop;
    final thickness = _pxUnderlineThickness;
    final cellHeight = _pxCellHeight;
    final padding = _pxDecorationPadding;

    switch (style) {
      case UnderlineStyle.none:
        break;

      case UnderlineStyle.single:
        // Clamp underline to stay within the sprite (cell + padding).
        final underlineY = min(
          _pxUnderlinePosition,
          cellHeight + padding - thickness,
        );
        canvas.drawRect(
          Rect.fromLTWH(ox, oy + underlineY, width, thickness),
          Paint()..color = const Color(0xFFFFFFFF),
        );

      case UnderlineStyle.double:
        // Place both lines symmetrically around the underline position,
        // clamped so the lower line stays within the padded sprite.
        final underlineY = min(
          _pxUnderlinePosition,
          cellHeight + padding - 2 * thickness,
        );
        final upperLineY = max(0.0, underlineY - thickness);
        final lowerLineY = underlineY + thickness;
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        canvas.drawRect(
          Rect.fromLTWH(ox, oy + upperLineY, width, thickness),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(ox, oy + lowerLineY, width, thickness),
          paint,
        );

      case UnderlineStyle.dotted:
        // Dot radius derived from line thickness (sqrt(1/2) gives area-
        // equivalent circle). Dot count is bounded: at least 1 dot,
        // at most enough to fit with 2-radius spacing, and at least
        // 1-radius gaps between dots so they don't merge.
        final radius = sqrt1_2 * thickness;
        final centerY = min(
          _pxUnderlinePosition + 0.5 * thickness,
          cellHeight + padding - radius.ceilToDouble(),
        );
        final dotCount = max(
          1.0,
          min(
            (width / (4 * radius)).ceilToDouble(),
            min(
              (width / (3 * radius)).floorToDouble(),
              (width / (2 * radius + 1)).floorToDouble(),
            ),
          ),
        );
        final spacing = width / dotCount;
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        for (var i = 0; i < dotCount.toInt(); i++) {
          canvas.drawCircle(
            Offset(ox + spacing / 2 + spacing * i, oy + centerY),
            radius,
            paint,
          );
        }

      case UnderlineStyle.dashed:
        final underlineY = min(
          _pxUnderlinePosition,
          cellHeight + padding - thickness,
        );
        final intWidth = width.toInt();
        final dashWidth = intWidth ~/ 3 + 1;
        final dashCount = intWidth ~/ dashWidth + 1;
        final paint = Paint()..color = const Color(0xFFFFFFFF);
        for (var i = 0; i < dashCount; i += 2) {
          canvas.drawRect(
            Rect.fromLTWH(
              ox + (i * dashWidth).toDouble(),
              oy + underlineY,
              dashWidth.toDouble(),
              thickness,
            ),
            paint,
          );
        }

      case UnderlineStyle.curly:
        // S-shaped cubic Bezier: starts at bottom-left, curves up to center,
        // then back down to bottom-right. controlRatio (0.4) flattens the
        // curve slightly for a smooth wave that tiles seamlessly across
        // adjacent cells (butt stroke caps prevent overlap at seams).
        final amplitude = width / pi;
        final top = min(
          _pxUnderlinePosition,
          cellHeight + padding - amplitude - thickness,
        );
        final bottom = top + amplitude;
        final center = width / 2;
        const controlRatio = 0.4;

        final path = Path()
          ..moveTo(ox, oy + bottom)
          ..cubicTo(
            ox + center * controlRatio,
            oy + bottom,
            ox + center - center * controlRatio,
            oy + top,
            ox + center,
            oy + top,
          )
          ..cubicTo(
            ox + center + center * controlRatio,
            oy + top,
            ox + width - center * controlRatio,
            oy + bottom,
            ox + width,
            oy + bottom,
          );
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFFFFF)
            ..style = PaintingStyle.stroke
            ..strokeWidth = thickness
            ..strokeCap = StrokeCap.butt
            ..strokeJoin = StrokeJoin.round,
        );
    }
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

  void _disposePending() {
    for (final (paragraph, _) in _pending) {
      paragraph.dispose();
    }
    _pending.clear();
  }

  /// Doubles the smaller atlas dimension (alternating width/height)
  /// so the texture stays roughly square as it grows toward [_maxSize].
  void _grow() {
    if (_width <= _height && _width < _maxSize) {
      _width = min(_width * 2, _maxSize);
    } else if (_height < _maxSize) {
      _height = min(_height * 2, _maxSize);
    }
  }

  /// Row-based bin packing: fills left-to-right within the current row,
  /// wraps to the next row when the glyph won't fit, and grows the
  /// atlas if vertical space is exhausted.
  void _pack(double width, double height) {
    if (_packX + width + _padding > _width) {
      _packX = 0;
      _packY += _rowHeight + _padding;
      _rowHeight = 0;
    }
    if (_packY + height + _padding > _height) _grow();
  }
}
