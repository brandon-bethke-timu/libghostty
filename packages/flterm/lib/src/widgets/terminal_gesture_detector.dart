import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:libghostty/libghostty.dart' show MouseTracking, Screen;

import '../foundation.dart';
import 'terminal_controller.dart';
import 'terminal_raw_gesture_detector.dart';

/// Interprets gestures as terminal actions: selection, mouse tracking
/// reports, and focus requests.
///
/// Wraps [TerminalRawGestureDetector] for low-level gesture recognition
/// and adds a [Listener] for mouse tracking when active.
class TerminalGestureDetector extends StatefulWidget {
  final Widget child;
  final int visibleRows;
  final CellMetrics metrics;
  final MouseTracking mouseMode;
  final TerminalController controller;
  final TerminalGestureSettings settings;
  final VoidCallback? onFocusRequest;
  final ScrollController? scrollController;
  final ValueGetter<Screen>? getScreen;
  final ValueChanged<Uint8List>? onOutput;
  final ValueChanged<String>? onLinkTap;
  final String? Function(int row, int col)? getHyperlinkAt;
  final ValueChanged<TerminalSelection?>? onSelectionChanged;

  const TerminalGestureDetector({
    super.key,
    required this.child,
    required this.metrics,
    required this.controller,
    this.mouseMode = .none,
    this.settings = const TerminalGestureSettings(),
    this.getScreen,
    this.onSelectionChanged,
    this.onFocusRequest,
    this.onOutput,
    this.onLinkTap,
    this.getHyperlinkAt,
    this.scrollController,
    this.visibleRows = 0,
  });

  @override
  State<TerminalGestureDetector> createState() =>
      _TerminalGestureDetectorState();
}

class _DragState {
  int anchorRow;
  final int anchorCol;
  final TerminalSelectionMode baseMode;
  int? lastRow;
  int? lastCol;
  TerminalSelectionMode? lastEmittedMode;

  _DragState(this.anchorRow, this.anchorCol, this.baseMode);
}

class _TerminalGestureDetectorState extends State<TerminalGestureDetector> {
  _DragState? _drag;
  Timer? _autoScrollTimer;
  var _autoScrollDelta = 0;

