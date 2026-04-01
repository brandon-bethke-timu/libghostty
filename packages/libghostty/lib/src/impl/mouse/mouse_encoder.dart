import 'package:meta/meta.dart';

import '../../bindings/bindings.dart';
import '../terminal/terminal.dart';
import 'mouse_event.dart';

@internal
int mouseEncoderHandle(MouseEncoder encoder) => encoder._handle;

/// Encodes mouse events into terminal escape sequences, supporting X10,
/// UTF-8, SGR, URxvt, and SGR-Pixels mouse protocols.
///
/// The encoder is stateful: configure it with the tracking mode, output
/// format, and renderer size before encoding. Options can be set individually
/// or synced from a [Terminal] via [syncFrom].
///
/// When used with a [Terminal], call [syncFrom] after each [Terminal.write]
/// to keep the encoder in sync with tracking mode changes the program may
/// have made.
///
/// ```dart
/// final terminal = Terminal(cols: 80, rows: 24);
/// terminal.write(vtData); // May enable mouse tracking
///
/// final encoder = MouseEncoder();
/// encoder.syncFrom(terminal);
/// encoder.setSize(const MouseEncoderSize(
///   screenWidth: 640, screenHeight: 480,
///   cellWidth: 8, cellHeight: 16,
/// ));
///
/// final event = MouseEvent()
///   ..action = MouseAction.press
///   ..button = MouseButton.left
///   ..setPosition(10.0, 20.0);
///
/// final seq = encoder.encode(event);
/// if (seq.isNotEmpty) pty.write(utf8.encode(seq));
///
/// event.dispose();
/// encoder.dispose();
/// terminal.dispose();
/// ```
class MouseEncoder {
  static final _finalizer = Finalizer<int>(bindings.mouseEncoderFree);

  final int _handle;
  var _disposed = false;

  /// Creates a new mouse encoder with default options.
  ///
  /// All modes start disabled (no mouse tracking). Configure with [syncFrom]
  /// or the typed setter methods, and call [setSize] before encoding.
  ///
  /// Throws [OutOfMemoryException] if the native allocation fails.
  MouseEncoder() : _handle = _create() {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases all resources associated with this encoder.
  ///
  /// The encoder must not be used after this call. Safe to call multiple
  /// times; subsequent calls are no-ops.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    bindings.mouseEncoderFree(_handle);
  }

  /// Encodes a [MouseEvent] into the appropriate terminal escape sequence
  /// based on the encoder's current options.
  ///
  /// Not all mouse events produce output. For example, motion events outside
  /// the tracked area or with no tracking mode enabled produce no sequence.
  /// Returns an empty string when the event produces no output.
  ///
  /// Throws [OutOfMemoryException] if the internal buffer allocation fails.
  ///
  /// ```dart
  /// final seq = encoder.encode(event);
  /// if (seq.isNotEmpty) pty.write(utf8.encode(seq));
  /// ```
  String encode(MouseEvent event) {
    return check(bindings.mouseEncoderEncode(_handle, mouseEventHandle(event)));
  }

  /// Clears internal motion deduplication state (last tracked cell).
  ///
  /// Call this when the terminal is reset or the viewport changes to avoid
  /// suppressing motion events that should be re-reported.
  void reset() => bindings.mouseEncoderReset(_handle);

  /// Sets whether any mouse button is currently pressed.
  ///
  /// The encoder uses this to distinguish drag events from plain motion.
  void setAnyButtonPressed({required bool pressed}) {
    bindings.mouseEncoderSetBoolOpt(_handle, .anyButtonPressed, value: pressed);
  }

  /// Sets the mouse output format (X10, UTF-8, SGR, URxvt, or SGR-Pixels).
  ///
  /// Controls how mouse coordinates and buttons are encoded in the escape
  /// sequence. Typically synced from the terminal via [syncFrom], but can
  /// be set directly.
  void setFormat(MouseFormat format) {
    bindings.mouseEncoderSetFormat(_handle, format);
  }

  /// Sets the renderer size context for pixel-to-cell coordinate conversion.
  ///
  /// Describes the rendered terminal geometry used to convert surface-space
  /// pixel positions into encoded cell coordinates. Must be called whenever
  /// the terminal grid dimensions or cell size change. Without this, the
  /// encoder cannot convert pixel positions to cell coordinates and will
  /// produce empty output.
  void setSize(MouseEncoderSize size) {
    bindings.mouseEncoderSetSize(_handle, size);
  }

  /// Sets the mouse tracking mode (none, X10, normal, button, or any).
  ///
  /// Controls which mouse events are reported. Typically synced from the
  /// terminal via [syncFrom], but can be set directly.
  void setTrackingMode(MouseTracking mode) {
    bindings.mouseEncoderSetTrackingMode(_handle, mode);
  }

  /// Sets whether to enable motion deduplication by last cell.
  ///
  /// When enabled, consecutive motion events that resolve to the same cell
  /// are suppressed. Call [reset] to clear the deduplication state.
  void setTrackLastCell({required bool enabled}) {
    bindings.mouseEncoderSetBoolOpt(_handle, .trackLastCell, value: enabled);
  }

  /// Syncs tracking mode and output format from the [terminal]'s current
  /// state.
  ///
  /// Reads the terminal's mouse tracking mode and output format and applies
  /// them to the encoder. Does not modify size or any-button state.
  void syncFrom(Terminal terminal) {
    bindings.mouseEncoderSetOptFromTerminal(_handle, terminalHandle(terminal));
  }

  static int _create() => check(bindings.mouseEncoderNew());
}
