import 'dart:ui';

import '../../sprite/sprite_face.dart';
import '../atlas_config.dart';
import '../atlas_entry.dart';
import 'atlas_lane.dart';

/// Rasterizes built-in geometry glyphs into the sprite atlas.
class SpriteLane extends AtlasLane {
  final List<(SpriteGlyph, AtlasEntry)> _pending = [];
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
    for (final (glyph, entry) in _pending) {
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
    _pending.clear();
  }

  /// Reserves an atlas slot for [glyph] and returns its [AtlasEntry].
  ///
  /// The sprite is painted by its own geometry (no font rasterization) into
  /// the reserved rect on the next [ensureImage]. [span] controls how many
  /// cell widths the glyph occupies.
  AtlasEntry rasterizeSprite(SpriteGlyph glyph, {int span = 1}) {
    final pxWidth = (_pxCellWidth * span).ceil().toDouble();
    final pxHeight = _pxCellHeight.ceil().toDouble();
    final entry = allocate(width: pxWidth, height: pxHeight, bearingY: 0);

    _pending.add((glyph, entry));
    return entry;
  }
}
