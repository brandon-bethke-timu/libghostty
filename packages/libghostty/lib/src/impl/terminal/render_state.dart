part of 'terminal.dart';

/// Dirty state of a render state after [RenderState.update].
enum DirtyState {
  /// Not dirty: rendering can be skipped entirely.
  clean,

  /// Some rows changed: renderer can redraw incrementally using per-row
  /// dirty flags via [Row.dirty].
  partial,

  /// Global state changed (e.g. colors, cursor shape, screen switch):
  /// renderer should redraw everything.
  full;

  factory DirtyState._fromRaw(RenderStateDirty value) => switch (value) {
    RenderStateDirty.false$ => DirtyState.clean,
    RenderStateDirty.partial => DirtyState.partial,
    RenderStateDirty.full => DirtyState.full,
  };
}

/// Stateful render snapshot of a terminal's visible viewport, optimized for
/// repeated updates and incremental redrawing of dirty regions.
///
/// The key design principle is that the render state only needs access to the
/// [Terminal] during the [update] call. Between updates, all data can be read
/// without holding any lock on the terminal, enabling safe multi-threaded
/// rendering.
///
/// ## Dirty Tracking
///
/// Dirty state is tracked at two independent layers: a global [dirty] state
/// and per-row flags via [Row.dirty]. The [update] call sets these but does
/// not clear them. The caller must manage both layers by calling
/// [markClean] after rendering. Setting one layer does not affect the other.
///
/// ```dart
/// final dirty = renderState.update();
/// if (dirty != DirtyState.clean) {
///   while (renderState.nextRow()) {
///     if (dirty == DirtyState.full || renderState.row.dirty) {
///       while (renderState.nextCell()) {
///         drawCell(renderState.cell);
///       }
///     }
///   }
///   renderState.markClean();
/// }
/// ```
class RenderState {
  static final _finalizer = Finalizer<_Handles>((handle) {
    bindings.rowCellsFree(handle.rowCells);
    bindings.rowIteratorFree(handle.rowIterator);
    bindings.renderStateFree(handle.handle);
  });

  final int _handle;
  final int _rowIterator;
  final int _rowCells;
  final int _terminalHandle;
  var _disposed = false;

  var _dirty = DirtyState.clean;
  var _cols = 0;
  var _rows = 0;
  var _rowStarted = false;
  var _cellStarted = false;

  /// The current [Row] in the iteration. Properties reflect the row at the
  /// current iterator position. Only valid after calling [nextRow] and
  /// before the next [update].
  late final row = Row._(_rowIterator);

  /// The current [Cell] in the iteration. Properties reflect the cell at
  /// the current iterator position. Only valid after calling [nextCell]
  /// and before the next [update].
  late final cell = Cell._(_rowCells);

  RenderState._(this._terminalHandle)
    : _handle = _createHandle(bindings.renderStateNew),
      _rowIterator = _createHandle(bindings.rowIteratorNew),
      _rowCells = _createHandle(bindings.rowCellsNew) {
    _finalizer.attach(
      this,
      _Handles(_handle, _rowIterator, _rowCells),
      detach: this,
    );
  }

  /// Resolved color information from the last [update]: foreground,
  /// background, cursor color, and the full 256-color palette.
  TerminalColors get colors => check(bindings.renderStateGetColors(_handle));

  /// Viewport width in cells from the last [update].
  int get cols => _cols;

  /// Cursor state from the last [update]: position, visibility, blink,
  /// shape, and password input flag. If the cursor is outside the
  /// viewport, position fields default to zero and [Cursor.wideTail]
  /// defaults to false.
  Cursor get cursor {
    final inViewport = check(bindings.renderStateGetCursorInViewport(_handle));
    final visible = check(bindings.renderStateGetCursorVisible(_handle));
    final blinking = check(bindings.renderStateGetCursorBlinking(_handle));
    final passwordInput = check(
      bindings.renderStateGetCursorPasswordInput(_handle),
    );
    final visualStyle = check(
      bindings.renderStateGetCursorVisualStyle(_handle),
    );
    if (!inViewport) {
      return Cursor(
        visible: visible,
        blinking: blinking,
        passwordInput: passwordInput,
        shape: visualStyle,
      );
    }
    final col = check(bindings.renderStateGetCursorViewportX(_handle));
    final row = check(bindings.renderStateGetCursorViewportY(_handle));
    final wideTail = check(
      bindings.renderStateGetCursorViewportWideTail(_handle),
    );
    return Cursor(
      col: col,
      row: row,
      visible: visible,
      blinking: blinking,
      wideTail: wideTail,
      passwordInput: passwordInput,
      shape: visualStyle,
    );
  }

