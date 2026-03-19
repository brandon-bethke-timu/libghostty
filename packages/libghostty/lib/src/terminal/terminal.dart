import 'dart:async';
import 'dart:typed_data';

import '../bindings/bindings.dart';
import '../color.dart';
import '../disposable.dart';
import 'cursor.dart';
import 'modes.dart';
import 'mouse.dart';
import 'screen.dart';
import 'scrollback.dart';
import 'terminal_event.dart';
import 'terminal_options.dart';

/// Terminal emulator state model.
///
/// ```dart
/// final terminal = Terminal(cols: 80, rows: 24);
/// terminal.write(ptyOutput);
///
/// final screen = terminal.screen;
/// for (var row = 0; row < screen.rows; row++) {
///   for (var col = 0; col < screen.cols; col++) {
///     final cell = screen.cellAt(row, col);
///   }
/// }
///
/// terminal.onEvent.listen((event) {
///   switch (event) {
///     case BellReceived():    playBeep();
///     case TitleChanged(:final title): setWindowTitle(title);
///     case CursorChanged(:final cursor): updateCursor(cursor);
///     case MouseShapeChanged(:final shape): setCursor(shape);
///     case ResponseReceived(:final response): sendToPty(response);
///     case ScreenChanged():   scheduleRepaint();
///   }
/// });
///
/// terminal.dispose();
/// ```
class Terminal extends Disposable {
  static final _resetSequence = Uint8List.fromList('\x1bc'.codeUnits);

  static final _finalizer = Finalizer<int>(
    (handle) => bindings.terminalFree(handle),
  );

  final int _handle;
  late final BindingsScreen _screen;
  late final BindingsScrollback _scrollback;

  final _onEvent = StreamController<TerminalEvent>.broadcast(sync: true);

  var _lastCursor = const Cursor();
  var _lastModes = const TerminalModes();
  var _lastMouseShape = MouseShape.text;
  var _hasContentChanges = false;

  Terminal({
    required int cols,
    required int rows,
    TerminalOptions options = const TerminalOptions(),
  }) : _handle = bindings.terminalNewWithConfig(
         cols,
         rows,
         RawTerminalConfig(
           scrollbackLimit: options.scrollbackLimit * cols * 16,
           fgR: options.foreground?.r ?? 0,
           fgG: options.foreground?.g ?? 0,
           fgB: options.foreground?.b ?? 0,
           fgSet: options.foreground != null,
           bgR: options.background?.r ?? 0,
           bgG: options.background?.g ?? 0,
           bgB: options.background?.b ?? 0,
           bgSet: options.background != null,
         ),
       ),
       super('Terminal') {
    _finalizer.attach(this, _handle, detach: this);
    bindings.terminalWrite(_handle, _resetSequence);

    final defaultFg = options.foreground ?? const RgbColor(0, 0, 0);
    final defaultBg = options.background ?? const RgbColor(0, 0, 0);
    _screen = BindingsScreen(
      _handle,
      defaultFg: defaultFg,
      defaultBg: defaultBg,
    );
    _scrollback = BindingsScrollback(
      _handle,
      cols: cols,
      defaultFg: defaultFg,
      defaultBg: defaultBg,
    );
    _syncRenderState();
    _lastCursor = _readCursor();
    _lastModes = _readModes();
  }

  Cursor get cursor {
    ensureNotDisposed();
    return _lastCursor;
  }

  /// Whether cell content has changed since the last [clearContentChanges].
  bool get hasContentChanges {
    ensureNotDisposed();
    return _hasContentChanges;
  }

  TerminalModes get modes {
    ensureNotDisposed();
    return _lastModes;
  }

  /// Mouse pointer shape requested by the application via OSC 22.
  MouseShape get mouseShape {
    ensureNotDisposed();
    return _lastMouseShape;
  }

  /// Terminal state change events, emitted synchronously during [write] and
  /// [resize].
  Stream<TerminalEvent> get onEvent => _onEvent.stream;

  Screen get screen {
    ensureNotDisposed();
    return _screen;
  }

  /// History for the primary screen (not available on alternate screen).
  Scrollback get scrollback {
    ensureNotDisposed();
    return _scrollback;
  }

  /// Resets [hasContentChanges] to false and marks the render state clean.
  void clearContentChanges() {
    ensureNotDisposed();
    _hasContentChanges = false;
    bindings.renderStateMarkClean(_handle);
  }

