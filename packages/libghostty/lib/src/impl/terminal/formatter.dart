part of 'terminal.dart';

/// Formats terminal content as plain text, VT sequences, or HTML.
///
/// Captures a borrowed reference to a [Terminal] and reads its current state
/// on each [format] call. The [Terminal] must outlive this formatter.
///
/// Create via [Terminal.createFormatter].
///
/// ```dart
/// final formatter = terminal.createFormatter(format: .plain);
/// final text = formatter.format();
/// formatter.dispose();
/// ```
class Formatter {
  static final _finalizer = Finalizer<int>(bindings.formatterFree);

  final int _handle;
  var _disposed = false;

  Formatter._(
    int terminalHandle, {
    required FormatterFormat format,
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
  }) : _handle = _create(terminalHandle, format, unwrap, trim, extra) {
    _finalizer.attach(this, _handle, detach: this);
  }

  /// Releases all resources associated with this formatter.
  ///
  /// The formatter must not be used after this call. Safe to call multiple
  /// times; subsequent calls are no-ops.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _finalizer.detach(this);
    bindings.formatterFree(_handle);
  }

  /// Formats the terminal's current active screen content and returns the
  /// result as a string.
  ///
  /// Each call reads the terminal's current state, so calling [format]
  /// after a [Terminal.write] reflects the updated content.
  ///
  /// Throws [OutOfMemoryException] if the output buffer allocation fails.
  String format() => check(bindings.formatterFormat(_handle));

  static int _create(
    int terminalHandle,
    FormatterFormat format,
    bool unwrap,
    bool trim,
    FormatterExtra extra,
  ) {
    return check(
      bindings.formatterTerminalNew(
        terminalHandle,
        format,
        unwrap: unwrap,
        trim: trim,
        extra: extra,
      ),
    );
  }
}
