import 'dart:ui';

import 'package:flutter/painting.dart';

import '../kitty_image_cache.dart';
import '../paint_state.dart';
import 'terminal_painter.dart';

/// Paints Kitty graphics placements for a single [KittyPaintLayer].
///
/// One painter per layer is invoked at the corresponding stage of the
/// renderer's paint pipeline. Each paint clips to the grid so off-grid
/// placements never bleed past the terminal bounds.
///
/// [snapshots] is shared across the three layer painters and is
/// expected to be sorted by z ascending; each painter filters by
/// [layer] in a single pass.
class KittyGraphicsPainter implements TerminalPainter {
  final Paint _paint;
  final KittyPaintLayer _layer;
  final KittyImageCache _cache;
  final TerminalPaintState _state;
  final List<KittyPlacementSnapshot> _snapshots;

  KittyGraphicsPainter({
    required KittyPaintLayer layer,
    required KittyImageCache cache,
    required TerminalPaintState state,
    required List<KittyPlacementSnapshot> snapshots,
  }) : _layer = layer,
       _cache = cache,
       _state = state,
       _snapshots = snapshots,
       _paint = Paint()..filterQuality = .low;

  @override
  void paint(Canvas canvas) {
    if (_snapshots.isEmpty) return;
    final width = _state.cols * _state.metrics.cellWidth;
    final height = _state.rows * _state.metrics.cellHeight;
    if (width <= 0 || height <= 0) return;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, width, height));
    for (final snap in _snapshots) {
      if (KittyPaintLayer.forZ(snap.z) != _layer) continue;

      final cached = _cache.lookupById(snap.imageId);
      if (cached is! KittyImageReady) continue;

      canvas.drawImageRect(cached.image, snap.src, snap.dst, _paint);
    }
    canvas.restore();
  }
}

/// Paint-order bucket a Kitty placement falls into based on its z-index.
///
/// Mirrors the Kitty graphics protocol's three-bucket convention.
enum KittyPaintLayer {
  /// Painted beneath cell backgrounds.
  belowBg,

  /// Painted between cell backgrounds and text.
  belowText,

  /// Painted above text, beneath the selection overlay.
  aboveText;

  // The protocol splits negative z values in half at INT32_MIN / 2:
  // anything further negative than that paints below the cell
  // background, the rest paints above the background but below text.
  static const int _bgThreshold = -1 << 30;

  /// Returns the layer for a placement with the given [z].
  static KittyPaintLayer forZ(int z) {
    if (z >= 0) return aboveText;
    if (z < _bgThreshold) return belowBg;
    return belowText;
  }
}

/// Placement data consumed by [KittyGraphicsPainter], decoupled from
/// the live terminal so paint never reaches back into libghostty.
class KittyPlacementSnapshot {
  final int imageId;

  /// Destination rectangle in the same logical-pixel space as cells.
  final Rect dst;

  /// Source rectangle in the image's own pixel space.
  final Rect src;

  /// Signed z-index. See [KittyPaintLayer] for the layer mapping.
  final int z;

  const KittyPlacementSnapshot({
    required this.imageId,
    required this.dst,
    required this.src,
    required this.z,
  });
}
