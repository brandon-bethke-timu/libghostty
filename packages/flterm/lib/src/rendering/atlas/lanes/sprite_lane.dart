import 'dart:ui';

import '../../sprite/sprite_face.dart';
import '../atlas_config.dart';
import '../atlas_entry.dart';
import 'atlas_lane.dart';

/// Rasterizes built-in geometry glyphs into the sprite atlas.
class SpriteLane extends AtlasLane {
  // Extra atlas pixels outside the sampled source rect. Edge-touching sprite
  // geometry paints into this gutter so atlas sampling cannot fetch
  // transparent pixels at cell boundaries.
  static const _sourceGutter = 1.0;

  final List<(SpriteGlyph, Rect)> _pending = [];
  final _spriteContext = SpriteContext();

  var _pxCellWidth = 0.0;
  var _pxCellHeight = 0.0;

  SpriteLane({super.initialSize, super.maxSize}) : super(entryLane: .sprite);

  @override
  bool get hasPending => _pending.isNotEmpty;

  @override
  void clearPending() {
    _pending.clear();
  }

  @override
  void configure(AtlasConfig config) {
    _pxCellWidth = config.metrics.cellWidth * config.devicePixelRatio;
    _pxCellHeight = config.metrics.cellHeight * config.devicePixelRatio;
  }

  @override
  void paintPending(Canvas canvas) {
    for (final (glyph, cell) in _pending) {
      final paintRect = cell.inflate(_sourceGutter);
      canvas.save();
      canvas.clipRect(paintRect, doAntiAlias: false);
      _paintGlyph(canvas, glyph, cell);
      _paintSourceGutter(canvas, glyph, cell);
      canvas.restore();
    }
    _pending.clear();
  }

  /// Reserves an atlas slot for [glyph] and returns its [AtlasEntry].
  ///
  /// The sprite is painted by its own geometry (no font rasterization) into
  /// the reserved rect on the next [ensureImage]. [span] controls how many
  /// cell widths the glyph occupies.
  AtlasEntry rasterizeSprite(SpriteGlyph glyph, {int span = 1}) {
    const g = _sourceGutter;
    final pxWidth = (_pxCellWidth * span).ceil().toDouble();
    final pxHeight = _pxCellHeight.ceil().toDouble();
    final slot = allocate(
      width: pxWidth + g * 2,
      height: pxHeight + g * 2,
      bearingY: 0,
    );
    final cell = Rect.fromLTRB(
      slot.srcLeft + g,
      slot.srcTop + g,
      slot.srcRight - g,
      slot.srcBottom - g,
    );
    final entry = AtlasEntry(
      srcLeft: cell.left,
      srcTop: cell.top,
      srcRight: cell.right,
      srcBottom: cell.bottom,
      bearingY: slot.bearingY,
      bearingX: slot.bearingX,
      lane: slot.lane,
    );

    _pending.add((glyph, cell));
    return entry;
  }

  void _paintGlyph(Canvas canvas, SpriteGlyph glyph, Rect cell) {
    _spriteContext.reset();
    glyph.paint(canvas, cell, _spriteContext);
  }

  void _paintSourceGutter(Canvas canvas, SpriteGlyph glyph, Rect cell) {
    const g = _sourceGutter;
    final l = cell.left;
    final t = cell.top;
    final r = cell.right;
    final b = cell.bottom;
    final w = cell.width;
    final h = cell.height;

    // Keep sprite geometry tied to the sampled cell. Painting once into an
    // inflated cell would move fractional block and mosaic boundaries.
    _copyGutter(canvas, glyph, cell, .fromLTWH(l - g, t, g, h), -g, 0);
    _copyGutter(canvas, glyph, cell, .fromLTWH(r, t, g, h), g, 0);
    _copyGutter(canvas, glyph, cell, .fromLTWH(l, t - g, w, g), 0, -g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(l, b, w, g), 0, g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(l - g, t - g, g, g), -g, -g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(r, t - g, g, g), g, -g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(l - g, b, g, g), -g, g);
    _copyGutter(canvas, glyph, cell, .fromLTWH(r, b, g, g), g, g);
  }

  void _copyGutter(
    Canvas canvas,
    SpriteGlyph glyph,
    Rect cell,
    Rect clip,
    double dx,
    double dy,
  ) {
    canvas.save();
    canvas.clipRect(clip, doAntiAlias: false);
    canvas.translate(dx, dy);
    _paintGlyph(canvas, glyph, cell);
    canvas.restore();
  }
}
