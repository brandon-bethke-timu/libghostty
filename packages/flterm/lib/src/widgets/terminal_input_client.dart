import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Soft keyboard text input connection for the terminal.
///
/// Processes IME deltas and surfaces semantic events (text commits,
/// deletions, newlines).
@internal
class TerminalInputClient with DeltaTextInputClient {
  static final _newlinePattern = RegExp(r'[\n\r]');
  static const _sentinel = TextEditingValue(
    selection: .collapsed(offset: 1),
    text: ' ',
  );

  TextInputConnection? _connection;
  TextEditingValue _value = _sentinel;
  Brightness _keyboardAppearance = .dark;
  var _wasComposing = false;

  VoidCallback? onNewline;
  ValueChanged<int>? onDelete;
  ValueChanged<String>? onTextCommitted;
  ValueChanged<String>? onComposingChanged;

  @override
  AutofillScope? get currentAutofillScope => null;

  @override
  TextEditingValue get currentTextEditingValue => _value;

  bool get isAttached => _connection != null;

  set keyboardAppearance(Brightness value) => _keyboardAppearance = value;

  void attach({Brightness keyboardAppearance = Brightness.dark}) {
    _connection?.close();
    _connection = TextInput.attach(
      this,
      TextInputConfiguration(
        autocorrect: false,
        inputAction: .newline,
        enableDeltaModel: true,
        enableSuggestions: false,
        keyboardAppearance: keyboardAppearance,
      ),
    );
    _value = _sentinel;
    _connection!.setEditingState(_value);
  }

  @override
  void connectionClosed() => _connection = null;

  void detach() {
    _connection?.close();
    _connection = null;
    _value = _sentinel;
    _wasComposing = false;
  }

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  void hide() => _connection?.close();

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  bool onFocusReceived() => false;

  @override
  void performAction(TextInputAction action) {
    if (action == .newline) onNewline?.call();
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void performSelector(String selectorName) {}

  @override
  void removeTextPlaceholder() {}

  void show() {
    attach(keyboardAppearance: _keyboardAppearance);
    _connection?.show();
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void showToolbar() {}

  @override
  void updateEditingValue(TextEditingValue value) {
    _value = value;
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> deltas) {
    for (final delta in deltas) {
      _value = delta.apply(_value);
      _processDelta(delta);
    }
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  void _processDelta(TextEditingDelta delta) {
    final isComposing = _value.composing != TextRange.empty;

    switch (delta) {
      case TextEditingDeltaInsertion() when !isComposing:
        final text = _stripNewlines(delta.textInserted);
        if (text.isNotEmpty) onTextCommitted?.call(text);
        _resetBuffer();
      case TextEditingDeltaDeletion() when !isComposing:
        final count = delta.deletedRange.end - delta.deletedRange.start;
        onDelete?.call(count);
        _resetBuffer();
      case TextEditingDeltaReplacement() when !isComposing:
        final text = _stripNewlines(delta.replacementText);
        if (text.isNotEmpty) onTextCommitted?.call(text);
        _resetBuffer();
      default:
        break;
    }

    if (isComposing) {
      onComposingChanged?.call(
        _value.text.substring(_value.composing.start, _value.composing.end),
      );
    } else if (_wasComposing) {
      onComposingChanged?.call('');
    }

    _wasComposing = isComposing;
  }

  void _resetBuffer() {
    _value = _sentinel;
    _connection?.setEditingState(_value);
  }

  static String _stripNewlines(String text) {
    return text.replaceAll(_newlinePattern, '');
  }
}
