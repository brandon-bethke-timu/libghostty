import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show FocusNode;
import 'package:libghostty/libghostty.dart' as vt;
import 'package:meta/meta.dart' show internal;

import '../foundation.dart';
import 'terminal_controller.dart';
import 'terminal_input_client.dart';
import 'terminal_view_binding.dart';

@internal
class TerminalControllerImpl extends TerminalController
    implements TerminalViewBinding {
  static const _cr = 0x0d;
  static const _del = 0x7f;
  static const _formFeed = 0x0c;
  static final _clearScrollback = utf8.encode('\x1b[3J');
  static final _crBytes = Uint8List.fromList([_cr]);
  static final _delBytes = Uint8List.fromList([_del]);
  static final _formFeedBytes = Uint8List.fromList([_formFeed]);

  final vt.KeyEvent _keyEvent;
  final vt.KeyEncoder _keyEncoder;
  final TerminalInputClient _textInput;

  var _lastModes = const vt.TerminalModes();
  var _virtualMods = vt.Mods.none;
  var _wasFocused = false;
  TerminalSelection? _selection;
  FocusNode? _focusNode;
  vt.Terminal? _terminal;

  @override
  ValueChanged<Uint8List>? onOutput;

  TerminalControllerImpl()
    : _keyEvent = vt.KeyEvent(),
      _keyEncoder = vt.KeyEncoder(),
      _textInput = TerminalInputClient(),
      super.base() {
    _textInput
      ..onTextCommitted = _handleTextCommitted
      ..onDelete = _handleDelete
      ..onNewline = _handleNewline;
  }

  FocusNode? get focusNode => _focusNode;

  @override
  set focusNode(FocusNode? value) {
    if (_focusNode == value) return;
    _focusNode?.removeListener(_onFocusChanged);
    _focusNode = value;
    _wasFocused = value?.hasFocus ?? false;
    _focusNode?.addListener(_onFocusChanged);
  }

  @override
  bool get hasFocus => _focusNode?.hasFocus ?? false;

  @override
  String get selectedText {
    final selection = _selection;
    if (_terminal == null || selection == null) return '';

    final buffer = StringBuffer();
    final selectionMode = selection.mode;
    final scrollbackLen = _terminal!.scrollback.length;

    for (var row = selection.topRow; row <= selection.bottomRow; row++) {
      final line = _lineAt(row, scrollbackLen);
      if (line == null || line.length == 0) continue;

      final cols = line.length;
      final startCol = switch (selection.mode) {
        .block => selection.topCol,
        _ => (row == selection.topRow ? selection.topCol : 0),
      };
      final endCol = switch (selectionMode) {
        .block => selection.bottomCol,
        _ => (row == selection.bottomRow ? selection.bottomCol : cols),
      };

      for (var col = startCol; col < endCol && col < cols; col++) {
        final cell = line.cellAt(col);
        if (cell.wide == .spacerTail || cell.wide == .spacerHead) continue;
        buffer.write(cell.content.isEmpty ? ' ' : cell.content);
      }

      if (row < selection.bottomRow) {
        if (selectionMode == .block || !_isRowWrapped(row, scrollbackLen)) {
          buffer.write('\n');
        }
      }
    }

    return buffer.toString();
  }

  @override
  TerminalSelection? get selection => _selection;

  @override
  set selection(TerminalSelection? value) {
    if (_selection == value) return;
    _selection = value;
    notifyListeners();
  }

  @override
  set terminal(vt.Terminal? value) => _terminal = value;

  @override
  vt.Mods get virtualMods => _virtualMods;

  @override
  void attachInput({Brightness keyboardAppearance = Brightness.dark}) {
    _textInput.attach(keyboardAppearance: keyboardAppearance);
  }

  @override
  void clear() {
    final terminal = _terminal;
    if (terminal == null) return;
    if (terminal.modes.screenMode == vt.ScreenMode.alternate) return;
    clearSelection();
    terminal.write(_clearScrollback);
    _emitOutput(_formFeedBytes);
  }

  @override
  void clearSelection() => selection = null;

  @override
  void clearVirtualMods() {
    if (_virtualMods.isEmpty) return;
    _virtualMods = vt.Mods.none;
    notifyListeners();
  }

  @override
  void detachInput() => _textInput.detach();

  @override
  void dispose() {
    _focusNode?.removeListener(_onFocusChanged);
    _keyEvent.dispose();
    _keyEncoder.dispose();
    _textInput.detach();
    super.dispose();
  }

  @override
  Uint8List? encodeKeyboardEvent(KeyEvent event) {
    final key = keyFromPhysical(event.physicalKey);
    final action = switch (event) {
      KeyDownEvent() => vt.KeyAction.press,
      KeyUpEvent() => vt.KeyAction.release,
      KeyRepeatEvent() => vt.KeyAction.repeat,
      _ => null,
    };

    if (action == null) return null;

    var mods = _virtualMods;
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed) mods = mods | vt.Mods.shift;
    if (keyboard.isControlPressed) mods = mods | vt.Mods.ctrl;
    if (keyboard.isAltPressed) mods = mods | vt.Mods.alt;
    if (keyboard.isMetaPressed) mods = mods | vt.Mods.superKey;

    _keyEvent
      ..key = key
      ..mods = mods
      ..action = action
      ..utf8 = event.character
      ..unshiftedCodepoint = unshiftedCodepointForKey(key);

    final result = _keyEncoder.encode(_keyEvent);
    if (result.isEmpty) return null;
    clearVirtualMods();
    return utf8.encode(result);
  }

  @override
  void hideKeyboard() => _textInput.hide();

  @override
  void requestFocus() => _focusNode?.requestFocus();

  @override
  void selectAll() {
    final terminal = _terminal;
    if (terminal == null) return;

    final screen = terminal.screen;
    final scrollbackLen = terminal.scrollback.length;

    var lastScreenRow = -1;
    for (var row = screen.rows - 1; row >= 0; row--) {
      final line = screen.lineAt(row);
      for (var col = 0; col < line.length; col++) {
        if (!line.cellAt(col).isEmpty) {
          lastScreenRow = row;
          break;
        }
      }
      if (lastScreenRow >= 0) break;
    }

    if (lastScreenRow < 0 && scrollbackLen == 0) return;

    int endRow;
    int endCol;

    if (lastScreenRow >= 0) {
      endRow = scrollbackLen + lastScreenRow;
      endCol = 0;
      final line = screen.lineAt(lastScreenRow);
      for (var col = line.length - 1; col >= 0; col--) {
        if (!line.cellAt(col).isEmpty) {
          endCol = col + 1;
          break;
        }
      }
    } else {
      endRow = scrollbackLen - 1;
      endCol = screen.cols;
    }

    selection = TerminalSelection(
      startRow: 0,
      startCol: 0,
      endRow: endRow,
      endCol: endCol,
    );
  }

  @override
  void sendKey(vt.Key key, {vt.Mods mods = vt.Mods.none}) {
    final effectiveMods = mods | _virtualMods;
    final codepoint = unshiftedCodepointForKey(key);
    _keyEvent
      ..key = key
      ..mods = effectiveMods
      ..action = vt.KeyAction.press
      ..unshiftedCodepoint = codepoint
      ..utf8 = codepoint > 0 ? String.fromCharCode(codepoint) : null;

    final result = _keyEncoder.encode(_keyEvent);
    if (result.isEmpty) return;
    _emitOutput(utf8.encode(result));
    clearVirtualMods();
  }

  @override
  void sendText(String text) {
    if (text.isEmpty) return;
    _emitOutput(utf8.encode(text));
    clearVirtualMods();
  }

  @override
  void showKeyboard() => _textInput.show();

  @override
  vt.MouseTracking? syncModes(vt.TerminalModes modes) {
    if (modes == _lastModes) return null;

    if (modes.cursorKeyApplication != _lastModes.cursorKeyApplication) {
      _keyEncoder.setCursorKeyApplication(enabled: modes.cursorKeyApplication);
    }
    if (modes.keypadApplication != _lastModes.keypadApplication) {
      _keyEncoder.setKeypadKeyApplication(enabled: modes.keypadApplication);
    }

    final mouseChanged = modes.mouseTracking != _lastModes.mouseTracking;
    _lastModes = modes;
    return mouseChanged ? modes.mouseTracking : null;
  }

  @override
  void testCommitText(String text) => _handleTextCommitted(text);

  @override
  void toggleMod(vt.Mods mod) {
    _virtualMods = _virtualMods ^ mod;
    notifyListeners();
  }

  @override
  void unfocus() => _focusNode?.unfocus();

  void _emitOutput(Uint8List bytes) => onOutput?.call(bytes);

  void _handleDelete(int count) {
    if (count == 1) {
      _emitOutput(_delBytes);
      return;
    }
    _emitOutput(Uint8List(count)..fillRange(0, count, _del));
  }

  void _handleNewline() {
    _emitOutput(_crBytes);
    clearVirtualMods();
  }

  void _handleTextCommitted(String text) {
    if (_virtualMods.isEmpty) {
      _emitOutput(utf8.encode(text));
      return;
    }

    if (text.length == 1) {
      final key = keyFromCodepoint(text.codeUnitAt(0));
      if (key != null) {
        sendKey(key);
        return;
      }
    }

    _emitOutput(utf8.encode(text));
    clearVirtualMods();
  }

  bool _isRowWrapped(int absoluteRow, int scrollbackLen) {
    if (absoluteRow < scrollbackLen) {
      return _terminal!.scrollback.isRowWrapped(absoluteRow);
    }
    final screenRow = absoluteRow - scrollbackLen;
    if (screenRow >= _terminal!.screen.rows) return false;
    return _terminal!.screen.isRowWrapped(screenRow);
  }

  vt.Line? _lineAt(int absoluteRow, int scrollbackLen) {
    if (absoluteRow < 0) return null;
    if (absoluteRow < scrollbackLen) {
      return _terminal!.scrollback.lineAt(absoluteRow);
    }
    final screenRow = absoluteRow - scrollbackLen;
    if (screenRow >= _terminal!.screen.rows) return null;
    return _terminal!.screen.lineAt(screenRow);
  }

  void _onFocusChanged() {
    final focused = _focusNode?.hasFocus ?? false;
    if (focused == _wasFocused) return;
    _wasFocused = focused;
    notifyListeners();
  }
}
