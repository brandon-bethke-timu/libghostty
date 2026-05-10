import 'package:libghostty/libghostty.dart';

import 'atlas/atlas.dart';
import 'codepoint_classification.dart';

/// Resolves terminal cell content to the atlas entry that should paint it.
///
/// This owns the text/emoji/built-in-sprite routing rules shared by normal
/// row rendering and block cursor glyph rendering. It does not decide where
/// or how the entry is painted; row and cursor builders own the output lane.
final class CellContentResolver {
  final Atlas _atlas;

  CellContentResolver(this._atlas);

  AtlasEntry? resolveCell(
    CellIterator cell, {
    required Style style,
    required int span,
  }) {
    final content = cell.content;
    if (content.isEmpty || content == ' ') return null;

    return resolve(
      content: content,
      codepoint: cell.codepoint,
      graphemeLength: cell.graphemeLength,
      style: style,
      span: span,
    );
  }

  AtlasEntry? resolve({
    required String content,
    required int codepoint,
    required int graphemeLength,
    required Style style,
    required int span,
  }) {
    if (content.isEmpty) return null;

    if (_usesCodepointEntry(
      codepoint: codepoint,
      graphemeLength: graphemeLength,
      span: span,
    )) {
      return resolveCodepoint(codepoint, style: style, span: span);
    }

    return _atlas.add(
      (text: content, bold: style.bold, italic: style.italic),
      span: span,
      emoji: _paintsAsEmoji(content, codepoint, span: span),
    );
  }

  AtlasEntry resolveCodepoint(
    int codepoint, {
    required Style style,
    int span = 1,
  }) {
    return _atlas.addCodepoint(
      codepoint,
      bold: style.bold,
      italic: style.italic,
      span: span,
    );
  }

  bool _paintsAsEmoji(String content, int codepoint, {required int span}) {
    return content.contains('\uFE0F') ||
        (span == 2 && !isCjkCodepoint(codepoint));
  }

  bool _usesCodepointEntry({
    required int codepoint,
    required int graphemeLength,
    required int span,
  }) {
    if (graphemeLength != 1) return false;
    if (span == 1) return codepoint < 0x100000;
    return _atlas.hasSprite(codepoint) || isCjkCodepoint(codepoint);
  }
}
