part of 'terminal.dart';

/// An immutable snapshot of the terminal cursor state.
@immutable
class Cursor {
  /// The row position within the viewport.
  final int row;

  /// The column position within the viewport.
  final int col;

  /// Whether the cursor is visible.
  final bool visible;

  /// Whether the cursor is on the tail of a wide character.
  final bool wideTail;

  /// The visual shape of the cursor (block, underline, or bar).
  final CursorShape shape;

  /// Whether the cursor blinks.
  final bool blinking;

  /// Whether the terminal is in password input mode.
  final bool passwordInput;

  const Cursor({
    this.row = 0,
    this.col = 0,
    this.visible = true,
    this.shape = .block,
    this.wideTail = false,
    this.blinking = false,
    this.passwordInput = false,
  });

  @override
  int get hashCode =>
      Object.hash(row, col, visible, shape, blinking, passwordInput, wideTail);

  @override
  bool operator ==(Object other) =>
      other is Cursor &&
      other.row == row &&
      other.col == col &&
      other.visible == visible &&
      other.shape == shape &&
      other.blinking == blinking &&
      other.passwordInput == passwordInput &&
      other.wideTail == wideTail;

  /// Returns a copy with the given fields replaced.
  Cursor copyWith({
    int? row,
    int? col,
    bool? visible,
    CursorShape? shape,
    bool? blinking,
    bool? passwordInput,
    bool? wideTail,
  }) {
    return Cursor(
      row: row ?? this.row,
      col: col ?? this.col,
      visible: visible ?? this.visible,
      shape: shape ?? this.shape,
      blinking: blinking ?? this.blinking,
      passwordInput: passwordInput ?? this.passwordInput,
      wideTail: wideTail ?? this.wideTail,
    );
  }

  @override
  String toString() =>
      'Cursor(row: $row, col: $col, visible: $visible, shape: $shape)';
}
