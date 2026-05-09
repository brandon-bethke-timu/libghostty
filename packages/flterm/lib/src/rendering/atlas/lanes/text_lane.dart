import 'dart:math';
import 'dart:ui';

import '../atlas_entry.dart';
import 'paragraph_lane.dart';

/// Rasterizes font-backed text glyphs into the text atlas.
class TextLane extends ParagraphLane {
  TextLane({super.initialSize, super.maxSize}) : super(entryLane: .text);

  @override
  void paintPending(Canvas canvas) {
    paintPendingParagraphs(canvas, (canvas, paragraph, entry) {
      canvas.drawParagraph(
        paragraph,
        Offset(entry.srcLeft + entry.bearingX, entry.srcTop + entry.bearingY),
      );
    });
  }

  /// Builds a paragraph for [text], packs it into the atlas, and returns
  /// an [AtlasEntry] with its source coordinates.
  ///
  /// The glyph is not composited into the atlas image until [ensureImage]
  /// is called. [span] controls how many cell widths the glyph occupies
  /// (2 for wide/CJK characters).
  AtlasEntry rasterizeText(
    String text, {
    required bool bold,
    required bool italic,
    int span = 1,
  }) {
    final pxCellWidth = (this.pxCellWidth * span).ceil().toDouble();
    final pxHeight = pxCellHeight.ceil().toDouble();

    // The sprite is positioned at the cell origin; the overhang width
    // overlaps into the adjacent cell's space without shifting the glyph.
    final overhang = italic ? pxItalicOverhang : 0.0;
    final pxWidth = pxCellWidth + overhang;

    final paragraph = buildParagraph(
      text,
      bold: bold,
      italic: italic,
      size: pxFontSize,
      width: double.infinity,
    );

    final bearingY = pxBaseline - paragraph.alphabeticBaseline;
    final bearingX = span > 1
        ? max(0.0, (pxCellWidth - paragraph.maxIntrinsicWidth) / 2)
        : 0.0;

    late final AtlasEntry entry;
    try {
      entry = allocate(
        width: pxWidth,
        height: pxHeight,
        bearingY: bearingY,
        bearingX: bearingX,
      );
    } catch (_) {
      paragraph.dispose();
      rethrow;
    }

    addPendingParagraph(paragraph, entry);
    return entry;
  }
}
