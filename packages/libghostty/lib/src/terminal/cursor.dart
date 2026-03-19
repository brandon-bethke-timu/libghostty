import 'package:meta/meta.dart';

/// An immutable snapshot of the terminal cursor state.
@immutable
class Cursor {
  final int row;
  final int col;
  final bool visible;
  final CursorShape shape;

  const Cursor({
    this.row = 0,
    this.col = 0,
    this.visible = true,
    this.shape = CursorShape.block,
  });

  @override
  int get hashCode => Object.hash(row, col, visible, shape);

  @override
  bool operator ==(Object other) =>
      other is Cursor &&
      other.row == row &&
      other.col == col &&
      other.visible == visible &&
      other.shape == shape;

  Cursor copyWith({int? row, int? col, bool? visible, CursorShape? shape}) {
    return Cursor(
      row: row ?? this.row,
      col: col ?? this.col,
      visible: visible ?? this.visible,
      shape: shape ?? this.shape,
    );
  }

  @override
  String toString() =>
      'Cursor(row: $row, col: $col, visible: $visible, shape: $shape)';
}

/// Terminal cursor rendering shape.
enum CursorShape {
  block(0),
  bar(1),
  underline(2),
  blockHollow(3);

  static final _nativeMap = {
    for (final shape in values) shape._nativeValue: shape,
  };

  final int _nativeValue;

  const CursorShape(this._nativeValue);
}

extension CursorShapeNative on CursorShape {
  int get nativeValue => _nativeValue;

  static CursorShape fromNative(int value) =>
      CursorShape._nativeMap[value] ?? CursorShape.block;
}
