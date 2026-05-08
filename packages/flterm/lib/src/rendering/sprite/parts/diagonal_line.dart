part of '../sprite_face.dart';

final class DiagonalLine extends SpriteGlyph {
  final bool topLeftToBottomRight;

  const DiagonalLine({required this.topLeftToBottomRight});

  @override
  void paint(Canvas canvas, Rect cell, SpriteContext ctx) {
    // Extend the line a half-step past each cell edge along the shorter
    // axis so adjacent diagonals meet cleanly without gaps.
    final slopeX = math.min(1.0, cell.width / cell.height);
    final slopeY = math.min(1.0, cell.height / cell.width);

    ctx.stroke
      ..strokeWidth = ctx.thickness(cell)
      ..strokeCap = .butt;

    if (topLeftToBottomRight) {
      canvas.drawLine(
        Offset(cell.left - 0.5 * slopeX, cell.top - 0.5 * slopeY),
        Offset(cell.right + 0.5 * slopeX, cell.bottom + 0.5 * slopeY),
        ctx.stroke,
      );
    } else {
      canvas.drawLine(
        Offset(cell.right + 0.5 * slopeX, cell.top - 0.5 * slopeY),
        Offset(cell.left - 0.5 * slopeX, cell.bottom + 0.5 * slopeY),
        ctx.stroke,
      );
    }
  }
}
