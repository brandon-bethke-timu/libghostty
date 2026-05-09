import 'package:libghostty/libghostty.dart';

import 'atlas/atlas.dart';
import 'codepoint_classification.dart';

/// Pre-fetched cell data at the cursor position.
///
/// Snapshot of the cell under the cursor, taken during state sync so the
/// cursor painter can render the character inside a block cursor without
/// accessing the terminal during paint.
final class CursorCell {
  /// Text content of the cell (grapheme cluster).
  final String content;

  /// Style attributes (bold, italic, blink, inverse, etc.).
  final Style style;

  /// Whether this is a wide (2-cell) character.
  final bool wide;

  const CursorCell(this.content, this.style, {required this.wide});
}

/// Resolves the atlas entry painted inside a focused block cursor.
final class CursorAtlasResolver {
  final Atlas _atlas;

  const CursorAtlasResolver(this._atlas);

  AtlasEntry? resolve({
    required CursorCell? cell,
    required CursorShape shape,
    required bool focused,
    required bool blinkVisible,
  }) {
    if (cell == null || !focused || shape != .block) return null;
    final style = cell.style;
    if (cell.content.isEmpty ||
        style.invisible ||
        (style.blink && !blinkVisible)) {
      return null;
    }

    final runes = cell.content.runes;
    final codepoint = runes.first;
    final span = cell.wide ? 2 : 1;
    if (_usesCodepointEntry(cell, runes.length, codepoint)) {
      return _atlas.addCodepoint(
        codepoint,
        bold: style.bold,
        italic: style.italic,
        span: span,
      );
    }

    return _textEntry(cell, codepoint, span: span);
  }

  bool _renderAsEmoji(CursorCell cell, int codepoint) {
    return cell.content.contains('\uFE0F') ||
        (cell.wide && !isCjkCodepoint(codepoint));
  }

  AtlasEntry _textEntry(CursorCell cell, int codepoint, {required int span}) {
    final style = cell.style;
    return _atlas.add(
      (text: cell.content, bold: style.bold, italic: style.italic),
      span: span,
      emoji: _renderAsEmoji(cell, codepoint),
    );
  }

  bool _usesCodepointEntry(CursorCell cell, int runeCount, int codepoint) {
    if (runeCount != 1) return false;
    return !cell.wide ||
        _atlas.hasSprite(codepoint) ||
        isCjkCodepoint(codepoint);
  }
}
