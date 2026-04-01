part of 'terminal.dart';

/// A single row in the terminal grid during render state iteration.
///
/// Access via [RenderState.row] after calling [RenderState.nextRow].
/// Properties reflect the row at the current iterator position and
/// become invalid after the next [RenderState.update] call.
class Row {
  final int _handle;

  Row._(this._handle);

  /// Whether this row has been modified since the last [RenderState.markClean].
  bool get dirty => check(bindings.rowIteratorGetDirty(_handle));

  /// Sets or clears the dirty flag for this row.
  set dirty(bool v) {
    checkCode(bindings.rowIteratorSetDirty(_handle, dirty: v));
  }

  /// Whether any cell in this row contains a grapheme cluster (multi-codepoint
  /// character).
  bool get hasGrapheme => check(bindings.rowGetGrapheme(_rawRow));

  /// Whether any cell in this row has a hyperlink (OSC 8).
  bool get hasHyperlink => check(bindings.rowGetHyperlink(_rawRow));

  /// Whether any cell in this row has a Kitty virtual placeholder.
  bool get hasKittyVirtualPlaceholder {
    return check(bindings.rowGetKittyVirtualPlaceholder(_rawRow));
  }

  /// Whether any cell in this row has non-default styling.
  bool get hasStyled => check(bindings.rowGetStyled(_rawRow));

  /// The semantic prompt state of this row.
  SemanticPrompt get semanticPrompt =>
      check(bindings.rowGetSemanticPrompt(_rawRow));

  /// Whether this row is soft-wrapped to the next row.
  bool get wrap => check(bindings.rowGetWrap(_rawRow));

  /// Whether this row is a continuation of a soft-wrapped line from the
  /// previous row.
  bool get wrapContinuation => check(bindings.rowGetWrapContinuation(_rawRow));

  int get _rawRow => check(bindings.rowIteratorGetRawRow(_handle));
}
