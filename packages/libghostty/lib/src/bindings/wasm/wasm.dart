import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../../ffi/libghostty_enums.g.dart';
import '../../ffi/libghostty_wasm.g.dart';
import '../interface.dart';
import 'adapter.dart';
import 'layouts.dart';
import 'memory.dart';

GhosttyBindings? _instance;

GhosttyBindings get bindings {
  if (_instance == null) {
    throw StateError(
      'libghostty WASM bindings not initialized. Call initializeForWeb() '
      'first.',
    );
  }
  return _instance!;
}

/// Loads the libghostty-vt WASM module and initializes bindings for web use.
///
/// ```dart
/// await initializeForWeb(Uri.parse('assets/libghostty.wasm'));
/// ```
Future<void> initializeForWeb(Uri wasmUri) async {
  final response = await web.window.fetch(wasmUri.toString().toJS).toDart;
  final bytes = await response.arrayBuffer().toDart;
  final imports = _buildImports();
  final resultObj =
      (await _wasmInstantiate(bytes, imports).toDart)! as JSObject;
  final instance = resultObj['instance']! as JSObject;
  final exports = instance['exports']! as JSObject;
  _instance = WasmBindings._(exports);
}

JSObject _buildImports() {
  final env = newJsObject();
  env['log'] = ((JSNumber ptr, JSNumber len) {}).toJS;
  final imports = newJsObject();
  imports['env'] = env;
  return imports;
}

@JS('WebAssembly.instantiate')
external JSPromise _wasmInstantiate(JSArrayBuffer bytes, JSObject imports);

class WasmBindings implements GhosttyBindings {
  final Mem _mem;
  final web.Table _table;
  late final Layouts _layout;
  final GhosttyExports _exports;
  final _utf8Ptrs = <int, (int ptr, int len)>{};
  final _callbacks = <int, Map<TerminalOption, (int index, Function fn)>>{};
  final _stringBufs = <int, Map<TerminalOption, (int ptr, int len)>>{};

  WasmBindings._(JSObject exports)
    : _exports = GhosttyExports(exports),
      _mem = Mem(GhosttyExports(exports)),
      _table =
          (exports['__indirect_function_table'] as web.Table?) ??
          (throw StateError(
            'WASM module does not export __indirect_function_table',
          )) {
    final json = jsonDecode(_mem.readCString(_exports.ghostty_type_json()));
    _layout = Layouts(json as Map<String, dynamic>);
  }

  int _registerCallback(
    JSFunction jsFunction,
    List<String> params, {
    List<String> results = const [],
    int? reuseIndex,
  }) {
    final wasmFunc = wrapJsAsWasmFunction(jsFunction, params, results);
    final index = reuseIndex ?? _table.grow(1);
    _table.set(index, wasmFunc);
    return index;
  }

  @override
  CResult<int> keyEventNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_key_event_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void keyEventFree(int handle) {
    final prev = _utf8Ptrs.remove(handle);
    if (prev != null) _exports.ghostty_wasm_free_u8_array(prev.$1, prev.$2);
    _exports.ghostty_key_event_free(handle);
  }

  @override
  void keyEventSetAction(int handle, KeyAction action) {
    _exports.ghostty_key_event_set_action(handle, action.value);
  }

  @override
  KeyAction keyEventGetAction(int handle) {
    return .fromValue(_exports.ghostty_key_event_get_action(handle));
  }

  @override
  void keyEventSetKey(int handle, Key key) {
    _exports.ghostty_key_event_set_key(handle, key.value);
  }

  @override
  Key keyEventGetKey(int handle) {
    return .fromValue(_exports.ghostty_key_event_get_key(handle));
  }

  @override
  void keyEventSetMods(int handle, int mods) {
    _exports.ghostty_key_event_set_mods(handle, mods);
  }

  @override
  int keyEventGetMods(int handle) {
    return _exports.ghostty_key_event_get_mods(handle);
  }

  @override
  void keyEventSetConsumedMods(int handle, int mods) {
    _exports.ghostty_key_event_set_consumed_mods(handle, mods);
  }

  @override
  int keyEventGetConsumedMods(int handle) {
    return _exports.ghostty_key_event_get_consumed_mods(handle);
  }

  @override
  void keyEventSetComposing(int handle, {required bool composing}) {
    _exports.ghostty_key_event_set_composing(handle, composing ? 1 : 0);
  }

  @override
  bool keyEventGetComposing(int handle) {
    return _exports.ghostty_key_event_get_composing(handle) != 0;
  }

  @override
  void keyEventSetUtf8(int handle, String? text) {
    final prev = _utf8Ptrs.remove(handle);
    if (prev != null) {
      _exports.ghostty_wasm_free_u8_array(prev.$1, prev.$2);
    }

    if (text == null) {
      _exports.ghostty_key_event_set_utf8(handle, 0, 0);
      return;
    }

    final encoded = utf8.encode(text);
    final ptr = _exports.ghostty_wasm_alloc_u8_array(encoded.length);
    _mem.writeBytes(ptr, encoded);
    _exports.ghostty_key_event_set_utf8(handle, ptr, encoded.length);
    _utf8Ptrs[handle] = (ptr, encoded.length);
  }

  @override
  String? keyEventGetUtf8(int handle) {
    final lenPtr = _exports.ghostty_wasm_alloc_usize();
    final charPtr = _exports.ghostty_key_event_get_utf8(handle, lenPtr);
    if (charPtr == 0) {
      _exports.ghostty_wasm_free_usize(lenPtr);
      return null;
    }
    final len = _mem.readU32(lenPtr);
    _exports.ghostty_wasm_free_usize(lenPtr);
    if (len == 0) return null;
    return utf8.decode(_mem.readBytes(charPtr, len));
  }