  /// Global dirty state from the last [update].
  DirtyState get dirty => _dirty;

  /// Viewport height in cells from the last [update].
  int get rows => _rows;

  /// Releases all resources held by this render state.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    bindings.rowCellsFree(_rowCells);
    bindings.rowIteratorFree(_rowIterator);
    bindings.renderStateFree(_handle);
  }

  /// Resets both global and per-row dirty flags to clean.
  ///
  /// Call this after rendering a frame. Iterates all rows to clear their
  /// individual dirty flags, then sets the global dirty state to
  /// [DirtyState.clean].
  void markClean() {
    if (_dirty == DirtyState.clean) return;
    checkCode(bindings.rowIteratorInit(_rowIterator, _handle));
    while (bindings.rowIteratorNext(_rowIterator)) {
      checkCode(bindings.rowIteratorSetDirty(_rowIterator, dirty: false));
    }
    checkCode(bindings.renderStateSetDirty(_handle, RenderStateDirty.false$));
    _dirty = DirtyState.clean;
    _rowStarted = false;
  }

  /// Advances to the next cell in the current row.
  ///
  /// Returns true if the iterator moved to a valid cell; false if no more
  /// cells remain. Read cell data from [cell] after this returns true.
  bool nextCell() {
    if (!_cellStarted) {
      _cellStarted = true;
      checkCode(bindings.rowCellsInit(_rowCells, _rowIterator));
    }
    return cell._advance();
  }

  /// Advances to the next row in the viewport.
  ///
  /// Returns true if the iterator moved to a valid row; false if no more
  /// rows remain. Read row data from [row] after this returns true, then
  /// iterate cells with [nextCell].
  bool nextRow() {
    if (!_rowStarted) {
      _rowStarted = true;
      checkCode(bindings.rowIteratorInit(_rowIterator, _handle));
    }
    final hasNext = bindings.rowIteratorNext(_rowIterator);
    if (hasNext) _cellStarted = false;
    return hasNext;
  }

  /// Resets the row and cell iteration state so that [nextRow] starts from
  /// the beginning again.
  ///
  /// Does not touch dirty flags or re-snapshot the terminal. Use this to
  /// iterate the same snapshot multiple times (e.g. once for layout, once
  /// for drawing).
  void resetIteration() {
    _rowStarted = false;
    _cellStarted = false;
  }

  /// Positions the cell iterator at the given zero-based [col] in the
  /// current row, so that [cell] properties reflect that column.
  ///
  /// Can be used instead of or mixed with [nextCell] for random access
  /// within a row. Calling [nextCell] after [selectCell] advances from
  /// the selected position. Only valid after [nextRow] returns true.
  ///
  /// Throws [InvalidValueException] if [col] is out of range.
  void selectCell(int col) {
    if (!_cellStarted) {
      _cellStarted = true;
      checkCode(bindings.rowCellsInit(_rowCells, _rowIterator));
    }
    checkCode(bindings.rowCellsSelect(_rowCells, col));
    cell._refresh();
  }

  /// Snapshots the terminal state and consumes the terminal's dirty flag.
  ///
  /// After this call, all render state properties ([cols], [rows],
  /// [colors], [cursor]) reflect the terminal's current state, and
  /// [dirty] indicates what changed. Does not clear this render state's
  /// own dirty tracking; call [markClean] after rendering.
  ///
  /// Throws [OutOfMemoryException] if updating requires allocation and
  /// that allocation fails.
  DirtyState update() {
    checkCode(bindings.renderStateUpdate(_handle, _terminalHandle));
    _dirty = DirtyState._fromRaw(check(bindings.renderStateGetDirty(_handle)));
    _cols = check(bindings.renderStateGetCols(_handle));
    _rows = check(bindings.renderStateGetRows(_handle));
    _rowStarted = false;
    return _dirty;
  }

  static int _createHandle(CResult<int> Function() factory) => check(factory());
}

class _Handles {
  final int handle;
  final int rowIterator;
  final int rowCells;

  _Handles(this.handle, this.rowIterator, this.rowCells);
}