  @override
  void releaseResources() {
    _finalizer.detach(this);
    bindings.terminalFree(_handle);
    unawaited(_onEvent.close());
  }

  /// Resize the terminal dimensions.
  void resize({required int cols, required int rows}) {
    ensureNotDisposed();
    if (cols == _screen.cols && rows == _screen.rows) return;
    bindings.terminalResize(_handle, cols, rows);
    _syncRenderState();
    _screen.invalidate();
    _scrollback.cols = cols;
    _updateCursor();
    _onEvent.add(const ScreenChanged());
  }

  /// Feed raw bytes from the PTY through the terminal parser.
  void write(Uint8List data) {
    ensureNotDisposed();
    final flags = bindings.terminalWrite(_handle, data);
    _processFlags(flags);
  }

  void _processFlags(int flags) {
    if (flags == TerminalEventFlag.none) return;

    if (flags & TerminalEventFlag.bell != 0) {
      final bells = bindings.terminalGetBellCount(_handle);
      for (var i = 0; i < bells; i++) {
        _onEvent.add(const BellReceived());
      }
      bindings.terminalResetBellCount(_handle);
    }

    if (flags & TerminalEventFlag.titleChanged != 0) {
      final title = bindings.terminalGetTitle(_handle);
      if (title != null) _onEvent.add(TitleChanged(title));
    }

    if (flags & TerminalEventFlag.mouseShapeChanged != 0) {
      _lastMouseShape = MouseShapeNative.fromNative(
        bindings.terminalGetMouseShape(_handle),
      );
      _onEvent.add(MouseShapeChanged(_lastMouseShape));
    }

    if (flags & TerminalEventFlag.hasResponse != 0) {
      Uint8List? response;
      while ((response = bindings.terminalReadResponse(_handle)) != null) {
        _onEvent.add(ResponseReceived(response!));
      }
    }

    if (flags & TerminalEventFlag.modeChanged != 0) {
      final newModes = _readModes();
      if (newModes != _lastModes) {
        _lastModes = newModes;
        _onEvent.add(ModeChanged(newModes));
      }
    }

    if (flags & TerminalEventFlag.repaint != 0) {
      _syncRenderState();
      _screen.invalidate();
      _updateCursor();
      _onEvent.add(const ScreenChanged());
    }
  }

  Cursor _readCursor() {
    return Cursor(
      col: bindings.renderStateGetCursorX(_handle),
      row: bindings.renderStateGetCursorY(_handle),
      visible: bindings.renderStateGetCursorVisible(_handle),
      shape: CursorShapeNative.fromNative(
        bindings.renderStateGetCursorStyle(_handle),
      ),
    );
  }

  TerminalModes _readModes() {
    final mode = bindings.terminalGetModes(_handle);

    MouseTracking mouseTracking() {
      if (mode & TerminalModeBits.mouseAnyEvent != 0) return .any;
      if (mode & TerminalModeBits.mouseButtonEvent != 0) return .button;
      if (mode & TerminalModeBits.mouseNormal != 0) return .normal;
      if (mode & TerminalModeBits.mouseX10 != 0) return .x10;
      return .none;
    }

    return TerminalModes(
      screenMode: mode & TerminalModeBits.alternateScreen != 0
          ? .alternate
          : .primary,
      bracketedPaste: mode & TerminalModeBits.bracketedPaste != 0,
      cursorKeyApplication: mode & TerminalModeBits.cursorKeys != 0,
      keypadApplication: mode & TerminalModeBits.keypadApplication != 0,
      autoWrap: mode & TerminalModeBits.autoWrap != 0,
      originMode: mode & TerminalModeBits.origin != 0,
      insertMode: mode & TerminalModeBits.insert != 0,
      mouseTracking: mouseTracking(),
      mouseAlternateScroll: mode & TerminalModeBits.mouseAlternateScroll != 0,
    );
  }

  void _syncRenderState() {
    final raw = bindings.renderStateUpdate(_handle);
    final state = DirtyState.fromNative(raw);
    _screen.dirtyState = state;
    _hasContentChanges = _hasContentChanges || state != .clean;
  }

  void _updateCursor() {
    final newCursor = _readCursor();
    if (newCursor != _lastCursor) {
      _lastCursor = newCursor;
      _onEvent.add(CursorChanged(newCursor));
    }
  }
}