  @override
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint) {
    _exports.ghostty_key_event_set_unshifted_codepoint(handle, codepoint);
  }

  @override
  int keyEventGetUnshiftedCodepoint(int handle) {
    return _exports.ghostty_key_event_get_unshifted_codepoint(handle);
  }

  @override
  CResult<int> keyEncoderNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_key_encoder_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void keyEncoderFree(int handle) {
    _exports.ghostty_key_encoder_free(handle);
  }

  @override
  void keyEncoderSetBoolOpt(
    int handle,
    KeyEncoderOption option, {
    required bool value,
  }) {
    final ptr = _exports.ghostty_wasm_alloc_u8();
    _mem.writeU8(ptr, value ? 1 : 0);
    _exports.ghostty_key_encoder_setopt(handle, option.value, ptr);
    _exports.ghostty_wasm_free_u8(ptr);
  }

  @override
  void keyEncoderSetKittyFlags(int handle, int flags) {
    final ptr = _exports.ghostty_wasm_alloc_u8();
    _mem.writeU8(ptr, flags);
    _exports.ghostty_key_encoder_setopt(
      handle,
      KeyEncoderOption.kittyFlags.value,
      ptr,
    );
    _exports.ghostty_wasm_free_u8(ptr);
  }

  @override
  void keyEncoderSetOptionAsAlt(int handle, OptionAsAlt value) {
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(ptr, value.value);
    _exports.ghostty_key_encoder_setopt(
      handle,
      KeyEncoderOption.macosOptionAsAlt.value,
      ptr,
    );
    _exports.ghostty_wasm_free_usize(ptr);
  }

  @override
  void keyEncoderSetOptFromTerminal(int encoder, int terminal) {
    _exports.ghostty_key_encoder_setopt_from_terminal(encoder, terminal);
  }

  @override
  CResult<String> keyEncoderEncode(int encoder, int event) {
    final outLen = _exports.ghostty_wasm_alloc_usize();
    var bufSize = 128;
    var buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    var result = Result.fromValue(
      _exports.ghostty_key_encoder_encode(encoder, event, buf, bufSize, outLen),
    );

    // Retry with the required size if the initial buffer was too small.
    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(buf, bufSize);
      bufSize = _mem.readU32(outLen);
      buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
      result = .fromValue(
        _exports.ghostty_key_encoder_encode(
          encoder,
          event,
          buf,
          bufSize,
          outLen,
        ),
      );
    }

    final len = _mem.readU32(outLen);
    final value = utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (result, value);
  }

  @override
  CResult<int> mouseEventNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_mouse_event_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void mouseEventFree(int handle) => _exports.ghostty_mouse_event_free(handle);

  @override
  void mouseEventSetAction(int handle, MouseAction action) {
    _exports.ghostty_mouse_event_set_action(handle, action.value);
  }

  @override
  MouseAction mouseEventGetAction(int handle) {
    return .fromValue(_exports.ghostty_mouse_event_get_action(handle));
  }

  @override
  void mouseEventSetButton(int handle, MouseButton button) {
    _exports.ghostty_mouse_event_set_button(handle, button.value);
  }

  @override
  void mouseEventClearButton(int handle) {
    _exports.ghostty_mouse_event_clear_button(handle);
  }

  @override
  CResult<MouseButton> mouseEventGetButton(int handle) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final hasButton =
        _exports.ghostty_mouse_event_get_button(handle, outPtr) != 0;
    final value = hasButton ? _mem.readI32(outPtr) : 0;
    _exports.ghostty_wasm_free_usize(outPtr);
    return (hasButton ? .success : .noValue, .fromValue(value));
  }

  @override
  void mouseEventSetMods(int handle, int mods) {
    _exports.ghostty_mouse_event_set_mods(handle, mods);
  }

  @override
  int mouseEventGetMods(int handle) {
    return _exports.ghostty_mouse_event_get_mods(handle);
  }

  @override
  void mouseEventSetPosition(int handle, double x, double y) {
    final posPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.mousePosSize);
    _mem.writeF32(posPtr, x);
    _mem.writeF32(posPtr + _layout.mousePosY, y);
    _exports.ghostty_mouse_event_set_position(handle, posPtr);
    _exports.ghostty_wasm_free_u8_array(posPtr, _layout.mousePosSize);
  }

  @override
  (double, double) mouseEventGetPosition(int handle) {
    final posPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.mousePosSize);
    _exports.ghostty_mouse_event_get_position(posPtr, handle);
    final x = _mem.readF32(posPtr);
    final y = _mem.readF32(posPtr + _layout.mousePosY);
    _exports.ghostty_wasm_free_u8_array(posPtr, _layout.mousePosSize);
    return (x, y);
  }

  @override
  CResult<int> mouseEncoderNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_mouse_encoder_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void mouseEncoderFree(int handle) {
    _exports.ghostty_mouse_encoder_free(handle);
  }

  @override
  void mouseEncoderSetBoolOpt(
    int handle,
    MouseEncoderOption option, {
    required bool value,
  }) {
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeU8(ptr, value ? 1 : 0);
    _exports.ghostty_mouse_encoder_setopt(handle, option.value, ptr);
    _exports.ghostty_wasm_free_usize(ptr);
  }

  @override
  void mouseEncoderSetTrackingMode(int handle, MouseTrackingMode mode) {
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(ptr, mode.value);
    _exports.ghostty_mouse_encoder_setopt(
      handle,
      MouseEncoderOption.event.value,
      ptr,
    );
    _exports.ghostty_wasm_free_usize(ptr);
  }

  @override
  void mouseEncoderSetFormat(int handle, MouseFormat format) {
    final ptr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(ptr, format.value);
    _exports.ghostty_mouse_encoder_setopt(
      handle,
      MouseEncoderOption.format.value,
      ptr,
    );
    _exports.ghostty_wasm_free_usize(ptr);
  }

  @override
  void mouseEncoderSetSize(int handle, MouseEncoderSize size) {
    final ptr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.mouseEncoderSizeSize,
    );
    _mem.writeU32(ptr, _layout.mouseEncoderSizeSize);
    _mem.writeU32(ptr + _layout.mouseEncoderSizeScreenWidth, size.screenWidth);
    _mem.writeU32(
      ptr + _layout.mouseEncoderSizeScreenHeight,
      size.screenHeight,
    );
    _mem.writeU32(ptr + _layout.mouseEncoderSizeCellWidth, size.cellWidth);
    _mem.writeU32(ptr + _layout.mouseEncoderSizeCellHeight, size.cellHeight);
    _mem.writeU32(ptr + _layout.mouseEncoderSizePaddingTop, size.paddingTop);
    _mem.writeU32(
      ptr + _layout.mouseEncoderSizePaddingBottom,
      size.paddingBottom,
    );
    _mem.writeU32(
      ptr + _layout.mouseEncoderSizePaddingRight,
      size.paddingRight,
    );
    _mem.writeU32(ptr + _layout.mouseEncoderSizePaddingLeft, size.paddingLeft);
    _exports.ghostty_mouse_encoder_setopt(
      handle,
      MouseEncoderOption.size.value,
      ptr,
    );
    _exports.ghostty_wasm_free_u8_array(ptr, _layout.mouseEncoderSizeSize);
  }

  @override
  void mouseEncoderSetOptFromTerminal(int encoder, int terminal) {
    _exports.ghostty_mouse_encoder_setopt_from_terminal(encoder, terminal);
  }

  @override
  void mouseEncoderReset(int handle) {
    _exports.ghostty_mouse_encoder_reset(handle);
  }

  @override
  CResult<String> mouseEncoderEncode(int encoder, int event) {
    final outLen = _exports.ghostty_wasm_alloc_usize();
    var bufSize = 128;
    var buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    var result = Result.fromValue(
      _exports.ghostty_mouse_encoder_encode(
        encoder,
        event,
        buf,
        bufSize,
        outLen,
      ),
    );

    // Retry with the required size if the initial buffer was too small.
    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(buf, bufSize);
      bufSize = _mem.readU32(outLen);
      buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
      result = .fromValue(
        _exports.ghostty_mouse_encoder_encode(
          encoder,
          event,
          buf,
          bufSize,
          outLen,
        ),
      );
    }

    final len = _mem.readU32(outLen);
    final value = utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (result, value);
  }

  @override
  CResult<int> oscNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_osc_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void oscFree(int handle) => _exports.ghostty_osc_free(handle);

  @override
  void oscFeedByte(int handle, int byte) {
    _exports.ghostty_osc_next(handle, byte);
  }

  @override
  int oscEnd(int handle, int terminator) {
    return _exports.ghostty_osc_end(handle, terminator);
  }

  @override
  OscCommandType oscCommandType(int command) {
    return .fromValue(_exports.ghostty_osc_command_type(command));
  }

  @override
  String? oscCommandWindowTitle(int command) {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final success = _exports.ghostty_osc_command_data(
      command,
      OscCommandData.changeWindowTitleStr.value,
      outPtr,
    );
    if (success == 0) {
      _exports.ghostty_wasm_free_opaque(outPtr);
      return null;
    }
    final charPtr = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    if (charPtr == 0) return null;
    return _mem.readCString(charPtr);
  }

  @override
  void oscReset(int handle) => _exports.ghostty_osc_reset(handle);

  @override
  CResult<int> sgrNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_sgr_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void sgrFree(int handle) => _exports.ghostty_sgr_free(handle);

  @override
  Result sgrSetParams(int handle, List<int> params, List<String>? separators) {
    final paramsPtr = _exports.ghostty_wasm_alloc_u16_array(params.length);
    var sepsPtr = 0;

    for (var i = 0; i < params.length; i++) {
      _mem.writeU16(paramsPtr + i * 2, params[i]);
    }

    if (separators != null) {
      sepsPtr = _exports.ghostty_wasm_alloc_u8_array(separators.length);
      for (var i = 0; i < separators.length; i++) {
        _mem.writeU8(sepsPtr + i, separators[i].codeUnitAt(0));
      }
    }

    final result = _exports.ghostty_sgr_set_params(
      handle,
      paramsPtr,
      sepsPtr,
      params.length,
    );

    _exports.ghostty_wasm_free_u16_array(paramsPtr, params.length);
    if (sepsPtr != 0) {
      _exports.ghostty_wasm_free_u8_array(sepsPtr, separators!.length);
    }
    return .fromValue(result);
  }

  @override
  SgrAttribute? sgrNext(int handle) {
    final attrPtr = _exports.ghostty_wasm_alloc_sgr_attribute();
    final hasNext = _exports.ghostty_sgr_next(handle, attrPtr) != 0;
    if (!hasNext) {
      _exports.ghostty_wasm_free_sgr_attribute(attrPtr);
      return null;
    }
    final attr = _readSgrAttribute(attrPtr);
    _exports.ghostty_wasm_free_sgr_attribute(attrPtr);
    return attr;
  }

  @override
  void sgrReset(int handle) => _exports.ghostty_sgr_reset(handle);

  @override
  bool pasteIsSafe(String data) {
    final encoded = utf8.encode(data);
    if (encoded.isEmpty) return _exports.ghostty_paste_is_safe(0, 0) != 0;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(encoded.length);
    _mem.writeBytes(ptr, encoded);
    final result = _exports.ghostty_paste_is_safe(ptr, encoded.length) != 0;
    _exports.ghostty_wasm_free_u8_array(ptr, encoded.length);
    return result;
  }

  @override
  CResult<int> terminalNew(int cols, int rows, int maxScrollback) {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final optsPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.terminalOptsSize,
    );
    _mem.writeU16(optsPtr, cols);
    _mem.writeU16(optsPtr + _layout.terminalOptsRows, rows);
    _mem.writeU32(optsPtr + _layout.terminalOptsMaxScrollback, maxScrollback);
    final result = _exports.ghostty_terminal_new(0, outPtr, optsPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    _exports.ghostty_wasm_free_u8_array(optsPtr, _layout.terminalOptsSize);
    return (.fromValue(result), handle);
  }

  @override
  void terminalFree(int handle) => _exports.ghostty_terminal_free(handle);

  @override
  void terminalVtWrite(int handle, Uint8List data) {
    if (data.isEmpty) return;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(data.length);
    _mem.writeBytes(ptr, data);
    _exports.ghostty_terminal_vt_write(handle, ptr, data.length);
    _exports.ghostty_wasm_free_u8_array(ptr, data.length);
  }

  @override
  Result terminalResize(
    int handle,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  ) {
    return .fromValue(
      _exports.ghostty_terminal_resize(
        handle,
        cols,
        rows,
        cellWidthPx,
        cellHeightPx,
      ),
    );
  }

  @override
  void terminalReset(int handle) => _exports.ghostty_terminal_reset(handle);

  @override
  void terminalScrollViewport(
    int handle,
    TerminalScrollViewportTag tag,
    int delta,
  ) {
    final svPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.scrollViewportSize,
    );
    _mem.writeU32(svPtr, tag.value);
    _mem.writeI32(svPtr + _layout.scrollViewportDelta, delta);
    _exports.ghostty_terminal_scroll_viewport(handle, svPtr);
    _exports.ghostty_wasm_free_u8_array(svPtr, _layout.scrollViewportSize);
  }

  @override
  CResult<int> terminalGetCols(int handle) => _terminalGetU16(handle, .cols);

  @override
  CResult<int> terminalGetRows(int handle) => _terminalGetU16(handle, .rows);

  @override
  CResult<int> terminalGetCursorX(int handle) {
    return _terminalGetU16(handle, .cursorX);
  }

  @override
  CResult<int> terminalGetCursorY(int handle) {
    return _terminalGetU16(handle, .cursorY);
  }

  @override
  CResult<bool> terminalGetCursorVisible(int handle) {
    return _terminalGetBool(handle, .cursorVisible);
  }

  @override
  CResult<bool> terminalGetCursorPendingWrap(int handle) {
    return _terminalGetBool(handle, .cursorPendingWrap);
  }

  @override
  CResult<TerminalScreen> terminalGetActiveScreen(int handle) {
    final raw = _terminalGetI32(handle, .activeScreen);
    return (raw.$1, TerminalScreen.fromValue(raw.$2));
  }

  @override
  CResult<int> terminalGetKittyKeyboardFlags(int handle) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_terminal_get(
      handle,
      TerminalData.kittyKeyboardFlags.value,
      outPtr,
    );
    final value = _mem.readU8(outPtr);
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  @override
  CResult<Scrollbar> terminalGetScrollbar(int handle) {
    final sbPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.scrollbarSize);
    final result = _exports.ghostty_terminal_get(
      handle,
      TerminalData.scrollbar.value,
      sbPtr,
    );
    final total = _mem.readU32(sbPtr);
    final offset = _mem.readU32(sbPtr + _layout.scrollbarOffset);
    final visible = _mem.readU32(sbPtr + _layout.scrollbarVisible);
    _exports.ghostty_wasm_free_u8_array(sbPtr, _layout.scrollbarSize);
    return (
      .fromValue(result),
      Scrollbar(total: total, offset: offset, visible: visible),
    );
  }

  @override
  CResult<bool> terminalModeGet(int handle, int mode) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_terminal_mode_get(handle, mode, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  @override
  Result terminalModeSet(int handle, int mode, {required bool value}) {
    return .fromValue(
      _exports.ghostty_terminal_mode_set(handle, mode, value ? 1 : 0),
    );
  }

  @override
  CResult<String> terminalGetTitle(int handle) {
    return _terminalGetString(handle, .title);
  }

  @override
  CResult<String> terminalGetPwd(int handle) {
    return _terminalGetString(handle, .pwd);
  }

  @override
  CResult<int> terminalGetTotalRows(int handle) {
    return _terminalGetU32(handle, .totalRows);
  }

  @override
  CResult<int> terminalGetScrollbackRows(int handle) {
    return _terminalGetU32(handle, .scrollbackRows);
  }

  @override
  CResult<int> terminalGetWidthPx(int handle) {
    return _terminalGetU32(handle, .widthPx);
  }

  @override
  CResult<int> terminalGetHeightPx(int handle) {
    return _terminalGetU32(handle, .heightPx);
  }

  @override
  Result terminalSetTitle(int handle, String? title) {
    return _terminalSetString(handle, TerminalOption.title, title);
  }

  @override
  Result terminalSetPwd(int handle, String? pwd) {
    return _terminalSetString(handle, TerminalOption.pwd, pwd);
  }

  @override
  Result terminalSetColorForeground(int handle, RgbColor? color) {
    return _terminalSetColor(handle, TerminalOption.colorForeground, color);
  }

  @override
  Result terminalSetColorBackground(int handle, RgbColor? color) {
    return _terminalSetColor(handle, TerminalOption.colorBackground, color);
  }

  @override
  Result terminalSetColorCursor(int handle, RgbColor? color) {
    return _terminalSetColor(handle, TerminalOption.colorCursor, color);
  }

  @override
  Result terminalSetColorPalette(int handle, List<RgbColor>? palette) {
    if (palette == null) {
      return Result.fromValue(
        _exports.ghostty_terminal_set(
          handle,
          TerminalOption.colorPalette.value,
          0,
        ),
      );
    }

    final paletteSize = 256 * _layout.colorRgbSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(paletteSize);
    for (var i = 0; i < 256; i++) {
      final offset = i * _layout.colorRgbSize;
      _mem.writeU8(ptr + offset, palette[i].r);
      _mem.writeU8(ptr + offset + _layout.colorRgbG, palette[i].g);
      _mem.writeU8(ptr + offset + _layout.colorRgbB, palette[i].b);
    }
    final result = _exports.ghostty_terminal_set(
      handle,
      TerminalOption.colorPalette.value,
      ptr,
    );
    _exports.ghostty_wasm_free_u8_array(ptr, paletteSize);
    return Result.fromValue(result);
  }

  @override
  CResult<RgbColor> terminalGetColorForeground(int handle) {
    return _terminalGetColor(handle, .colorForeground);
  }

  @override
  CResult<RgbColor> terminalGetColorBackground(int handle) {
    return _terminalGetColor(handle, .colorBackground);
  }

  @override
  CResult<RgbColor> terminalGetColorCursor(int handle) {
    return _terminalGetColor(handle, .colorCursor);
  }

  @override
  CResult<List<RgbColor>> terminalGetColorPalette(int handle) {
    return _terminalGetPalette(handle, .colorPalette);
  }

  @override
  CResult<RgbColor> terminalGetColorForegroundDefault(int handle) {
    return _terminalGetColor(handle, .colorForegroundDefault);
  }

  @override
  CResult<RgbColor> terminalGetColorBackgroundDefault(int handle) {
    return _terminalGetColor(handle, .colorBackgroundDefault);
  }

  @override
  CResult<RgbColor> terminalGetColorCursorDefault(int handle) {
    return _terminalGetColor(handle, .colorCursorDefault);
  }

  @override
  CResult<List<RgbColor>> terminalGetColorPaletteDefault(int handle) {
    return _terminalGetPalette(handle, .colorPaletteDefault);
  }

  @override
  CResult<Style> terminalGetCursorStyle(int handle) {
    return _terminalGetStyle(handle, .cursorStyle);
  }

  @override
  CResult<bool> terminalGetMouseTracking(int handle) {
    return _terminalGetBool(handle, .mouseTracking);
  }

  @override
  CResult<int> terminalGetKittyImageStorageLimit(int handle) {
    return _terminalGetU64(handle, .kittyImageStorageLimit);
  }

  @override
  CResult<bool> terminalGetKittyImageMediumFile(int handle) {
    return _terminalGetBool(handle, .kittyImageMediumFile);
  }

  @override
  CResult<bool> terminalGetKittyImageMediumTempFile(int handle) {
    return _terminalGetBool(handle, .kittyImageMediumTempFile);
  }

  @override
  CResult<bool> terminalGetKittyImageMediumSharedMem(int handle) {
    return _terminalGetBool(handle, .kittyImageMediumSharedMem);
  }

  @override
  Result terminalSetKittyImageStorageLimit(int handle, int? limit) {
    return _terminalSetU64(handle, .kittyImageStorageLimit, limit);
  }

  @override
  Result terminalSetKittyImageMediumFile(int handle, {bool? enabled}) {
    return _terminalSetBool(handle, .kittyImageMediumFile, enabled);
  }

  @override
  Result terminalSetKittyImageMediumTempFile(int handle, {bool? enabled}) {
    return _terminalSetBool(handle, .kittyImageMediumTempFile, enabled);
  }

  @override
  Result terminalSetKittyImageMediumSharedMem(int handle, {bool? enabled}) {
    return _terminalSetBool(handle, .kittyImageMediumSharedMem, enabled);
  }

  @override
  CResult<Uint8List> pasteEncode(String data, {required bool bracketed}) {
    final encoded = utf8.encode(data);
    final dataPtr = _exports.ghostty_wasm_alloc_u8_array(encoded.length);
    _mem.writeBytes(dataPtr, encoded);
    final outWrittenPtr = _exports.ghostty_wasm_alloc_usize();

    // First call to get the required buffer size.
    var result = Result.fromValue(
      _exports.ghostty_paste_encode(
        dataPtr,
        encoded.length,
        bracketed ? 1 : 0,
        0,
        0,
        outWrittenPtr,
      ),
    );

    if (result != .outOfSpace) {
      _exports.ghostty_wasm_free_usize(outWrittenPtr);
      _exports.ghostty_wasm_free_u8_array(dataPtr, encoded.length);
      return (result, Uint8List(0));
    }

    final bufLen = _mem.readU32(outWrittenPtr);
    final bufPtr = _exports.ghostty_wasm_alloc_u8_array(bufLen);

    // Re-encode the data since the first call modified it in place.
    _mem.writeBytes(dataPtr, encoded);

    result = .fromValue(
      _exports.ghostty_paste_encode(
        dataPtr,
        encoded.length,
        bracketed ? 1 : 0,
        bufPtr,
        bufLen,
        outWrittenPtr,
      ),
    );

    final written = _mem.readU32(outWrittenPtr);
    final bytes = Uint8List.fromList(_mem.readBytes(bufPtr, written));
    _exports.ghostty_wasm_free_u8_array(bufPtr, bufLen);
    _exports.ghostty_wasm_free_usize(outWrittenPtr);
    _exports.ghostty_wasm_free_u8_array(dataPtr, encoded.length);
    return (result, bytes);
  }

  @override
  void terminalSetOnWritePty(int handle, ValueSetter<Uint8List>? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.writePty;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int dataPtr, int len) {
        try {
          callback(Uint8List.fromList(_mem.readBytes(dataPtr, len)));
        } on Object catch (_) {}
      }).toJS,
      ['i32', 'i32', 'i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnBell(int handle, VoidCallback? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.bell;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata) {
        try {
          callback();
        } on Object catch (_) {}
      }).toJS,
      ['i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnTitleChanged(int handle, VoidCallback? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.titleChanged;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata) {
        try {
          callback();
        } on Object catch (_) {}
      }).toJS,
      ['i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnEnquiry(int handle, ValueGetter<Uint8List>? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.enquiry;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _freeStringBuf(handle, option);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final bufMap = _stringBufs.putIfAbsent(handle, () => {});
    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int sretPtr, int terminal, int userdata) {
        try {
          final data = callback();
          final prev = bufMap[option];
          if (prev != null) {
            _exports.ghostty_wasm_free_u8_array(prev.$1, prev.$2);
          }
          final ptr = _exports.ghostty_wasm_alloc_u8_array(data.length);
          _mem.writeBytes(ptr, data);
          bufMap[option] = (ptr, data.length);
          _mem.writeU32(sretPtr, ptr);
          _mem.writeU32(sretPtr + _layout.stringLen, data.length);
        } on Object catch (_) {
          _mem.writeU32(sretPtr, 0);
          _mem.writeU32(sretPtr + _layout.stringLen, 0);
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnXtversion(int handle, ValueGetter<String>? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.xtversion;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _freeStringBuf(handle, option);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final bufMap = _stringBufs.putIfAbsent(handle, () => {});
    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int sretPtr, int terminal, int userdata) {
        try {
          final result = callback();
          final bytes = utf8.encode(result);
          final prev = bufMap[option];
          if (prev != null) {
            _exports.ghostty_wasm_free_u8_array(prev.$1, prev.$2);
          }
          final ptr = _exports.ghostty_wasm_alloc_u8_array(bytes.length);
          _mem.writeBytes(ptr, bytes);
          bufMap[option] = (ptr, bytes.length);
          _mem.writeU32(sretPtr, ptr);
          _mem.writeU32(sretPtr + _layout.stringLen, bytes.length);
        } on Object catch (_) {
          _mem.writeU32(sretPtr, 0);
          _mem.writeU32(sretPtr + _layout.stringLen, 0);
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnColorScheme(
    int handle,
    ValueGetter<ColorScheme?>? callback,
  ) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.colorScheme;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int outPtr) {
        try {
          final result = callback();
          if (result == null) return 0;
          _mem.writeU32(outPtr, result.value);
          return 1;
        } on Object catch (_) {
          return 0;
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnSize(int handle, ValueGetter<TerminalSizeInfo?>? callback) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.size;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int outPtr) {
        try {
          final result = callback();
          if (result == null) return 0;
          _mem.writeU16(outPtr, result.rows);
          _mem.writeU16(outPtr + _layout.sizeReportColumns, result.columns);
          _mem.writeU32(outPtr + _layout.sizeReportCellWidth, result.cellWidth);
          _mem.writeU32(
            outPtr + _layout.sizeReportCellHeight,
            result.cellHeight,
          );
          return 1;
        } on Object catch (_) {
          return 0;
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalSetOnDeviceAttributes(
    int handle,
    ValueGetter<DeviceAttributesResponse?>? callback,
  ) {
    final map = _callbacks.putIfAbsent(handle, () => {});
    const option = TerminalOption.deviceAttributes;

    if (callback == null) {
      final existing = map.remove(option);
      if (existing != null) _table.set(existing.$1);
      _exports.ghostty_terminal_set(handle, option.value, 0);
      return;
    }

    final reuseIndex = map[option]?.$1;
    final index = _registerCallback(
      ((int terminal, int userdata, int outPtr) {
        try {
          final result = callback();
          if (result == null) return 0;
          _mem.writeU16(outPtr, result.primary.conformanceLevel);
          final featureCount = result.primary.features.length > 64
              ? 64
              : result.primary.features.length;
          for (var i = 0; i < featureCount; i++) {
            _mem.writeU16(
              outPtr + _layout.deviceAttrsFeatures + i * 2,
              result.primary.features[i],
            );
          }
          _mem.writeU32(outPtr + _layout.deviceAttrsNumFeatures, featureCount);
          _mem.writeU16(
            outPtr + _layout.deviceAttrsDeviceType,
            result.secondary.deviceType,
          );
          _mem.writeU16(
            outPtr + _layout.deviceAttrsFirmwareVersion,
            result.secondary.firmwareVersion,
          );
          _mem.writeU16(
            outPtr + _layout.deviceAttrsRomCartridge,
            result.secondary.romCartridge,
          );
          _mem.writeU32(
            outPtr + _layout.deviceAttrsUnitId,
            result.tertiary.unitId,
          );
          return 1;
        } on Object catch (_) {
          return 0;
        }
      }).toJS,
      ['i32', 'i32', 'i32'],
      results: ['i32'],
      reuseIndex: reuseIndex,
    );
    map[option] = (index, callback);
    _exports.ghostty_terminal_set(handle, option.value, index);
  }

  @override
  void terminalDisposeCallbacks(int handle) {
    final map = _callbacks.remove(handle);
    if (map case Map(:final keys, :final values)) {
      for (final option in keys) {
        _exports.ghostty_terminal_set(handle, option.value, 0);
      }
      for (final (index, _) in values) {
        _table.set(index);
      }
    }
    final bufs = _stringBufs.remove(handle);
    if (bufs case Map(:final values)) {
      for (final (ptr, len) in values) {
        _exports.ghostty_wasm_free_u8_array(ptr, len);
      }
    }
  }

  void _freeStringBuf(int handle, TerminalOption option) {
    final bufs = _stringBufs[handle];
    if (bufs == null) return;
    final buf = bufs.remove(option);
    if (buf != null) _exports.ghostty_wasm_free_u8_array(buf.$1, buf.$2);
  }

  @override
  CResult<int> renderStateNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = _exports.ghostty_render_state_new(0, outPtr);
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (.fromValue(result), handle);
  }

  @override
  void renderStateFree(int handle) {
    _exports.ghostty_render_state_free(handle);
  }

  @override
  Result renderStateUpdate(int state, int terminal) {
    return .fromValue(_exports.ghostty_render_state_update(state, terminal));
  }

  @override
  CResult<int> renderStateGetCols(int state) {
    return _renderStateGetU16(state, .cols);
  }

  @override
  CResult<int> renderStateGetRows(int state) {
    return _renderStateGetU16(state, .rows);
  }

  @override
  CResult<RenderStateDirty> renderStateGetDirty(int state) {
    final raw = _renderStateGetI32(state, .dirty);
    return (raw.$1, RenderStateDirty.fromValue(raw.$2));
  }

  @override
  Result renderStateSetDirty(int state, RenderStateDirty dirty) {
    final valPtr = _exports.ghostty_wasm_alloc_usize();
    _mem.writeI32(valPtr, dirty.value);
    final result = _exports.ghostty_render_state_set(
      state,
      RenderStateOption.dirty.value,
      valPtr,
    );
    _exports.ghostty_wasm_free_usize(valPtr);
    return Result.fromValue(result);
  }

  @override
  CResult<TerminalColors> renderStateGetColors(int state) {
    final colorsPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.colorsSize);
    _mem.writeU32(colorsPtr, _layout.colorsSize);
    final result = Result.fromValue(
      _exports.ghostty_render_state_colors_get(state, colorsPtr),
    );

    RgbColor rgbAt(int offset) => RgbColor(
      _mem.readU8(colorsPtr + offset),
      _mem.readU8(colorsPtr + offset + 1),
      _mem.readU8(colorsPtr + offset + 2),
    );

    final bg = rgbAt(_layout.colorsBg);
    final fg = rgbAt(_layout.colorsFg);
    final cursorHasValue =
        _mem.readU8(colorsPtr + _layout.colorsCursorHasValue) != 0;
    final cursor = cursorHasValue ? rgbAt(_layout.colorsCursor) : null;

    final palette = <RgbColor>[
      for (var i = 0; i < 256; i++)
        rgbAt(_layout.colorsPalette + i * _layout.colorRgbSize),
    ];

    _exports.ghostty_wasm_free_u8_array(colorsPtr, _layout.colorsSize);
    return (
      result,
      TerminalColors(
        foreground: fg,
        background: bg,
        cursor: cursor,
        palette: palette,
      ),
    );
  }

  @override
  CResult<RenderStateCursorVisualStyle> renderStateGetCursorVisualStyle(
    int state,
  ) {
    final raw = _renderStateGetI32(state, .cursorVisualStyle);
    return (raw.$1, RenderStateCursorVisualStyle.fromValue(raw.$2));
  }

  @override
  CResult<bool> renderStateGetCursorVisible(int state) {
    return _renderStateGetBool(state, .cursorVisible);
  }

  @override
  CResult<bool> renderStateGetCursorBlinking(int state) {
    return _renderStateGetBool(state, .cursorBlinking);
  }

  @override
  CResult<bool> renderStateGetCursorPasswordInput(int state) {
    return _renderStateGetBool(state, .cursorPasswordInput);
  }

  @override
  CResult<bool> renderStateGetCursorInViewport(int state) {
    return _renderStateGetBool(state, .cursorViewportHasValue);
  }

  @override
  CResult<int> renderStateGetCursorViewportX(int state) {
    return _renderStateGetU16(state, .cursorViewportX);
  }

  @override
  CResult<int> renderStateGetCursorViewportY(int state) {
    return _renderStateGetU16(state, .cursorViewportY);
  }

  @override
  CResult<bool> renderStateGetCursorViewportWideTail(int state) {
    return _renderStateGetBool(state, .cursorViewportWideTail);
  }

  @override
  CResult<int> rowIteratorNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_iterator_new(0, outPtr),
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (result, handle);
  }

  @override
  void rowIteratorFree(int handle) {
    _exports.ghostty_render_state_row_iterator_free(handle);
  }

  @override
  Result rowIteratorInit(int iterator, int renderState) {
    final ptrPtr = _exports.ghostty_wasm_alloc_opaque();
    _mem.writeU32(ptrPtr, iterator);
    final result = _exports.ghostty_render_state_get(
      renderState,
      RenderStateData.rowIterator.value,
      ptrPtr,
    );
    _exports.ghostty_wasm_free_opaque(ptrPtr);
    return Result.fromValue(result);
  }

  @override
  bool rowIteratorNext(int iterator) {
    return _exports.ghostty_render_state_row_iterator_next(iterator) != 0;
  }

  @override
  CResult<bool> rowIteratorGetDirty(int iterator) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_get(
        iterator,
        RenderStateRowData.dirty.value,
        outPtr,
      ),
    );
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (result, value);
  }

  @override
  Result rowIteratorSetDirty(int iterator, {required bool dirty}) {
    final valPtr = _exports.ghostty_wasm_alloc_u8();
    _mem.writeU8(valPtr, dirty ? 1 : 0);
    final result = _exports.ghostty_render_state_row_set(
      iterator,
      RenderStateRowOption.dirty.value,
      valPtr,
    );
    _exports.ghostty_wasm_free_u8(valPtr);
    return Result.fromValue(result);
  }

  @override
  CResult<int> rowIteratorGetRawRow(int iterator) {
    const u64Size = 8;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u64Size);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_get(
        iterator,
        RenderStateRowData.raw.value,
        outPtr,
      ),
    );
    final value = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, u64Size);
    return (result, value);
  }

  @override
  CResult<int> rowCellsNew() {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_new(0, outPtr),
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    return (result, handle);
  }

  @override
  void rowCellsFree(int handle) {
    _exports.ghostty_render_state_row_cells_free(handle);
  }

  @override
  Result rowCellsInit(int cells, int iterator) {
    final ptrPtr = _exports.ghostty_wasm_alloc_opaque();
    _mem.writeU32(ptrPtr, cells);
    final result = _exports.ghostty_render_state_row_get(
      iterator,
      RenderStateRowData.cells.value,
      ptrPtr,
    );
    _exports.ghostty_wasm_free_opaque(ptrPtr);
    return Result.fromValue(result);
  }

  @override
  bool rowCellsNext(int cells) =>
      _exports.ghostty_render_state_row_cells_next(cells) != 0;

  @override
  Result rowCellsSelect(int cells, int x) {
    return Result.fromValue(
      _exports.ghostty_render_state_row_cells_select(cells, x),
    );
  }

  @override
  CResult<int> rowCellsGetRawCell(int cells) {
    const u64Size = 8;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u64Size);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.raw.value,
        outPtr,
      ),
    );
    final value = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, u64Size);
    return (result, value);
  }

  @override
  CResult<Style> rowCellsGetStyle(int cells) {
    final size = _layout.styleSize;
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(size);
    _mem.writeU32(stylePtr, size);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.style.value,
        stylePtr,
      ),
    );
    final value = _readStyle(stylePtr);
    _exports.ghostty_wasm_free_u8_array(stylePtr, size);
    return (result, value);
  }

  @override
  CResult<int> rowCellsGetGraphemeLen(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.graphemesLen.value,
        outPtr,
      ),
    );
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (result, value);
  }

  @override
  CResult<List<int>> rowCellsGetGraphemes(int cells, int len) {
    if (len <= 0) return (Result.success, const []);
    final bufSize = len * 4;
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.graphemesBuf.value,
        buf,
      ),
    );
    final value = [for (var i = 0; i < len; i++) _mem.readU32(buf + i * 4)];
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (result, value);
  }

  @override
  CResult<RgbColor> rowCellsGetBgColor(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.bgColor.value,
        outPtr,
      ),
    );
    final rgb = RgbColor(
      _mem.readU8(outPtr),
      _mem.readU8(outPtr + _layout.colorRgbG),
      _mem.readU8(outPtr + _layout.colorRgbB),
    );
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, rgb);
  }

  @override
  CResult<RgbColor> rowCellsGetFgColor(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.fgColor.value,
        outPtr,
      ),
    );
    final rgb = RgbColor(
      _mem.readU8(outPtr),
      _mem.readU8(outPtr + _layout.colorRgbG),
      _mem.readU8(outPtr + _layout.colorRgbB),
    );
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, rgb);
  }

  @override
  CResult<int> rowCellsGetBgColorArgb(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.bgColor.value,
        outPtr,
      ),
    );
    final argb =
        0xFF000000 |
        (_mem.readU8(outPtr) << 16) |
        (_mem.readU8(outPtr + _layout.colorRgbG) << 8) |
        _mem.readU8(outPtr + _layout.colorRgbB);
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, argb);
  }

  @override
  CResult<int> rowCellsGetFgColorArgb(int cells) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _exports.ghostty_render_state_row_cells_get(
        cells,
        RenderStateRowCellsData.fgColor.value,
        outPtr,
      ),
    );
    final argb =
        0xFF000000 |
        (_mem.readU8(outPtr) << 16) |
        (_mem.readU8(outPtr + _layout.colorRgbG) << 8) |
        _mem.readU8(outPtr + _layout.colorRgbB);
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, argb);
  }

  @override
  CResult<int> cellGetCodepoint(int cell) => _cellGetU32(cell, .codepoint);

  @override
  CResult<CellContentTag> cellGetContentTag(int cell) {
    final raw = _cellGetI32(cell, .contentTag);
    return (raw.$1, CellContentTag.fromValue(raw.$2));
  }

  @override
  CResult<CellWide> cellGetWide(int cell) {
    final raw = _cellGetI32(cell, .wide);
    return (raw.$1, CellWide.fromValue(raw.$2));
  }

  @override
  CResult<bool> cellGetHasText(int cell) => _cellGetBool(cell, .hasText);

  @override
  CResult<bool> cellGetHasStyling(int cell) => _cellGetBool(cell, .hasStyling);

  @override
  CResult<int> cellGetStyleId(int cell) => _cellGetU16(cell, .styleId);

  @override
  CResult<bool> cellGetHasHyperlink(int cell) =>
      _cellGetBool(cell, .hasHyperlink);

  @override
  CResult<bool> cellGetProtected(int cell) => _cellGetBool(cell, .protected);

  @override
  CResult<CellSemanticContent> cellGetSemanticContent(int cell) {
    final raw = _cellGetI32(cell, .semanticContent);
    return (raw.$1, CellSemanticContent.fromValue(raw.$2));
  }

  @override
  CResult<int> cellGetColorPalette(int cell) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = Result.fromValue(_callCellGet(cell, .colorPalette, outPtr));
    final value = _mem.readU8(outPtr);
    _exports.ghostty_wasm_free_u8(outPtr);
    return (result, value);
  }

  @override
  CResult<RgbColor> cellGetColorRgb(int cell) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(3);
    final result = Result.fromValue(
      _callCellGet(cell, CellData.colorRgb, outPtr),
    );
    final rgb = RgbColor(
      _mem.readU8(outPtr),
      _mem.readU8(outPtr + _layout.colorRgbG),
      _mem.readU8(outPtr + _layout.colorRgbB),
    );
    _exports.ghostty_wasm_free_u8_array(outPtr, 3);
    return (result, rgb);
  }

  @override
  CResult<bool> rowGetWrap(int row) => _rowGetBool(row, .wrap);

  @override
  CResult<bool> rowGetWrapContinuation(int row) =>
      _rowGetBool(row, .wrapContinuation);

  @override
  CResult<bool> rowGetGrapheme(int row) => _rowGetBool(row, .grapheme);

  @override
  CResult<bool> rowGetStyled(int row) => _rowGetBool(row, .styled);

  @override
  CResult<bool> rowGetHyperlink(int row) => _rowGetBool(row, .hyperlink);

  @override
  CResult<RowSemanticPrompt> rowGetSemanticPrompt(int row) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _callRowGet(row, .semanticPrompt, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), .fromValue(value));
  }

  @override
  CResult<bool> rowGetKittyVirtualPlaceholder(int row) {
    return _rowGetBool(row, .kittyVirtualPlaceholder);
  }

  @override
  CResult<bool> rowGetDirty(int row) => _rowGetBool(row, .dirty);

  @override
  CResult<String> focusEncode(FocusEvent event) {
    final outLen = _exports.ghostty_wasm_alloc_usize();
    const bufSize = 8;
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    final result = _exports.ghostty_focus_encode(
      event.value,
      buf,
      bufSize,
      outLen,
    );
    final len = _mem.readU32(outLen);
    final value = (len == 0) ? '' : utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (.fromValue(result), value);
  }

  @override
  CResult<int> buildInfo(BuildInfo data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_build_info(data.value, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  @override
  CResult<bool> buildInfoBool(BuildInfo data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_build_info(data.value, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  @override
  CResult<String> buildInfoString(BuildInfo data) {
    final strSize = _layout.stringSize;
    final strPtr = _exports.ghostty_wasm_alloc_u8_array(strSize);
    final result = _exports.ghostty_build_info(data.value, strPtr);
    final ptr = _mem.readU32(strPtr);
    final len = _mem.readU32(strPtr + _layout.stringLen);
    _exports.ghostty_wasm_free_u8_array(strPtr, strSize);
    if (len == 0 || ptr == 0) return (.fromValue(result), '');
    return (.fromValue(result), utf8.decode(_mem.readBytes(ptr, len)));
  }

  @override
  CResult<String> modeReportEncode(int mode, ModeReportState state) {
    final outLen = _exports.ghostty_wasm_alloc_usize();
    const bufSize = 64;
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    final result = _exports.ghostty_mode_report_encode(
      mode,
      state.value,
      buf,
      bufSize,
      outLen,
    );
    final len = _mem.readU32(outLen);
    final value = (len == 0) ? '' : utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (.fromValue(result), value);
  }

  @override
  CResult<String> sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  ) {
    final sizeStructSize = _layout.sizeReportSize;
    final sizePtr = _exports.ghostty_wasm_alloc_u8_array(sizeStructSize);
    final outLen = _exports.ghostty_wasm_alloc_usize();
    const bufSize = 64;
    final buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    _mem.writeU16(sizePtr, rows);
    _mem.writeU16(sizePtr + _layout.sizeReportColumns, columns);
    _mem.writeU32(sizePtr + _layout.sizeReportCellWidth, cellWidth);
    _mem.writeU32(sizePtr + _layout.sizeReportCellHeight, cellHeight);
    final result = _exports.ghostty_size_report_encode(
      style.value,
      sizePtr,
      buf,
      bufSize,
      outLen,
    );
    final len = _mem.readU32(outLen);
    final value = (len == 0) ? '' : utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_u8_array(sizePtr, sizeStructSize);
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (.fromValue(result), value);
  }

  @override
  Style styleDefault() {
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(_layout.styleSize);
    _mem.writeU32(stylePtr, _layout.styleSize);
    _exports.ghostty_style_default(stylePtr);
    final value = _readStyle(stylePtr);
    _exports.ghostty_wasm_free_u8_array(stylePtr, _layout.styleSize);
    return value;
  }

  @override
  bool styleIsDefault(Style style) {
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(_layout.styleSize);
    _mem.writeU32(stylePtr, _layout.styleSize);
    _writeStyle(stylePtr, style);
    final value = _exports.ghostty_style_is_default(stylePtr) != 0;
    _exports.ghostty_wasm_free_u8_array(stylePtr, _layout.styleSize);
    return value;
  }

  @override
  CResult<int> terminalGridRef(int terminal, PointTag pointTag, int x, int y) {
    final pointPtr = _exports.ghostty_wasm_alloc_u8_array(_layout.pointSize);
    final gridRefPtr = _exports.ghostty_wasm_alloc_u8_array(
      _layout.gridRefSize,
    );
    _mem.writeU32(pointPtr, pointTag.value);
    _mem.writeU16(pointPtr + _layout.pointX, x);
    _mem.writeU32(pointPtr + _layout.pointY, y);
    _mem.writeU32(gridRefPtr, _layout.gridRefSize);
    final result = _exports.ghostty_terminal_grid_ref(
      terminal,
      pointPtr,
      gridRefPtr,
    );
    _exports.ghostty_wasm_free_u8_array(pointPtr, _layout.pointSize);
    return (.fromValue(result), gridRefPtr);
  }

  @override
  void gridRefFree(int ref) {
    _exports.ghostty_wasm_free_u8_array(ref, _layout.gridRefSize);
  }

  @override
  CResult<int> gridRefCell(int ref) {
    const u64Size = 8;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u64Size);
    final result = _exports.ghostty_grid_ref_cell(ref, outPtr);
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, u64Size);
    return (.fromValue(result), value);
  }

  @override
  CResult<int> gridRefRow(int ref) {
    const u64Size = 8;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(u64Size);
    final result = _exports.ghostty_grid_ref_row(ref, outPtr);
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, u64Size);
    return (.fromValue(result), value);
  }

  @override
  CResult<Style> gridRefStyle(int ref) {
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(_layout.styleSize);
    _mem.writeU32(stylePtr, _layout.styleSize);
    final result = _exports.ghostty_grid_ref_style(ref, stylePtr);
    final value = _readStyle(stylePtr);
    _exports.ghostty_wasm_free_u8_array(stylePtr, _layout.styleSize);
    return (.fromValue(result), value);
  }

  @override
  CResult<List<int>> gridRefGraphemes(int ref) {
    const bufCount = 32;
    const bufSize = bufCount * 4;
    final outLen = _exports.ghostty_wasm_alloc_usize();
    var buf = _exports.ghostty_wasm_alloc_u8_array(bufSize);
    var result = Result.fromValue(
      _exports.ghostty_grid_ref_graphemes(ref, buf, bufCount, outLen),
    );
    var len = _mem.readU32(outLen);

    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(buf, bufSize);
      final bigSize = len * 4;
      buf = _exports.ghostty_wasm_alloc_u8_array(bigSize);
      result = Result.fromValue(
        _exports.ghostty_grid_ref_graphemes(ref, buf, len, outLen),
      );
      len = _mem.readU32(outLen);
      final value = [for (var i = 0; i < len; i++) _mem.readU32(buf + i * 4)];
      _exports.ghostty_wasm_free_usize(outLen);
      _exports.ghostty_wasm_free_u8_array(buf, bigSize);
      return (result, value);
    }

    final value = switch (len == 0) {
      true => const <int>[],
      false => [for (var i = 0; i < len; i++) _mem.readU32(buf + i * 4)],
    };
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, bufSize);
    return (result, value);
  }

  @override
  CResult<String> gridRefHyperlinkUri(int ref) {
    const initSize = 256;
    final outLen = _exports.ghostty_wasm_alloc_usize();
    var buf = _exports.ghostty_wasm_alloc_u8_array(initSize);
    var result = Result.fromValue(
      _exports.ghostty_grid_ref_hyperlink_uri(ref, buf, initSize, outLen),
    );
    var len = _mem.readU32(outLen);

    if (result == .outOfSpace) {
      _exports.ghostty_wasm_free_u8_array(buf, initSize);
      buf = _exports.ghostty_wasm_alloc_u8_array(len);
      result = Result.fromValue(
        _exports.ghostty_grid_ref_hyperlink_uri(ref, buf, len, outLen),
      );
      len = _mem.readU32(outLen);
      final value = len == 0 ? '' : utf8.decode(_mem.readBytes(buf, len));
      _exports.ghostty_wasm_free_usize(outLen);
      _exports.ghostty_wasm_free_u8_array(buf, len);
      return (result, value);
    }

    final value = len == 0 ? '' : utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_wasm_free_usize(outLen);
    _exports.ghostty_wasm_free_u8_array(buf, initSize);
    return (result, value);
  }

  @override
  CResult<({int col, int row})> terminalPointFromGridRef(
    int terminal,
    int ref,
    PointTag pointTag,
  ) {
    final size = _layout.pointCoordinateSize;
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(size);
    final result = Result.fromValue(
      _exports.ghostty_terminal_point_from_grid_ref(
        terminal,
        ref,
        pointTag.value,
        outPtr,
      ),
    );
    final col = _mem.readU16(outPtr + _layout.pointCoordinateX);
    final row = _mem.readU32(outPtr + _layout.pointCoordinateY);
    _exports.ghostty_wasm_free_u8_array(outPtr, size);
    return (result, (col: col, row: row));
  }

  @override
  CResult<int> formatterTerminalNew(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
  }) {
    final optsSize = _layout.formatterOptsSize;
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final optsPtr = _exports.ghostty_wasm_alloc_u8_array(optsSize);

    // Zero the entire struct first, then populate fields.
    for (var i = 0; i < optsSize; i++) {
      _mem.writeU8(optsPtr + i, 0);
    }

    _mem.writeU32(optsPtr, optsSize);
    _mem.writeU32(optsPtr + _layout.formatterOptsFormat, format.value);
    _mem.writeU8(optsPtr + _layout.formatterOptsUnwrap, unwrap ? 1 : 0);
    _mem.writeU8(optsPtr + _layout.formatterOptsTrim, trim ? 1 : 0);

    final extraBase = optsPtr + _layout.formatterOptsExtra;
    _mem.writeU32(extraBase, _layout.formatterTermExtraSize);
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraPalette,
      extra.palette ? 1 : 0,
    );
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraModes,
      extra.modes ? 1 : 0,
    );
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraScrollingRegion,
      extra.scrollingRegion ? 1 : 0,
    );
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraTabstops,
      extra.tabstops ? 1 : 0,
    );
    _mem.writeU8(extraBase + _layout.formatterTermExtraPwd, extra.pwd ? 1 : 0);
    _mem.writeU8(
      extraBase + _layout.formatterTermExtraKeyboard,
      extra.keyboard ? 1 : 0,
    );

    final screenBase = extraBase + _layout.formatterTermExtraScreen;
    _mem.writeU32(screenBase, _layout.formatterScreenExtraSize);
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraCursor,
      extra.cursor ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraStyle,
      extra.style ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraHyperlink,
      extra.hyperlink ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraProtection,
      extra.protection ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraKittyKeyboard,
      extra.kittyKeyboard ? 1 : 0,
    );
    _mem.writeU8(
      screenBase + _layout.formatterScreenExtraCharsets,
      extra.charsets ? 1 : 0,
    );

    final result = _exports.ghostty_formatter_terminal_new(
      0,
      outPtr,
      terminal,
      optsPtr,
    );
    final handle = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    _exports.ghostty_wasm_free_u8_array(optsPtr, optsSize);
    return (.fromValue(result), handle);
  }

  @override
  void formatterFree(int formatter) {
    _exports.ghostty_formatter_free(formatter);
  }

  @override
  CResult<String> formatterFormat(int formatter) {
    final outPtr = _exports.ghostty_wasm_alloc_opaque();
    final outLen = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_formatter_format_alloc(
      formatter,
      0,
      outPtr,
      outLen,
    );
    final len = _mem.readU32(outLen);
    final buf = _mem.readPtr(outPtr);
    _exports.ghostty_wasm_free_opaque(outPtr);
    _exports.ghostty_wasm_free_usize(outLen);
    if (len == 0 || buf == 0) return (.fromValue(result), '');
    final encoded = utf8.decode(_mem.readBytes(buf, len));
    _exports.ghostty_free(0, buf, len);
    return (.fromValue(result), encoded);
  }

  CResult<int> _terminalGetU16(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = Result.fromValue(
      _exports.ghostty_terminal_get(handle, data.value, outPtr),
    );
    final value = _mem.readU16(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (result, value);
  }

  CResult<bool> _terminalGetBool(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_terminal_get(handle, data.value, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _terminalGetU32(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_terminal_get(handle, data.value, outPtr);
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _terminalGetU64(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8_array(8);
    final result = _exports.ghostty_terminal_get(handle, data.value, outPtr);
    final value = _mem.readU64(outPtr);
    _exports.ghostty_wasm_free_u8_array(outPtr, 8);
    return (.fromValue(result), value);
  }

  CResult<Style> _terminalGetStyle(int handle, TerminalData data) {
    final stylePtr = _exports.ghostty_wasm_alloc_u8_array(_layout.styleSize);
    _mem.writeU32(stylePtr, _layout.styleSize);
    final result = _exports.ghostty_terminal_get(handle, data.value, stylePtr);
    final value = _readStyle(stylePtr);
    _exports.ghostty_wasm_free_u8_array(stylePtr, _layout.styleSize);
    return (.fromValue(result), value);
  }

  Result _terminalSetBool(int handle, TerminalOption option, bool? value) {
    if (value == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final ptr = _exports.ghostty_wasm_alloc_u8();
    _mem.writeU8(ptr, value ? 1 : 0);
    final result = _exports.ghostty_terminal_set(handle, option.value, ptr);
    _exports.ghostty_wasm_free_u8(ptr);
    return .fromValue(result);
  }

  Result _terminalSetU64(int handle, TerminalOption option, int? value) {
    if (value == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final ptr = _exports.ghostty_wasm_alloc_u8_array(8);
    _mem.writeU32(ptr, value & 0xFFFFFFFF);
    _mem.writeU32(ptr + 4, value >> 32);
    final result = _exports.ghostty_terminal_set(handle, option.value, ptr);
    _exports.ghostty_wasm_free_u8_array(ptr, 8);
    return .fromValue(result);
  }

  CResult<String> _terminalGetString(int handle, TerminalData data) {
    final strSize = _layout.stringSize;
    final strPtr = _exports.ghostty_wasm_alloc_u8_array(strSize);
    final result = _exports.ghostty_terminal_get(handle, data.value, strPtr);
    final ptr = _mem.readU32(strPtr);
    final len = _mem.readU32(strPtr + _layout.stringLen);
    _exports.ghostty_wasm_free_u8_array(strPtr, strSize);
    if (len == 0 || ptr == 0) return (.fromValue(result), '');
    return (.fromValue(result), utf8.decode(_mem.readBytes(ptr, len)));
  }

  Result _terminalSetString(int handle, TerminalOption option, String? value) {
    if (value == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final encoded = utf8.encode(value);
    final strSize = _layout.stringSize;
    final strPtr = _exports.ghostty_wasm_alloc_u8_array(strSize);
    final bytesPtr = _exports.ghostty_wasm_alloc_u8_array(encoded.length);
    _mem.writeBytes(bytesPtr, encoded);
    _mem.writeU32(strPtr, bytesPtr);
    _mem.writeU32(strPtr + _layout.stringLen, encoded.length);
    final result = _exports.ghostty_terminal_set(handle, option.value, strPtr);
    _exports.ghostty_wasm_free_u8_array(bytesPtr, encoded.length);
    _exports.ghostty_wasm_free_u8_array(strPtr, strSize);
    return .fromValue(result);
  }

  CResult<RgbColor> _terminalGetColor(int handle, TerminalData data) {
    final rgbSize = _layout.colorRgbSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(rgbSize);
    final result = _exports.ghostty_terminal_get(handle, data.value, ptr);
    final rgb = RgbColor(
      _mem.readU8(ptr),
      _mem.readU8(ptr + _layout.colorRgbG),
      _mem.readU8(ptr + _layout.colorRgbB),
    );
    _exports.ghostty_wasm_free_u8_array(ptr, rgbSize);
    return (.fromValue(result), rgb);
  }

  CResult<List<RgbColor>> _terminalGetPalette(int handle, TerminalData data) {
    final paletteSize = 256 * _layout.colorRgbSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(paletteSize);
    final result = Result.fromValue(
      _exports.ghostty_terminal_get(handle, data.value, ptr),
    );

    if (result != .success) {
      _exports.ghostty_wasm_free_u8_array(ptr, paletteSize);
      return (result, const []);
    }

    final palette = <RgbColor>[
      for (var i = 0; i < 256; i++)
        RgbColor(
          _mem.readU8(ptr + i * _layout.colorRgbSize),
          _mem.readU8(ptr + i * _layout.colorRgbSize + _layout.colorRgbG),
          _mem.readU8(ptr + i * _layout.colorRgbSize + _layout.colorRgbB),
        ),
    ];
    _exports.ghostty_wasm_free_u8_array(ptr, paletteSize);
    return (result, palette);
  }

  Result _terminalSetColor(int handle, TerminalOption option, RgbColor? color) {
    if (color == null) {
      return .fromValue(_exports.ghostty_terminal_set(handle, option.value, 0));
    }
    final rgbSize = _layout.colorRgbSize;
    final ptr = _exports.ghostty_wasm_alloc_u8_array(rgbSize);
    _mem.writeU8(ptr, color.r);
    _mem.writeU8(ptr + _layout.colorRgbG, color.g);
    _mem.writeU8(ptr + _layout.colorRgbB, color.b);
    final result = _exports.ghostty_terminal_set(handle, option.value, ptr);
    _exports.ghostty_wasm_free_u8_array(ptr, rgbSize);
    return .fromValue(result);
  }

  CResult<int> _terminalGetI32(int handle, TerminalData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_terminal_get(handle, data.value, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _renderStateGetU16(int state, RenderStateData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_render_state_get(state, data.value, outPtr);
    final value = _mem.readU16(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<bool> _renderStateGetBool(int state, RenderStateData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _exports.ghostty_render_state_get(state, data.value, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _renderStateGetI32(int state, RenderStateData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _exports.ghostty_render_state_get(state, data.value, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _cellGetU16(int cell, CellData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _callCellGet(cell, data, outPtr);
    final value = _mem.readU16(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _cellGetU32(int cell, CellData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _callCellGet(cell, data, outPtr);
    final value = _mem.readU32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<int> _cellGetI32(int cell, CellData data) {
    final outPtr = _exports.ghostty_wasm_alloc_usize();
    final result = _callCellGet(cell, data, outPtr);
    final value = _mem.readI32(outPtr);
    _exports.ghostty_wasm_free_usize(outPtr);
    return (.fromValue(result), value);
  }

  CResult<bool> _cellGetBool(int cell, CellData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _callCellGet(cell, data, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  CResult<bool> _rowGetBool(int row, RowData data) {
    final outPtr = _exports.ghostty_wasm_alloc_u8();
    final result = _callRowGet(row, data, outPtr);
    final value = _mem.readU8(outPtr) != 0;
    _exports.ghostty_wasm_free_u8(outPtr);
    return (.fromValue(result), value);
  }

  int _callCellGet(int cell, CellData data, int outPtr) {
    final fn = (_exports as JSObject)['ghostty_cell_get']! as JSFunction;
    return (fn.callAsFunction(
              null,
              _toBigInt(cell),
              data.value.toJS,
              outPtr.toJS,
            )!
            as JSNumber)
        .toDartInt;
  }

  int _callRowGet(int row, RowData data, int outPtr) {
    final fn = (_exports as JSObject)['ghostty_row_get']! as JSFunction;
    return (fn.callAsFunction(
              null,
              _toBigInt(row),
              data.value.toJS,
              outPtr.toJS,
            )!
            as JSNumber)
        .toDartInt;
  }

  Style _readStyle(int stylePtr) {
    final ulRaw = _readRawColor(stylePtr + _layout.styleUnderlineColor);
    return Style(
      foreground: cellColorFromRaw(_readRawColor(stylePtr + _layout.styleFg)),
      background: cellColorFromRaw(_readRawColor(stylePtr + _layout.styleBg)),
      underlineColor: switch (ulRaw.tag) {
        .rgb || .palette => cellColorFromRaw(ulRaw),
        .none => null,
      },
      bold: _mem.readU8(stylePtr + _layout.styleBold) != 0,
      italic: _mem.readU8(stylePtr + _layout.styleItalic) != 0,
      faint: _mem.readU8(stylePtr + _layout.styleFaint) != 0,
      blink: _mem.readU8(stylePtr + _layout.styleBlink) != 0,
      inverse: _mem.readU8(stylePtr + _layout.styleInverse) != 0,
      invisible: _mem.readU8(stylePtr + _layout.styleInvisible) != 0,
      strikethrough: _mem.readU8(stylePtr + _layout.styleStrikethrough) != 0,
      overline: _mem.readU8(stylePtr + _layout.styleOverline) != 0,
      underline: .fromValue(_mem.readI32(stylePtr + _layout.styleUnderline)),
    );
  }

  RawColor _readRawColor(int addr) {
    return (
      tag: StyleColorTag.fromValue(_mem.readU32(addr)),
      palette: _mem.readU8(addr + _layout.styleColorR),
      r: _mem.readU8(addr + _layout.styleColorR),
      g: _mem.readU8(addr + _layout.styleColorG),
      b: _mem.readU8(addr + _layout.styleColorB),
    );
  }

  void _writeStyle(int stylePtr, Style style) {
    _writeStyleColor(stylePtr + _layout.styleFg, style.foreground);
    _writeStyleColor(stylePtr + _layout.styleBg, style.background);
    _writeStyleColor(
      stylePtr + _layout.styleUnderlineColor,
      style.underlineColor,
    );
    _mem.writeU8(stylePtr + _layout.styleBold, style.bold ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleItalic, style.italic ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleFaint, style.faint ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleBlink, style.blink ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleInverse, style.inverse ? 1 : 0);
    _mem.writeU8(stylePtr + _layout.styleInvisible, style.invisible ? 1 : 0);
    _mem.writeU8(
      stylePtr + _layout.styleStrikethrough,
      style.strikethrough ? 1 : 0,
    );
    _mem.writeU8(stylePtr + _layout.styleOverline, style.overline ? 1 : 0);
    _mem.writeI32(stylePtr + _layout.styleUnderline, style.underline.value);
  }

  void _writeStyleColor(int addr, CellColor? color) {
    switch (color) {
      case RgbColor(:final r, :final g, :final b):
        _mem.writeU32(addr, StyleColorTag.rgb.value);
        _mem.writeU8(addr + _layout.styleColorR, r);
        _mem.writeU8(addr + _layout.styleColorG, g);
        _mem.writeU8(addr + _layout.styleColorB, b);
      case PaletteColor(:final index):
        _mem.writeU32(addr, StyleColorTag.palette.value);
        _mem.writeU8(addr + _layout.styleColorR, index);
        _mem.writeU8(addr + _layout.styleColorG, 0);
        _mem.writeU8(addr + _layout.styleColorB, 0);
      case DefaultColor() || null:
        _mem.writeU32(addr, StyleColorTag.none.value);
        _mem.writeU8(addr + _layout.styleColorR, 0);
        _mem.writeU8(addr + _layout.styleColorG, 0);
        _mem.writeU8(addr + _layout.styleColorB, 0);
    }
  }

  SgrAttribute _readSgrAttribute(int attrPtr) {
    final tag = _exports.ghostty_sgr_attribute_tag(attrPtr);
    final valuePtr = _exports.ghostty_sgr_attribute_value(attrPtr);
    final tagEnum = SgrAttributeTag.fromValue(tag);
    return switch (tagEnum) {
      .unknown => _readSgrUnknown(valuePtr),
      .underline => SgrAttribute(
        underlineStyle: .fromValue(_mem.readI32(valuePtr)),
        tag: tagEnum,
      ),
      .underlineColor ||
      .directColorFg ||
      .directColorBg => _readSgrRgb(tagEnum, valuePtr),
      .underlineColor256 ||
      .fg8 ||
      .bg8 ||
      .brightFg8 ||
      .brightBg8 ||
      .fg256 ||
      .bg256 => SgrAttribute(tag: tagEnum, paletteIndex: _mem.readU8(valuePtr)),
      _ => SgrAttribute(tag: tagEnum),
    };
  }

  SgrAttribute _readSgrRgb(SgrAttributeTag tag, int valuePtr) {
    final rPtr = _exports.ghostty_wasm_alloc_u8();
    final gPtr = _exports.ghostty_wasm_alloc_u8();
    final bPtr = _exports.ghostty_wasm_alloc_u8();
    _exports.ghostty_color_rgb_get(valuePtr, rPtr, gPtr, bPtr);
    final result = SgrAttribute(
      tag: tag,
      color: RgbColor(_mem.readU8(rPtr), _mem.readU8(gPtr), _mem.readU8(bPtr)),
    );
    _exports.ghostty_wasm_free_u8(rPtr);
    _exports.ghostty_wasm_free_u8(gPtr);
    _exports.ghostty_wasm_free_u8(bPtr);
    return result;
  }

  static final _jsBigInt = globalContext['BigInt']! as JSFunction;

  static JSAny _toBigInt(int value) {
    return _jsBigInt.callAsFunction(null, value.toJS)!;
  }

  SgrAttribute _readSgrUnknown(int valuePtr) {
    final fullOutPtr = _exports.ghostty_wasm_alloc_opaque();
    final partialOutPtr = _exports.ghostty_wasm_alloc_opaque();
    final fullLen = _exports.ghostty_sgr_unknown_full(valuePtr, fullOutPtr);
    final partialLen = _exports.ghostty_sgr_unknown_partial(
      valuePtr,
      partialOutPtr,
    );

    final fullPtrAddr = _mem.readPtr(fullOutPtr);
    final partialPtrAddr = _mem.readPtr(partialOutPtr);

    final full = <int>[];
    for (var i = 0; i < fullLen; i++) {
      full.add(_mem.readU16(fullPtrAddr + i * 2));
    }

    final partial = <int>[];
    for (var i = 0; i < partialLen; i++) {
      partial.add(_mem.readU16(partialPtrAddr + i * 2));
    }

    _exports.ghostty_wasm_free_opaque(fullOutPtr);
    _exports.ghostty_wasm_free_opaque(partialOutPtr);
    return SgrAttribute(
      tag: .unknown,
      unknownFull: full,
      unknownPartial: partial,
    );
  }
}
