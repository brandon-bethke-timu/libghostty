import 'dart:math';
import 'dart:ui';

import '../atlas_entry.dart';
import 'paragraph_lane.dart';

/// Rasterizes full-color emoji glyphs into the emoji atlas.
class EmojiLane extends ParagraphLane {
  EmojiLane({super.initialSize, super.maxSize}) : super(entryLane: .emoji);

  @override
  void paintPending(Canvas canvas) {
    paintPendingParagraphs(canvas, _paintEmoji);
  }

  /// Builds a full-color emoji paragraph for [text], packs it into the
  /// atlas, and returns an [AtlasEntry] with its source coordinates.
  ///
  /// Emoji are rasterized in color and composited with uniform scaling to
  /// fit within the cell bounds; tinting is not applied at draw time.
  AtlasEntry rasterizeEmoji(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    final pxCellWidth = (this.pxCellWidth * span).ceil().toDouble();
    final pxHeight = pxCellHeight.ceil().toDouble();
    final size = min(pxCellHeight, this.pxCellWidth * span) * 0.95;

    final paragraph = buildParagraph(
      text,
      bold: bold,
      italic: italic,
      size: size,
      width: pxCellWidth,
    );

    late final AtlasEntry entry;
    try {
      entry = allocate(
        width: pxCellWidth,
        height: pxHeight,
        bearingY: max(0.0, (pxCellHeight - paragraph.height) / 2),
      );
    } catch (_) {
      paragraph.dispose();
      rethrow;
    }

    addPendingParagraph(paragraph, entry);
    return entry;
  }

  /// Scales and centers an emoji paragraph within its atlas cell.
  ///
  /// The emoji is uniformly scaled by whichever axis is tighter (width
  /// or height), then centered on both axes. Centering uses the actual
  /// rendered emoji dimensions because when scaling is height-constrained
  /// the scaled width differs from the cell width.
  void _paintEmoji(Canvas canvas, Paragraph paragraph, AtlasEntry entry) {
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
