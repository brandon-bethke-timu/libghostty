import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../bindings/bindings.dart';
import '../../ffi/libghostty_enums.g.dart';
import '../../listenable.dart';
import '../key/key_encoder.dart';
import '../key/kitty_key_flags.dart';
import '../mouse/mouse_encoder.dart';
import 'terminal_mode.dart';

part 'cell.dart';
part 'cursor.dart';
part 'formatter.dart';
part 'grid_ref.dart';
part 'kitty_graphics.dart';
part 'render_state.dart';
part 'row.dart';
part 'selection.dart';

@internal
int terminalHandle(Terminal terminal) => terminal._handle;

/// Complete terminal emulator managing screen state, scrollback, cursor,
/// styles, modes, and VT stream processing.
///
/// By default, VT sequence processing via [write] only handles sequences that
/// directly affect terminal state. Sequences with side effects (bell, title
/// changes, device queries) are silently ignored unless the corresponding
/// callback is registered. See the "Effects" section below.
///
/// ## Effects
///
/// Effects are callbacks invoked synchronously during [write] in response to
/// VT sequences. Register them by assigning the callback setters ([onWritePty],
/// [onBell], [onTitleChanged], etc.). Set to null to disable.
///
/// All callbacks fire synchronously during [write]. Callers **must not** call
/// [write] from within a callback (no reentrancy), and callbacks should avoid
/// blocking or expensive operations since they block further I/O processing.
///
/// ## Color Theme
///
/// The terminal maintains two color layers for foreground, background, cursor,
/// and the 256-color palette: **defaults** set by the embedder and
/// **overrides** set by programs running in the terminal via OSC sequences (OSC
/// 10/11/12 for foreground/background/cursor, OSC 4 for palette entries).
///
/// The effective color getters ([foreground], [background], [cursorColor],
/// [palette]) return the OSC override if one is active, otherwise the default.
/// The default-only getters ([foregroundDefault], [backgroundDefault],
/// [cursorColorDefault], [paletteDefault]) ignore OSC overrides.
///
/// ```dart
/// final terminal = Terminal(cols: 80, rows: 24);
///
/// terminal.onWritePty = (data) => pty.write(data);
/// terminal.onBell = () => playSound();
///
/// terminal.write(vtData);
/// terminal.resize(cols: 120, rows: 40, cellWidthPx: 8, cellHeightPx: 16);
///
/// terminal.dispose();
/// ```
class Terminal with Listenable {
  static final _finalizer = Finalizer<int>((handle) {
    bindings.terminalDisposeCallbacks(handle);
    bindings.terminalFree(handle);
  });

  final int _handle;

  /// Encodes keyboard input into terminal escape sequences.
  late final KeyEncoder keyEncoder;

  /// Rendering API with dirty tracking for efficient screen updates.
  late final RenderState renderState;

  /// Encodes mouse events into terminal escape sequences.
  late final MouseEncoder mouseEncoder;
  var _disposed = false;

  /// Creates a terminal with the given grid dimensions and scrollback limit.
  ///
  /// Both [cols] and [rows] must be greater than zero. [maxScrollback] controls
  /// how many lines of history are preserved above the active grid.
  ///
  /// Throws [OutOfMemoryException] if the native allocation fails.
  ///
  /// ```dart
  /// final terminal = Terminal(cols: 80, rows: 24, maxScrollback: 5000);
  /// ```
  Terminal({required int cols, required int rows, int maxScrollback = 10_000})
    : _handle = _create(cols, rows, maxScrollback) {
    _finalizer.attach(this, _handle, detach: this);
    renderState = RenderState._(_handle);
    keyEncoder = KeyEncoder()..syncFrom(this);
    mouseEncoder = MouseEncoder()..syncFrom(this);
  }

  /// The active screen buffer (primary or alternate).
  ///
  /// Programs switch screens via DEC private mode 1049 (e.g. when entering
  /// full-screen editors like vim).
  TerminalScreen get activeScreen {
    return check(bindings.terminalGetActiveScreen(_handle));
  }

  /// Effective background color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured (neither a default nor an OSC
  /// override).
  RgbColor? get background {
    return _optionalColor(bindings.terminalGetColorBackground(_handle));
  }