  @override
  Widget build(BuildContext context) {
    final tracked = widget.mouseMode != MouseTracking.none;

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: tracked ? _handleTrackedDown : null,
      onPointerMove: tracked ? _handleTrackedMove : null,
      onPointerUp: tracked ? _handleTrackedUp : null,
      onPointerSignal: tracked ? _handleTrackedSignal : null,
      child: TerminalRawGestureDetector(
        onSingleTapDown: _handleSingleTapDown,
        onDoubleTapDown: _handleDoubleTapDown,
        onTripleTapDown: _handleTripleTapDown,
        onDragStart: _handleDragStart,
        onDragUpdate: _handleDragUpdate,
        onDragEnd: _handleDragEnd,
        onLongPressStart: _handleLongPressStart,
        onLongPressMoveUpdate: _handleLongPressMoveUpdate,
        onLongPressUp: _handleLongPressUp,
        child: widget.child,
      ),
    );
  }

  @override
  void didUpdateWidget(TerminalGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.metrics != oldWidget.metrics ||
        widget.controller != oldWidget.controller) {
      _clearSelection();
      if (_drag != null) _endDrag();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _autoScrollTick(Timer timer) {
    final sc = widget.scrollController;
    if (sc == null || !sc.hasClients) return;

    final drag = _drag;
    if (drag == null) {
      _stopAutoScroll();
      return;
    }

    final position = sc.position;
    final pixelDelta = _autoScrollDelta > 0
        ? widget.metrics.cellHeight
        : -widget.metrics.cellHeight;
    final target = (position.pixels + pixelDelta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if (target == position.pixels) return;
    sc.jumpTo(target);

    drag.anchorRow += _autoScrollDelta < 0 ? 1 : -1;

    if (drag.lastRow != null && drag.lastCol != null) {
      _emitSelection(
        drag.anchorRow,
        drag.anchorCol,
        drag.lastRow!,
        drag.lastCol!,
        _isBlockModifierPressed() ? .block : drag.baseMode,
      );
    }
  }

  void _clearSelection() {
    if (widget.controller.selection == null) return;
    widget.onSelectionChanged?.call(null);
  }

  void _emitSelection(
    int startRow,
    int startCol,
    int endRow,
    int endCol,
    TerminalSelectionMode mode,
  ) {
    final screen = widget.getScreen?.call();
    final (sc, ec) = screen != null
        ? screen.snapSelectionCols(startRow, startCol, endRow, endCol)
        : (startCol, endCol);
    widget.onSelectionChanged?.call(
      TerminalSelection(
        startRow: startRow,
        startCol: sc,
        endRow: endRow,
        endCol: ec,
        mode: mode,
      ),
    );
  }

  void _endDrag() {
    _stopAutoScroll();
    _drag = null;
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    widget.onFocusRequest?.call();
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;

    if (_isEnabled(.word)) {
      final screen = widget.getScreen?.call();
      if (screen != null) {
        _selectWord(details.localPosition, screen);
        return;
      }
    }
    _clearSelection();
  }

  void _handleDragEnd() => _endDrag();

  void _handleDragStart(DragStartDetails details) {
    widget.onFocusRequest?.call();
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    if (!_isEnabled(.drag)) return;

    _clearSelection();
    _startDrag(details.localPosition);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;
    if (_drag != null) _updateDrag(details.localPosition);
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_drag != null) _updateDrag(details.localPosition);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    widget.onFocusRequest?.call();
    if (!_isEnabled(.longPress)) return;
    _clearSelection();
    _startDrag(
      details.localPosition,
      mode: widget.settings.longPressSelectionMode,
    );
  }

  void _handleLongPressUp() => _endDrag();

  void _handleSingleTapDown(TapDownDetails details) {
    widget.onFocusRequest?.call();
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;

    if (widget.onLinkTap != null && HardwareKeyboard.instance.isMetaPressed) {
      final (row, col) = widget.metrics.cellAt(details.localPosition);
      final link = widget.getHyperlinkAt?.call(row, col);
      if (link != null) {
        widget.onLinkTap!(link);
        return;
      }
    }

    _clearSelection();
  }

  void _handleTrackedDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.touch) return;
    final shift =
        event.buttons & kSecondaryButton != 0 ||
        HardwareKeyboard.instance.isShiftPressed;
    if (!_isMouseTracked(shift)) return;
    _sendMouseEvent(.press, event.localPosition);
  }

  void _handleTrackedMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.touch) return;
    if (!_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) {
      return;
    }
    _sendMouseEvent(.motion, event.localPosition);
  }

  void _handleTrackedSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) {
      return;
    }

    final (row, col) = widget.metrics.cellAt(event.localPosition);
    final button = event.scrollDelta.dy < 0
        ? MouseButton.scrollUp
        : MouseButton.scrollDown;
    final bytes = encodeMouseEvent(.press, widget.mouseMode, button, col, row);
    if (bytes != null) widget.onOutput?.call(bytes);
  }

  void _handleTrackedUp(PointerUpEvent event) {
    if (event.kind == PointerDeviceKind.touch) return;
    if (!_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) {
      return;
    }
    _sendMouseEvent(.release, event.localPosition);
  }

  void _handleTripleTapDown(TapDownDetails details) {
    widget.onFocusRequest?.call();
    if (_isMouseTracked(HardwareKeyboard.instance.isShiftPressed)) return;

    if (_isEnabled(.line)) {
      final screen = widget.getScreen?.call();
      if (screen != null) {
        _selectLine(details.localPosition, screen);
        return;
      }
    }
    _clearSelection();
  }

  bool _isBlockModifierPressed() {
    final modifier = widget.settings.blockSelectionModifier;
    if (modifier == null) return false;
    final keyboard = HardwareKeyboard.instance;
    final mods = widget.controller.virtualMods;
    return switch (modifier) {
      .alt => keyboard.isAltPressed || mods.hasAlt,
      .meta => keyboard.isMetaPressed || mods.hasSuper,
      .shift => keyboard.isShiftPressed || mods.hasShift,
      .control => keyboard.isControlPressed || mods.hasCtrl,
    };
  }

  bool _isEnabled(SelectionGesture gesture) {
    return widget.settings.enabledSelections.contains(gesture);
  }

  bool _isMouseTracked(bool shift) {
    return widget.mouseMode != .none &&
        !shift &&
        !widget.controller.virtualMods.hasShift;
  }

  void _selectLine(Offset position, Screen screen) {
    final (row, _) = widget.metrics.cellAt(position);
    final (:startRow, :endRow, :endCol) = screen.lineBoundaryAt(row);
    final effectiveEndCol = switch (widget.settings.lineSelectMode) {
      .content => endCol,
      .full => screen.cols,
    };

    widget.onSelectionChanged?.call(
      TerminalSelection(
        startRow: startRow,
        startCol: 0,
        endRow: endRow,
        endCol: effectiveEndCol,
      ),
    );
  }

  void _selectWord(Offset position, Screen screen) {
    final (row, rawCol) = widget.metrics.cellAt(position);
    final col = screen.snapColToWideBoundary(row, rawCol, inclusive: true);
    final (startCol, endCol) = screen.wordBoundaryAt(row, col);
    widget.onSelectionChanged?.call(
      TerminalSelection(
        startRow: row,
        startCol: startCol,
        endRow: row,
        endCol: endCol,
      ),
    );
  }

  void _sendMouseEvent(MouseEventType type, Offset position) {
    final (row, col) = widget.metrics.cellAt(position);
    final keyboard = HardwareKeyboard.instance;
    final mods = widget.controller.virtualMods;
    final bytes = encodeMouseEvent(
      type,
      widget.mouseMode,
      MouseButton.left,
      col,
      row,
      alt: keyboard.isAltPressed || mods.hasAlt,
      ctrl: keyboard.isControlPressed || mods.hasCtrl,
      shift: keyboard.isShiftPressed || mods.hasShift,
    );
    if (bytes != null) widget.onOutput?.call(bytes);
  }

  void _startAutoScroll(int delta) {
    _autoScrollDelta = delta;
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      _autoScrollTick,
    );
  }

  void _startDrag(Offset position, {TerminalSelectionMode mode = .normal}) {
    final (row, col) = widget.metrics.cellAt(position);
    _drag = _DragState(row, col, mode);
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollDelta = 0;
  }

  void _updateDrag(Offset position) {
    final drag = _drag;
    if (drag == null) return;
    final (row, col) = widget.metrics.cellAt(position);

    final visibleRows = widget.visibleRows;
    if (visibleRows > 0) {
      if (row < 0) {
        _startAutoScroll(row);
      } else if (row >= visibleRows) {
        _startAutoScroll(row - visibleRows + 1);
      } else {
        _stopAutoScroll();
      }
    }

    final clampedRow = visibleRows > 0 ? row.clamp(0, visibleRows - 1) : row;
    final mode = _isBlockModifierPressed()
        ? TerminalSelectionMode.block
        : drag.baseMode;
    if (clampedRow == drag.lastRow &&
        col == drag.lastCol &&
        mode == drag.lastEmittedMode) {
      return;
    }
    drag.lastRow = clampedRow;
    drag.lastCol = col;
    drag.lastEmittedMode = mode;

    _emitSelection(drag.anchorRow, drag.anchorCol, clampedRow, col, mode);
  }
}