  /// Sets the default background color, or clears it if null.
  ///
  /// This sets the embedder default. Programs running in the terminal can
  /// still override it via OSC 11.
  set background(RgbColor? color) {
    checkCode(bindings.terminalSetColorBackground(_handle, color));
  }

  /// Default background color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get backgroundDefault {
    return _optionalColor(bindings.terminalGetColorBackgroundDefault(_handle));
  }

  /// Effective cursor color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured.
  RgbColor? get cursorColor {
    return _optionalColor(bindings.terminalGetColorCursor(_handle));
  }

  /// Sets the default cursor color, or clears it if null.
  ///
  /// Programs running in the terminal can override this via OSC 12.
  set cursorColor(RgbColor? color) {
    checkCode(bindings.terminalSetColorCursor(_handle, color));
  }

  /// Default cursor color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get cursorColorDefault {
    return _optionalColor(bindings.terminalGetColorCursorDefault(_handle));
  }

  /// The cursor's current SGR style (applied to newly printed characters).
  Style get cursorStyle => check(bindings.terminalGetCursorStyle(_handle));

  /// Effective foreground color (OSC override if active, otherwise default).
  ///
  /// Returns null if no color is configured (neither a default nor an OSC
  /// override).
  RgbColor? get foreground {
    return _optionalColor(bindings.terminalGetColorForeground(_handle));
  }

  /// Sets the default foreground color, or clears it if null.
  ///
  /// Programs running in the terminal can override this via OSC 10.
  set foreground(RgbColor? color) {
    checkCode(bindings.terminalSetColorForeground(_handle, color));
  }

  /// Default foreground color, ignoring any OSC override.
  ///
  /// Returns null if no default has been configured.
  RgbColor? get foregroundDefault {
    return _optionalColor(bindings.terminalGetColorForegroundDefault(_handle));
  }

  /// Total terminal height in pixels (rows * cell height).
  int get heightPx => check(bindings.terminalGetHeightPx(_handle));

  /// Whether any mouse tracking mode is currently active.
  bool get isMouseTracking => check(bindings.terminalGetMouseTracking(_handle));

  /// Image storage for the Kitty graphics protocol on the active
  /// screen, or null when Kitty graphics are disabled in the native
  /// library build.
  ///
  /// The returned [KittyGraphics] handle is borrowed from the terminal
  /// and is invalidated by any mutating terminal call ([write],
  /// [reset], [resize]); re-read this getter after such operations
  /// rather than retaining the previous value.
  ///
  /// Image storage must be enabled before any images are kept: set a
  /// non-zero [kittyImageStorageLimit]. PNG payloads additionally
  /// require a decoder installed via [LibGhostty.setPngDecoder].
  KittyGraphics? get kittyGraphics {
    final handle = bindings.kittyGraphicsGet(_handle);
    return handle == 0 ? null : KittyGraphics._(handle, _handle);
  }

  /// Whether the file medium is enabled for Kitty image loading.
  /// Returns null when Kitty graphics are not compiled in.
  bool? get isKittyFileMedium {
    final (code, value) = bindings.terminalGetKittyImageMediumFile(_handle);
    return code == .noValue ? null : check((code, value));
  }

  /// Enables or disables the file medium for Kitty image loading.
  void setKittyFileMedium({required bool enabled}) {
    checkCode(
      bindings.terminalSetKittyImageMediumFile(_handle, enabled: enabled),
    );
  }

  /// Whether the shared memory medium is enabled for Kitty image loading.
  /// Returns null when Kitty graphics are not compiled in.
  bool? get isKittySharedMemMedium {
    final (code, value) = bindings.terminalGetKittyImageMediumSharedMem(
      _handle,
    );
    return code == .noValue ? null : check((code, value));
  }

  /// Enables or disables the shared memory medium for Kitty image loading.
  void setKittySharedMemMedium({required bool enabled}) {
    checkCode(
      bindings.terminalSetKittyImageMediumSharedMem(_handle, enabled: enabled),
    );
  }

  /// Whether the temporary file medium is enabled for Kitty image loading.
  /// Returns null when Kitty graphics are not compiled in.
  bool? get isKittyTempFileMedium {
    final (code, value) = bindings.terminalGetKittyImageMediumTempFile(_handle);
    return code == .noValue ? null : check((code, value));
  }

  /// Enables or disables the temporary file medium for Kitty image loading.
  void setKittyTempFileMedium({required bool enabled}) {
    checkCode(
      bindings.terminalSetKittyImageMediumTempFile(_handle, enabled: enabled),
    );
  }

  /// Kitty image storage limit in bytes for the active screen.
  ///
  /// Zero means the Kitty graphics protocol is disabled. Returns null when
  /// Kitty graphics support is not compiled into the library.
  int? get kittyImageStorageLimit {
    final (code, value) = bindings.terminalGetKittyImageStorageLimit(_handle);
    return code == .noValue ? null : check((code, value));
  }

  /// Sets the Kitty image storage limit in bytes. Zero or null disables
  /// the Kitty graphics protocol entirely.
  set kittyImageStorageLimit(int? value) {
    checkCode(bindings.terminalSetKittyImageStorageLimit(_handle, value));
  }

  /// Current Kitty keyboard protocol flags.
  ///
  /// Reflects the flags set by the program running in the terminal via the
  /// Kitty keyboard protocol. Use [KeyEncoder] to encode key events according
  /// to these flags.
  KittyKeyFlags get kittyKeyboardFlags => KittyKeyFlags.fromValue(
    check(bindings.terminalGetKittyKeyboardFlags(_handle)),
  );

  /// Active mouse tracking mode derived from the current terminal modes.
  ///
  /// Returns [MouseTracking.none] if no mouse tracking mode is enabled.
  /// Programs enable mouse tracking via DEC private modes (9, 1000, 1002,
  /// 1003).
  MouseTracking get mouseTracking {
    if (modeGet(const .anyMouse())) return .any;
    if (modeGet(const .buttonMouse())) return .button;
    if (modeGet(const .normalMouse())) return .normal;
    if (modeGet(const .x10Mouse())) return .x10;
    return MouseTracking.none;
  }

  /// Registers a callback for BEL character (0x07).
  ///
  /// Fires synchronously during [write]. Set to null to ignore bell events.
  set onBell(VoidCallback? value) => bindings.terminalSetOnBell(_handle, value);

  /// Registers a callback for color scheme queries (CSI ? 996 n).
  ///
  /// Return the current [ColorScheme], or null to silently ignore the query.
  /// Fires synchronously during [write].
  set onColorScheme(ValueGetter<ColorScheme?>? value) {
    bindings.terminalSetOnColorScheme(_handle, value);
  }

  /// Registers a callback for device attributes queries (CSI c / > c / = c).
  ///
  /// Return a [DeviceAttributesResponse], or null to silently ignore the query.
  /// Fires synchronously during [write].
  set onDeviceAttributes(ValueGetter<DeviceAttributesResponse?>? value) {
    bindings.terminalSetOnDeviceAttributes(_handle, value);
  }

  /// Registers a callback for ENQ character (0x05).
  ///
  /// Return the response bytes to write back to the PTY. Return an empty list
  /// to send no response. Fires synchronously during [write].
  set onEnquiry(ValueGetter<Uint8List>? value) {
    bindings.terminalSetOnEnquiry(_handle, value);
  }

  /// Registers a callback for XTWINOPS size queries (CSI 14/16/18 t).
  ///
  /// Return a [TerminalSizeInfo] with the current geometry, or null to
  /// silently ignore the query. Fires synchronously during [write].
  set onSize(ValueGetter<TerminalSizeInfo?>? value) {
    bindings.terminalSetOnSize(_handle, value);
  }

  /// Registers a callback for title changes via OSC 0 or OSC 2.
  ///
  /// Query the new [title] after the callback returns. Fires synchronously
  /// during [write].
  set onTitleChanged(VoidCallback? value) {
    bindings.terminalSetOnTitleChanged(_handle, value);
  }

  /// Registers a callback for PTY write-back data.
  ///
  /// Invoked when the terminal needs to send data back to the PTY, for
  /// example in response to device status reports or mode queries. The data
  /// is only valid for the duration of the callback; copy it if needed.
  /// Fires synchronously during [write].
  set onWritePty(ValueSetter<Uint8List>? value) {
    bindings.terminalSetOnWritePty(_handle, value);
  }

  /// Registers a callback for XTVERSION queries (CSI > q).
  ///
  /// Return the version string to report (e.g. "myterm 1.0"). Return an empty
  /// string to use the default "libghostty" identifier. Fires synchronously
  /// during [write].
  set onXtversion(ValueGetter<String>? value) {
    bindings.terminalSetOnXtversion(_handle, value);
  }

  /// Current 256-color palette with any active OSC 4 overrides applied.
  ///
  /// Always returns a 256-element list (the built-in default palette is used
  /// as a baseline).
  ///
  /// Throws [LibGhosttyException] if the terminal is in an invalid state.
  List<RgbColor> get palette {
    return check(bindings.terminalGetColorPalette(_handle));
  }

  /// Sets the default 256-color palette, or resets to built-in defaults if
  /// null.
  ///
  /// Only updates indices that have not been overridden by OSC 4. Per-index
  /// OSC overrides are preserved.
  ///
  /// Throws [LibGhosttyException] if the palette cannot be set.
  set palette(List<RgbColor>? colors) {
    checkCode(bindings.terminalSetColorPalette(_handle, colors));
  }

  /// Default 256-color palette, ignoring any OSC 4 overrides.
  ///
  /// Throws [LibGhosttyException] if the terminal is in an invalid state.
  List<RgbColor> get paletteDefault {
    return check(bindings.terminalGetColorPaletteDefault(_handle));
  }

  /// Current working directory as reported by OSC 7.
  ///
  /// The returned value is borrowed from the terminal. Read it immediately
  /// after [write] or [reset]; it may change on the next call to either.
  String get pwd => check(bindings.terminalGetPwd(_handle));

  /// Sets the working directory, or clears it if null.
  set pwd(String? value) => checkCode(bindings.terminalSetPwd(_handle, value));

  /// Number of rows in the scrollback buffer (excluding the active grid).
  int get scrollbackRows => check(bindings.terminalGetScrollbackRows(_handle));

  /// Scrollbar position and dimensions for rendering a scrollbar widget.
  ///
  /// May be expensive for terminals with large scrollback, as it requires
  /// traversing the scrollback page list to compute the total size.
  Scrollbar get scrollbar => check(bindings.terminalGetScrollbar(_handle));

  /// Terminal title as set by OSC 0 or OSC 2 sequences.
  ///
  /// The returned value is borrowed from the terminal. Read it immediately
  /// after [write] or [reset]; it may change on the next call to either.
  String get title => check(bindings.terminalGetTitle(_handle));

  /// Sets the terminal title, or clears it if null.
  set title(String? value) {
    checkCode(bindings.terminalSetTitle(_handle, value));
  }

  /// Total number of rows: active grid rows plus scrollback rows.
  int get totalRows => check(bindings.terminalGetTotalRows(_handle));

  /// Total terminal width in pixels (cols * cell width).
  int get widthPx => check(bindings.terminalGetWidthPx(_handle));

  /// Creates a [Formatter] for extracting terminal content as plain text,
  /// VT sequences, or HTML.
  ///
  /// [extra] controls which additional terminal state is included in
  /// [FormatterFormat.vt] output (cursor position, modes, palette, etc.).
  /// Has no effect on plain text or HTML output.
  ///
  /// [selection] restricts the output to the given range. When null, the
  /// entire active screen is formatted.
  ///
  /// Throws [OutOfMemoryException] when the allocation fails.
  ///
  /// ```dart
  /// final fmt = terminal.createFormatter(format: FormatterFormat.plain);
  /// final text = fmt.format();
  /// fmt.dispose();
  /// ```
  Formatter createFormatter({
    required FormatterFormat format,
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
    Selection? selection,
  }) {
    if (selection == null) {
      return Formatter._(
        _handle,
        format: format,
        unwrap: unwrap,
        trim: trim,
        extra: extra,
      );
    }
    final start = GridRef._(
      _handle,
      col: selection.startCol,
      row: selection.startRow,
      pointTag: selection.pointTag,
    );
    final end = GridRef._(
      _handle,
      col: selection.endCol,
      row: selection.endRow,
      pointTag: selection.pointTag,
    );
    try {
      return Formatter._(
        _handle,
        format: format,
        unwrap: unwrap,
        trim: trim,
        extra: extra,
        selection: (
          start: start._handle,
          end: end._handle,
          rectangle: selection.rectangle,
        ),
      );
    } finally {
      start.dispose();
      end.dispose();
    }
  }

  /// Releases all resources held by this terminal instance.
  ///
  /// Disposes the [keyEncoder], [renderState], and [mouseEncoder], clears all
  /// registered callbacks, and frees the native terminal handle. Safe to call
  /// multiple times; subsequent calls are no-ops.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    keyEncoder.dispose();
    renderState.dispose();
    mouseEncoder.dispose();
    clearListeners();
    bindings.terminalDisposeCallbacks(_handle);
    _finalizer.detach(this);
    bindings.terminalFree(_handle);
  }

  /// Resolves a point in terminal coordinates to a [GridRef] for a single cell.
  ///
  /// [pointTag] selects the coordinate space: [PointTag.active] and
  /// [PointTag.viewport] are fast lookups; [PointTag.screen] and
  /// [PointTag.history] may require traversing the full scrollback page list.
  ///
  /// Not intended for render loops; use [renderState] for bulk cell access.
  ///
  /// Throws [InvalidValueException] if the coordinates are out of range.
  ///
  /// ```dart
  /// final ref = terminal.gridRefAt(col: 0, row: 0);
  /// final codepoint = ref.codepoint;
  /// ref.dispose();
  /// ```
  GridRef gridRefAt({
    required int col,
    required int row,
    PointTag pointTag = .active,
  }) => GridRef._(_handle, col: col, row: row, pointTag: pointTag);

  /// Queries whether the given terminal [mode] is currently enabled.
  bool modeGet(TerminalMode mode) {
    return check(bindings.terminalModeGet(_handle, mode.value));
  }

  /// Enables or disables the given terminal [mode].
  void modeSet(TerminalMode mode, {required bool value}) {
    checkCode(bindings.terminalModeSet(_handle, mode.value, value: value));
  }

  /// Performs a full reset (RIS): resets modes, scrollback, scrolling region,
  /// and screen contents to defaults while preserving terminal dimensions.
  void reset() => bindings.terminalReset(_handle);

  /// Resizes the terminal grid to the given cell dimensions.
  ///
  /// The primary screen reflows content when autowrap is enabled; the
  /// alternate screen does not reflow. A no-op if dimensions are unchanged.
  ///
  /// Side effects: disables synchronized output mode, and sends an in-band
  /// size report if mode 2048 is enabled.
  ///
  /// [cellWidthPx] and [cellHeightPx] set the pixel dimensions per cell,
  /// used to compute [widthPx] and [heightPx] and to respond to pixel-based
  /// size queries. Notifies listeners synchronously after the resize completes.
  ///
  /// Throws [InvalidValueException] if [cols] or [rows] is zero.
  /// Throws [OutOfMemoryException] if reflow allocation fails.
  void resize({
    required int cols,
    required int rows,
    int cellWidthPx = 0,
    int cellHeightPx = 0,
  }) {
    checkCode(
      bindings.terminalResize(_handle, cols, rows, cellWidthPx, cellHeightPx),
    );
    notifyListeners();
  }

  /// Scrolls the viewport to the bottom (active area).
  void scrollToBottom() => bindings.terminalScrollViewport(_handle, .bottom, 0);

  /// Scrolls the viewport to the top of the scrollback history.
  void scrollToTop() => bindings.terminalScrollViewport(_handle, .top, 0);

  /// Scrolls the viewport by [delta] rows. Positive values scroll down
  /// (toward the active area), negative values scroll up (toward history).
  void scrollViewport(int delta) {
    if (delta == 0) return;
    bindings.terminalScrollViewport(_handle, .delta, delta);
  }

  /// Feeds raw VT-encoded bytes into the terminal for processing.
  ///
  /// Never fails: malformed input is logged internally but does not corrupt
  /// state or throw. All registered callbacks fire synchronously during this
  /// call. Callers **must not** call [write] from within a callback (no
  /// reentrancy).
  ///
  /// Sequences requiring output (device status reports, mode queries) are
  /// silently ignored unless [onWritePty] is registered. Notifies listeners
  /// synchronously after processing completes.
  ///
  /// ```dart
  /// terminal.write(Uint8List.fromList(utf8.encode('Hello\r\n')));
  /// ```
  void write(Uint8List data) {
    bindings.terminalVtWrite(_handle, data);
    notifyListeners();
  }

  static int _create(int cols, int rows, int maxScrollback) {
    return check(bindings.terminalNew(cols, rows, maxScrollback));
  }

  static RgbColor? _optionalColor(CResult<RgbColor> result) {
    return result.$1 == .noValue ? null : check(result);
  }
}
