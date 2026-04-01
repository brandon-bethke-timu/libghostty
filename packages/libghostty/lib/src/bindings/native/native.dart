import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../ffi/libghostty.g.dart' as native;
import '../../ffi/libghostty_enums.g.dart' as native;
import '../../ffi/libghostty_enums.g.dart';
import '../interface.dart';

typedef _StringBuffer = ({
  ffi.Pointer<native.String> str,
  ffi.Pointer<ffi.Uint8> data,
});

final GhosttyBindings bindings = NativeBindings();

Future<void> initializeForWeb(Uri wasmUri) async {}

class NativeBindings implements GhosttyBindings {
  final _utf8Ptrs = <int, ffi.Pointer<ffi.Char>>{};
  final _callables = <int, Map<TerminalOption, ffi.NativeCallable>>{};
  final _stringBuffers = <int, Map<TerminalOption, _StringBuffer>>{};

  final _outU8 = calloc<ffi.Uint8>();
  final _outU16 = calloc<ffi.Uint16>();
  final _outU32 = calloc<ffi.Uint32>();
  final _outU64 = calloc<ffi.Uint64>();
  final _outI32 = calloc<ffi.Int32>();
  final _outBool = calloc<ffi.Bool>();
  final _outStyle = calloc<native.Style>();
  final _outScrollbar = calloc<native.TerminalScrollbar>();
  final _outColors = calloc<native.RenderStateColors>();
  final _outSize = calloc<ffi.Size>();
  final _outGhosttyString = calloc<native.String>();
  final _outColorRgb = calloc<native.ColorRgb>();
  final _graphemeBuf = calloc<ffi.Uint32>(32);

  NativeBindings() {
    _outColors.ref.size = ffi.sizeOf<native.RenderStateColors>();
    _outStyle.ref.size = ffi.sizeOf<native.Style>();
  }

  @override
  CResult<int> keyEventNew() {
    final ptr = calloc<ffi.Pointer<native.KeyEventImpl>>();
    final result = native.ghostty_key_event_new(ffi.nullptr, ptr);
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void keyEventFree(int handle) {
    _freeUtf8(handle);
    native.ghostty_key_event_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetAction(int handle, KeyAction action) {
    native.ghostty_key_event_set_action(
      ffi.Pointer.fromAddress(handle),
      action,
    );
  }

  @override
  KeyAction keyEventGetAction(int handle) {
    return native.ghostty_key_event_get_action(ffi.Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetKey(int handle, Key key) {
    native.ghostty_key_event_set_key(ffi.Pointer.fromAddress(handle), key);
  }

  @override
  Key keyEventGetKey(int handle) {
    return native.ghostty_key_event_get_key(ffi.Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetMods(int handle, int mods) {
    native.ghostty_key_event_set_mods(ffi.Pointer.fromAddress(handle), mods);
  }

  @override
  int keyEventGetMods(int handle) {
    return native.ghostty_key_event_get_mods(ffi.Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetConsumedMods(int handle, int mods) {
    native.ghostty_key_event_set_consumed_mods(
      ffi.Pointer.fromAddress(handle),
      mods,
    );
  }

  @override
  int keyEventGetConsumedMods(int handle) {
    return native.ghostty_key_event_get_consumed_mods(
      ffi.Pointer.fromAddress(handle),
    );
  }

  @override
  void keyEventSetComposing(int handle, {required bool composing}) {
    native.ghostty_key_event_set_composing(
      ffi.Pointer.fromAddress(handle),
      composing,
    );
  }

  @override
  bool keyEventGetComposing(int handle) {
    return native.ghostty_key_event_get_composing(
      ffi.Pointer.fromAddress(handle),
    );
  }

  @override
  void keyEventSetUtf8(int handle, String? text) {
    _freeUtf8(handle);
    final ptr = ffi.Pointer<native.KeyEventImpl>.fromAddress(handle);
    if (text == null) {
      native.ghostty_key_event_set_utf8(ptr, ffi.nullptr, 0);
      return;
    }
    final encoded = utf8.encode(text);
    final charPtr = calloc<ffi.Char>(encoded.length);
    charPtr.cast<ffi.Uint8>().asTypedList(encoded.length).setAll(0, encoded);
    _utf8Ptrs[handle] = charPtr;
    native.ghostty_key_event_set_utf8(ptr, charPtr, encoded.length);
  }

  @override
  String? keyEventGetUtf8(int handle) {
    final lenPtr = calloc<ffi.Size>();
    final charPtr = native.ghostty_key_event_get_utf8(
      ffi.Pointer.fromAddress(handle),
      lenPtr,
    );
    if (charPtr == ffi.nullptr) {
      calloc.free(lenPtr);
      return null;
    }
    final len = lenPtr.value;
    calloc.free(lenPtr);
    if (len == 0) return null;
    return utf8.decode(charPtr.cast<ffi.Uint8>().asTypedList(len));
  }

  @override
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint) {
    native.ghostty_key_event_set_unshifted_codepoint(
      ffi.Pointer.fromAddress(handle),
      codepoint,
    );
  }

  @override
  int keyEventGetUnshiftedCodepoint(int handle) {
    return native.ghostty_key_event_get_unshifted_codepoint(
      ffi.Pointer.fromAddress(handle),
    );
  }

  @override
  CResult<int> keyEncoderNew() {
    final ptr = calloc<ffi.Pointer<native.KeyEncoderImpl>>();
    final result = native.ghostty_key_encoder_new(ffi.nullptr, ptr);
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void keyEncoderFree(int handle) {
    native.ghostty_key_encoder_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  void keyEncoderSetBoolOpt(
    int handle,
    KeyEncoderOption option, {
    required bool value,
  }) {
    final ptr = calloc<ffi.Bool>();
    ptr.value = value;
    native.ghostty_key_encoder_setopt(
      ffi.Pointer.fromAddress(handle),
      option,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  @override
  void keyEncoderSetKittyFlags(int handle, int flags) {
    final ptr = calloc<ffi.Uint8>();
    ptr.value = flags;
    native.ghostty_key_encoder_setopt(
      ffi.Pointer.fromAddress(handle),
      native.KeyEncoderOption.kittyFlags,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  @override
  void keyEncoderSetOptionAsAlt(int handle, OptionAsAlt value) {
    final ptr = calloc<ffi.Int32>();
    ptr.value = value.value;
    native.ghostty_key_encoder_setopt(
      ffi.Pointer.fromAddress(handle),
      native.KeyEncoderOption.macosOptionAsAlt,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  @override
  void keyEncoderSetOptFromTerminal(int encoder, int terminal) {
    native.ghostty_key_encoder_setopt_from_terminal(
      ffi.Pointer.fromAddress(encoder),
      ffi.Pointer.fromAddress(terminal),
    );
  }

  @override
  CResult<String> keyEncoderEncode(int encoder, int event) {
    final outLen = calloc<ffi.Size>();
    var bufSize = 128;
    var buf = calloc<ffi.Char>(bufSize);
    var result = native.ghostty_key_encoder_encode(
      ffi.Pointer.fromAddress(encoder),
      ffi.Pointer.fromAddress(event),
      buf,
      bufSize,
      outLen,
    );

    // Retry with the required size if the initial buffer was too small.
    if (result == Result.outOfSpace) {
      calloc.free(buf);
      bufSize = outLen.value;
      buf = calloc<ffi.Char>(bufSize);
      result = native.ghostty_key_encoder_encode(
        ffi.Pointer.fromAddress(encoder),
        ffi.Pointer.fromAddress(event),
        buf,
        bufSize,
        outLen,
      );
    }

    final len = outLen.value;
    final encoded = utf8.decode(buf.cast<ffi.Uint8>().asTypedList(len));
    calloc.free(outLen);
    calloc.free(buf);
    return (result, encoded);
  }

  @override
  CResult<int> mouseEventNew() {
    final ptr = calloc<ffi.Pointer<native.MouseEventImpl>>();
    final result = native.ghostty_mouse_event_new(ffi.nullptr, ptr);
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void mouseEventFree(int handle) {
    native.ghostty_mouse_event_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  void mouseEventSetAction(int handle, MouseAction action) {
    native.ghostty_mouse_event_set_action(
      ffi.Pointer.fromAddress(handle),
      action,
    );
  }

  @override
  MouseAction mouseEventGetAction(int handle) {
    return native.ghostty_mouse_event_get_action(
      ffi.Pointer.fromAddress(handle),
    );
  }

  @override
  void mouseEventSetButton(int handle, MouseButton button) {
    native.ghostty_mouse_event_set_button(
      ffi.Pointer.fromAddress(handle),
      button,
    );
  }

  @override
  void mouseEventClearButton(int handle) {
    native.ghostty_mouse_event_clear_button(ffi.Pointer.fromAddress(handle));
  }

  @override
  CResult<MouseButton> mouseEventGetButton(int handle) {
    final out = calloc<ffi.Int32>();
    final hasButton = native.ghostty_mouse_event_get_button(
      ffi.Pointer.fromAddress(handle),
      out.cast(),
    );
    final result = hasButton ? Result.success : Result.noValue;
    final button = MouseButton.fromValue(out.value);
    calloc.free(out);
    return (result, button);
  }

  @override
  void mouseEventSetMods(int handle, int mods) {
    native.ghostty_mouse_event_set_mods(ffi.Pointer.fromAddress(handle), mods);
  }

  @override
  int mouseEventGetMods(int handle) {
    return native.ghostty_mouse_event_get_mods(ffi.Pointer.fromAddress(handle));
  }

  @override
  void mouseEventSetPosition(int handle, double x, double y) {
    final pos = calloc<native.MousePosition>();
    pos.ref.x = x;
    pos.ref.y = y;
    native.ghostty_mouse_event_set_position(
      ffi.Pointer.fromAddress(handle),
      pos.ref,
    );
    calloc.free(pos);
  }

  @override
  (double, double) mouseEventGetPosition(int handle) {
    final pos = native.ghostty_mouse_event_get_position(
      ffi.Pointer.fromAddress(handle),
    );
    return (pos.x, pos.y);
  }

  @override
  CResult<int> mouseEncoderNew() {
    final ptr = calloc<ffi.Pointer<native.MouseEncoderImpl>>();
    final result = native.ghostty_mouse_encoder_new(ffi.nullptr, ptr);
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void mouseEncoderFree(int handle) {
    native.ghostty_mouse_encoder_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  void mouseEncoderSetBoolOpt(
    int handle,
    MouseEncoderOption option, {
    required bool value,
  }) {
    final ptr = calloc<ffi.Bool>();
    ptr.value = value;
    native.ghostty_mouse_encoder_setopt(
      ffi.Pointer.fromAddress(handle),
      option,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  @override
  void mouseEncoderSetTrackingMode(int handle, MouseTrackingMode mode) {
    final ptr = calloc<ffi.Int32>();
    ptr.value = mode.value;
    native.ghostty_mouse_encoder_setopt(
      ffi.Pointer.fromAddress(handle),
      native.MouseEncoderOption.event,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  @override
  void mouseEncoderSetFormat(int handle, MouseFormat format) {
    final ptr = calloc<ffi.Int32>();
    ptr.value = format.value;
    native.ghostty_mouse_encoder_setopt(
      ffi.Pointer.fromAddress(handle),
      native.MouseEncoderOption.format,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  @override
  void mouseEncoderSetSize(int handle, MouseEncoderSize size) {
    final ptr = calloc<native.MouseEncoderSize>();
    ptr.ref
      ..size = ffi.sizeOf<native.MouseEncoderSize>()
      ..screen_width = size.screenWidth
      ..screen_height = size.screenHeight
      ..cell_width = size.cellWidth
      ..cell_height = size.cellHeight
      ..padding_top = size.paddingTop
      ..padding_bottom = size.paddingBottom
      ..padding_left = size.paddingLeft
      ..padding_right = size.paddingRight;
    native.ghostty_mouse_encoder_setopt(
      ffi.Pointer.fromAddress(handle),
      native.MouseEncoderOption.size,
      ptr.cast(),
    );
    calloc.free(ptr);
  }

  @override
  void mouseEncoderSetOptFromTerminal(int encoder, int terminal) {
    native.ghostty_mouse_encoder_setopt_from_terminal(
      ffi.Pointer.fromAddress(encoder),
      ffi.Pointer.fromAddress(terminal),
    );
  }

  @override
  void mouseEncoderReset(int handle) {
    native.ghostty_mouse_encoder_reset(ffi.Pointer.fromAddress(handle));
  }

  @override
  CResult<String> mouseEncoderEncode(int encoder, int event) {
    final outLen = calloc<ffi.Size>();
    var bufSize = 128;
    var buf = calloc<ffi.Char>(bufSize);
    var result = native.ghostty_mouse_encoder_encode(
      ffi.Pointer.fromAddress(encoder),
      ffi.Pointer.fromAddress(event),
      buf,
      bufSize,
      outLen,
    );

    // Retry with the required size if the initial buffer was too small.
    if (result == Result.outOfSpace) {
      calloc.free(buf);
      bufSize = outLen.value;
      buf = calloc<ffi.Char>(bufSize);
      result = native.ghostty_mouse_encoder_encode(
        ffi.Pointer.fromAddress(encoder),
        ffi.Pointer.fromAddress(event),
        buf,
        bufSize,
        outLen,
      );
    }

    final len = outLen.value;
    final encoded = utf8.decode(buf.cast<ffi.Uint8>().asTypedList(len));
    calloc.free(outLen);
    calloc.free(buf);
    return (result, encoded);
  }

  @override
  CResult<int> oscNew() {
    final ptr = calloc<ffi.Pointer<native.OscParserImpl>>();
    final result = native.ghostty_osc_new(ffi.nullptr, ptr);
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void oscFree(int handle) {
    native.ghostty_osc_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  void oscFeedByte(int handle, int byte) {
    native.ghostty_osc_next(ffi.Pointer.fromAddress(handle), byte);
  }

  @override
  int oscEnd(int handle, int terminator) {
    return native
        .ghostty_osc_end(ffi.Pointer.fromAddress(handle), terminator)
        .address;
  }

  @override
  OscCommandType oscCommandType(int command) {
    return native.ghostty_osc_command_type(
      native.OscCommand.fromAddress(command),
    );
  }

  @override
  String? oscCommandWindowTitle(int command) {
    return _extractWindowTitle(native.OscCommand.fromAddress(command));
  }

  @override
  void oscReset(int handle) {
    native.ghostty_osc_reset(ffi.Pointer.fromAddress(handle));
  }

  @override
  CResult<int> sgrNew() {
    final ptr = calloc<ffi.Pointer<native.SgrParserImpl>>();
    final result = native.ghostty_sgr_new(ffi.nullptr, ptr);
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void sgrFree(int handle) {
    native.ghostty_sgr_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  Result sgrSetParams(int handle, List<int> params, List<String>? separators) {
    final nativeParams = calloc<ffi.Uint16>(params.length);
    ffi.Pointer<ffi.Char> nativeSeps = ffi.nullptr;

    for (var i = 0; i < params.length; i++) {
      nativeParams[i] = params[i];
    }

    if (separators != null) {
      nativeSeps = calloc<ffi.Char>(separators.length);
      for (var i = 0; i < separators.length; i++) {
        (nativeSeps + i).value = separators[i].codeUnitAt(0);
      }
    }

    final result = native.ghostty_sgr_set_params(
      ffi.Pointer.fromAddress(handle),
      nativeParams,
      nativeSeps,
      params.length,
    );

    calloc.free(nativeParams);
    if (nativeSeps != ffi.nullptr) {
      calloc.free(nativeSeps);
    }
    return result;
  }

  @override
  SgrAttribute? sgrNext(int handle) {
    final attrPtr = calloc<native.SgrAttribute>();
    final hasNext = native.ghostty_sgr_next(
      ffi.Pointer.fromAddress(handle),
      attrPtr,
    );
    if (!hasNext) {
      calloc.free(attrPtr);
      return null;
    }
    final attr = _convertNativeSgrAttribute(attrPtr.ref);
    calloc.free(attrPtr);
    return attr;
  }

  @override
  void sgrReset(int handle) {
    native.ghostty_sgr_reset(ffi.Pointer.fromAddress(handle));
  }

  @override
  bool pasteIsSafe(String data) {
    final encoded = utf8.encode(data);
    final ptr = calloc<ffi.Char>(encoded.length);
    ptr.cast<ffi.Uint8>().asTypedList(encoded.length).setAll(0, encoded);
    final safe = native.ghostty_paste_is_safe(ptr, encoded.length);
    calloc.free(ptr);
    return safe;
  }

  @override
  CResult<int> terminalNew(int cols, int rows, int maxScrollback) {
    final ptr = calloc<ffi.Pointer<native.TerminalImpl>>();
    final opts = calloc<native.TerminalOptions>();
    opts.ref.cols = cols;
    opts.ref.rows = rows;
    opts.ref.max_scrollback = maxScrollback;
    final result = native.ghostty_terminal_new(ffi.nullptr, ptr, opts.ref);
    final address = ptr.value.address;
    calloc.free(opts);
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void terminalFree(int handle) {
    native.ghostty_terminal_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  void terminalVtWrite(int handle, Uint8List data) {
    if (data.isEmpty) return;
    final ptr = calloc<ffi.Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    native.ghostty_terminal_vt_write(
      ffi.Pointer.fromAddress(handle),
      ptr,
      data.length,
    );
    calloc.free(ptr);
  }

  @override
  Result terminalResize(
    int handle,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  ) {
    return native.ghostty_terminal_resize(
      ffi.Pointer.fromAddress(handle),
      cols,
      rows,
      cellWidthPx,
      cellHeightPx,
    );
  }

  @override
  void terminalReset(int handle) {
    native.ghostty_terminal_reset(ffi.Pointer.fromAddress(handle));
  }

  @override
  void terminalScrollViewport(
    int handle,
    TerminalScrollViewportTag tag,
    int delta,
  ) {
    final sv = calloc<native.TerminalScrollViewport>();
    sv.ref.tagAsInt = tag.value;
    sv.ref.value.delta = delta;
    native.ghostty_terminal_scroll_viewport(
      ffi.Pointer.fromAddress(handle),
      sv.ref,
    );
    calloc.free(sv);
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
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      .activeScreen,
      _outI32.cast(),
    );
    return (result, TerminalScreen.fromValue(_outI32.value));
  }

  @override
  CResult<int> terminalGetKittyKeyboardFlags(int handle) {
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      .kittyKeyboardFlags,
      _outU8.cast(),
    );
    return (result, _outU8.value);
  }

  @override
  CResult<Scrollbar> terminalGetScrollbar(int handle) {
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      .scrollbar,
      _outScrollbar.cast(),
    );
    return (
      result,
      Scrollbar(
        total: _outScrollbar.ref.total,
        offset: _outScrollbar.ref.offset,
        visible: _outScrollbar.ref.len,
      ),
    );
  }

  @override
  CResult<bool> terminalModeGet(int handle, int mode) {
    final result = native.ghostty_terminal_mode_get(
      ffi.Pointer.fromAddress(handle),
      mode,
      _outBool,
    );
    return (result, _outBool.value);
  }

  @override
  Result terminalModeSet(int handle, int mode, {required bool value}) {
    return native.ghostty_terminal_mode_set(
      ffi.Pointer.fromAddress(handle),
      mode,
      value,
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
    return _terminalGetSize(handle, .totalRows);
  }

  @override
  CResult<int> terminalGetScrollbackRows(int handle) {
    return _terminalGetSize(handle, .scrollbackRows);
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
    return _terminalSetString(handle, .title, title);
  }

  @override
  Result terminalSetPwd(int handle, String? pwd) {
    return _terminalSetString(handle, .pwd, pwd);
  }

  @override
  Result terminalSetColorForeground(int handle, RgbColor? color) {
    return _terminalSetColor(handle, .colorForeground, color);
  }

  @override
  Result terminalSetColorBackground(int handle, RgbColor? color) {
    return _terminalSetColor(handle, .colorBackground, color);
  }

  @override
  Result terminalSetColorCursor(int handle, RgbColor? color) {
    return _terminalSetColor(handle, .colorCursor, color);
  }

  @override
  Result terminalSetColorPalette(int handle, List<RgbColor>? palette) {
    if (palette == null) {
      return native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.colorPalette,
        ffi.nullptr,
      );
    }
    final ptr = calloc<native.ColorRgb>(256);
    for (var i = 0; i < 256; i++) {
      ptr[i].r = palette[i].r;
      ptr[i].g = palette[i].g;
      ptr[i].b = palette[i].b;
    }
    final result = native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.colorPalette,
      ptr.cast(),
    );
    calloc.free(ptr);
    return result;
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
  CResult<Uint8List> pasteEncode(String data, {required bool bracketed}) {
    final encoded = utf8.encode(data);
    final dataPtr = calloc<ffi.Char>(encoded.length);
    dataPtr.cast<ffi.Uint8>().asTypedList(encoded.length).setAll(0, encoded);
    final outWritten = calloc<ffi.Size>();

    // First call to get the required buffer size.
    var result = native.ghostty_paste_encode(
      dataPtr,
      encoded.length,
      bracketed,
      ffi.nullptr,
      0,
      outWritten,
    );

    if (result != .outOfSpace) {
      calloc.free(outWritten);
      calloc.free(dataPtr);
      return (result, Uint8List(0));
    }

    final bufLen = outWritten.value;
    final buf = calloc<ffi.Char>(bufLen);

    // Re-encode the data since the first call modified it in place.
    dataPtr.cast<ffi.Uint8>().asTypedList(encoded.length).setAll(0, encoded);

    result = native.ghostty_paste_encode(
      dataPtr,
      encoded.length,
      bracketed,
      buf,
      bufLen,
      outWritten,
    );

    final written = outWritten.value;
    final bytes = Uint8List.fromList(
      buf.cast<ffi.Uint8>().asTypedList(written),
    );
    calloc.free(buf);
    calloc.free(outWritten);
    calloc.free(dataPtr);
    return (result, bytes);
  }

  @override
  CResult<int> renderStateNew() {
    final ptr = calloc<ffi.Pointer<native.RenderStateImpl>>();
    final result = native.ghostty_render_state_new(ffi.nullptr, ptr);
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void renderStateFree(int handle) {
    native.ghostty_render_state_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  Result renderStateUpdate(int state, int terminal) {
    return native.ghostty_render_state_update(
      ffi.Pointer.fromAddress(state),
      ffi.Pointer.fromAddress(terminal),
    );
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
    final result = native.ghostty_render_state_get(
      ffi.Pointer.fromAddress(state),
      native.RenderStateData.dirty,
      _outI32.cast(),
    );
    return (result, .fromValue(_outI32.value));
  }

  @override
  Result renderStateSetDirty(int state, RenderStateDirty dirty) {
    _outI32.value = dirty.value;
    return native.ghostty_render_state_set(
      ffi.Pointer.fromAddress(state),
      native.RenderStateOption.dirty,
      _outI32.cast(),
    );
  }

  @override
  CResult<TerminalColors> renderStateGetColors(int state) {
    final result = native.ghostty_render_state_colors_get(
      ffi.Pointer.fromAddress(state),
      _outColors,
    );

    final ref = _outColors.ref;
    return (
      result,
      TerminalColors(
        foreground: RgbColor(
          ref.foreground.r,
          ref.foreground.g,
          ref.foreground.b,
        ),
        background: RgbColor(
          ref.background.r,
          ref.background.g,
          ref.background.b,
        ),
        cursor: ref.cursor_has_value
            ? RgbColor(ref.cursor.r, ref.cursor.g, ref.cursor.b)
            : null,
        palette: [
          for (var i = 0; i < 256; i++)
            RgbColor(ref.palette[i].r, ref.palette[i].g, ref.palette[i].b),
        ],
      ),
    );
  }

  @override
  CResult<RenderStateCursorVisualStyle> renderStateGetCursorVisualStyle(
    int state,
  ) {
    final result = native.ghostty_render_state_get(
      ffi.Pointer.fromAddress(state),
      native.RenderStateData.cursorVisualStyle,
      _outI32.cast(),
    );
    return (result, RenderStateCursorVisualStyle.fromValue(_outI32.value));
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
    final ptr = calloc<ffi.Pointer<native.RenderStateRowIteratorImpl>>();
    final result = native.ghostty_render_state_row_iterator_new(
      ffi.nullptr,
      ptr,
    );
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void rowIteratorFree(int handle) {
    native.ghostty_render_state_row_iterator_free(
      ffi.Pointer.fromAddress(handle),
    );
  }

  @override
  Result rowIteratorInit(int iterator, int renderState) {
    final ptr = calloc<ffi.Pointer<native.RenderStateRowIterator>>();
    ptr.value = ffi.Pointer.fromAddress(iterator);
    final result = native.ghostty_render_state_get(
      ffi.Pointer.fromAddress(renderState),
      native.RenderStateData.rowIterator,
      ptr.cast(),
    );
    calloc.free(ptr);
    return result;
  }

  @override
  bool rowIteratorNext(int iterator) {
    return native.ghostty_render_state_row_iterator_next(
      ffi.Pointer.fromAddress(iterator),
    );
  }

  @override
  CResult<bool> rowIteratorGetDirty(int iterator) {
    final result = native.ghostty_render_state_row_get(
      ffi.Pointer.fromAddress(iterator),
      native.RenderStateRowData.dirty,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  @override
  Result rowIteratorSetDirty(int iterator, {required bool dirty}) {
    _outBool.value = dirty;
    return native.ghostty_render_state_row_set(
      ffi.Pointer.fromAddress(iterator),
      native.RenderStateRowOption.dirty,
      _outBool.cast(),
    );
  }

  @override
  CResult<int> rowIteratorGetRawRow(int iterator) {
    final result = native.ghostty_render_state_row_get(
      ffi.Pointer.fromAddress(iterator),
      native.RenderStateRowData.raw,
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<int> rowCellsNew() {
    final ptr = calloc<ffi.Pointer<native.RenderStateRowCellsImpl>>();
    final result = native.ghostty_render_state_row_cells_new(ffi.nullptr, ptr);
    final address = ptr.value.address;
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void rowCellsFree(int handle) {
    native.ghostty_render_state_row_cells_free(ffi.Pointer.fromAddress(handle));
  }

  @override
  Result rowCellsInit(int cells, int iterator) {
    final ptr = calloc<ffi.Pointer<native.RenderStateRowCells>>();
    ptr.value = ffi.Pointer.fromAddress(cells);
    final result = native.ghostty_render_state_row_get(
      ffi.Pointer.fromAddress(iterator),
      native.RenderStateRowData.cells,
      ptr.cast(),
    );
    calloc.free(ptr);
    return result;
  }

  @override
  bool rowCellsNext(int cells) {
    return native.ghostty_render_state_row_cells_next(
      ffi.Pointer.fromAddress(cells),
    );
  }

  @override
  Result rowCellsSelect(int cells, int x) {
    return native.ghostty_render_state_row_cells_select(
      ffi.Pointer.fromAddress(cells),
      x,
    );
  }

  @override
  CResult<int> rowCellsGetRawCell(int cells) {
    final result = native.ghostty_render_state_row_cells_get(
      ffi.Pointer.fromAddress(cells),
      native.RenderStateRowCellsData.raw,
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<Style> rowCellsGetStyle(int cells) {
    final result = native.ghostty_render_state_row_cells_get(
      ffi.Pointer.fromAddress(cells),
      native.RenderStateRowCellsData.style,
      _outStyle.cast(),
    );
    return (result, _readNativeStyle(_outStyle.ref));
  }

  @override
  CResult<int> rowCellsGetGraphemeLen(int cells) {
    final result = native.ghostty_render_state_row_cells_get(
      ffi.Pointer.fromAddress(cells),
      native.RenderStateRowCellsData.graphemesLen,
      _outU32.cast(),
    );
    return (result, _outU32.value);
  }

  @override
  CResult<List<int>> rowCellsGetGraphemes(int cells, int len) {
    if (len <= 0) return (Result.success, const []);
    final buf = len <= 32 ? _graphemeBuf : calloc<ffi.Uint32>(len);
    final result = native.ghostty_render_state_row_cells_get(
      ffi.Pointer.fromAddress(cells),
      native.RenderStateRowCellsData.graphemesBuf,
      buf.cast(),
    );
    final graphemes = [for (var i = 0; i < len; i++) buf[i]];
    if (len > 32) calloc.free(buf);
    return (result, graphemes);
  }

  @override
  CResult<RgbColor> rowCellsGetBgColor(int cells) {
    final result = native.ghostty_render_state_row_cells_get(
      ffi.Pointer.fromAddress(cells),
      native.RenderStateRowCellsData.bgColor,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  @override
  CResult<RgbColor> rowCellsGetFgColor(int cells) {
    final result = native.ghostty_render_state_row_cells_get(
      ffi.Pointer.fromAddress(cells),
      native.RenderStateRowCellsData.fgColor,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
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
  CResult<int> cellGetStyleId(int cell) {
    final result = native.ghostty_cell_get(cell, .styleId, _outU16.cast());
    return (result, _outU16.value);
  }

  @override
  CResult<bool> cellGetHasHyperlink(int cell) {
    return _cellGetBool(cell, .hasHyperlink);
  }

  @override
  CResult<bool> cellGetProtected(int cell) => _cellGetBool(cell, .protected);

  @override
  CResult<CellSemanticContent> cellGetSemanticContent(int cell) {
    final raw = _cellGetI32(cell, .semanticContent);
    return (raw.$1, CellSemanticContent.fromValue(raw.$2));
  }

  @override
  CResult<int> cellGetColorPalette(int cell) {
    final result = native.ghostty_cell_get(cell, .colorPalette, _outU8.cast());
    return (result, _outU8.value);
  }

  @override
  CResult<RgbColor> cellGetColorRgb(int cell) {
    final out = calloc<native.ColorRgb>();
    final result = native.ghostty_cell_get(cell, .colorRgb, out.cast());
    final rgb = RgbColor(out.ref.r, out.ref.g, out.ref.b);
    calloc.free(out);
    return (result, rgb);
  }

  @override
  CResult<bool> rowGetWrap(int row) => _rowGetBool(row, .wrap);

  @override
  CResult<bool> rowGetWrapContinuation(int row) {
    return _rowGetBool(row, .wrapContinuation);
  }

  @override
  CResult<bool> rowGetGrapheme(int row) => _rowGetBool(row, .grapheme);

  @override
  CResult<bool> rowGetStyled(int row) => _rowGetBool(row, .styled);

  @override
  CResult<bool> rowGetHyperlink(int row) => _rowGetBool(row, .hyperlink);

  @override
  CResult<RowSemanticPrompt> rowGetSemanticPrompt(int row) {
    final result = native.ghostty_row_get(row, .semanticPrompt, _outI32.cast());
    return (result, RowSemanticPrompt.fromValue(_outI32.value));
  }

  @override
  CResult<bool> rowGetKittyVirtualPlaceholder(int row) {
    return _rowGetBool(row, .kittyVirtualPlaceholder);
  }

  @override
  CResult<bool> rowGetDirty(int row) => _rowGetBool(row, .dirty);

  @override
  CResult<String> focusEncode(FocusEvent event) {
    final outLen = calloc<ffi.Size>();
    final buf = calloc<ffi.Char>(8);
    final result = native.ghostty_focus_encode(event, buf, 8, outLen);
    final len = outLen.value;
    final encoded = len == 0
        ? ''
        : utf8.decode(buf.cast<ffi.Uint8>().asTypedList(len));
    calloc.free(outLen);
    calloc.free(buf);
    return (result, encoded);
  }

  CResult<int> _terminalGetU16(int handle, native.TerminalData data) {
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      data,
      _outU16.cast(),
    );
    return (result, _outU16.value);
  }

  CResult<int> _terminalGetU32(int handle, native.TerminalData data) {
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      data,
      _outU32.cast(),
    );
    return (result, _outU32.value);
  }

  CResult<int> _terminalGetSize(int handle, native.TerminalData data) {
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      data,
      _outSize.cast(),
    );
    return (result, _outSize.value);
  }

  CResult<String> _terminalGetString(int handle, native.TerminalData data) {
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      data,
      _outGhosttyString.cast(),
    );
    final ptr = _outGhosttyString.ref.ptr;
    final len = _outGhosttyString.ref.len;
    if (len == 0 || ptr == ffi.nullptr) return (result, '');
    return (result, utf8.decode(ptr.asTypedList(len)));
  }

  Result _terminalSetString(
    int handle,
    native.TerminalOption option,
    String? value,
  ) {
    if (value == null) {
      return native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        option,
        ffi.nullptr,
      );
    }
    final encoded = utf8.encode(value);
    final strPtr = calloc<native.String>();
    final bytesPtr = calloc<ffi.Uint8>(encoded.length);
    bytesPtr.asTypedList(encoded.length).setAll(0, encoded);
    strPtr.ref.ptr = bytesPtr;
    strPtr.ref.len = encoded.length;
    final result = native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      option,
      strPtr.cast(),
    );
    calloc.free(bytesPtr);
    calloc.free(strPtr);
    return result;
  }

  CResult<bool> _terminalGetBool(int handle, native.TerminalData data) {
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      data,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  CResult<RgbColor> _terminalGetColor(int handle, native.TerminalData data) {
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      data,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  CResult<List<RgbColor>> _terminalGetPalette(
    int handle,
    native.TerminalData data,
  ) {
    final ptr = calloc<native.ColorRgb>(256);
    final result = native.ghostty_terminal_get(
      ffi.Pointer.fromAddress(handle),
      data,
      ptr.cast(),
    );

    if (result != .success) {
      calloc.free(ptr);
      return (result, const []);
    }

    final palette = <RgbColor>[
      for (var i = 0; i < 256; i++) RgbColor(ptr[i].r, ptr[i].g, ptr[i].b),
    ];
    calloc.free(ptr);
    return (result, palette);
  }

  Result _terminalSetColor(
    int handle,
    native.TerminalOption option,
    RgbColor? color,
  ) {
    if (color == null) {
      return native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        option,
        ffi.nullptr,
      );
    }
    _outColorRgb.ref.r = color.r;
    _outColorRgb.ref.g = color.g;
    _outColorRgb.ref.b = color.b;
    return native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      option,
      _outColorRgb.cast(),
    );
  }

  CResult<int> _renderStateGetU16(int state, native.RenderStateData data) {
    final result = native.ghostty_render_state_get(
      ffi.Pointer.fromAddress(state),
      data,
      _outU16.cast(),
    );
    return (result, _outU16.value);
  }

  CResult<bool> _renderStateGetBool(int state, native.RenderStateData data) {
    final result = native.ghostty_render_state_get(
      ffi.Pointer.fromAddress(state),
      data,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  CResult<int> _cellGetU32(int cell, native.CellData data) {
    final result = native.ghostty_cell_get(cell, data, _outU32.cast());
    return (result, _outU32.value);
  }

  CResult<int> _cellGetI32(int cell, native.CellData data) {
    final result = native.ghostty_cell_get(cell, data, _outI32.cast());
    return (result, _outI32.value);
  }

  CResult<bool> _cellGetBool(int cell, native.CellData data) {
    final result = native.ghostty_cell_get(cell, data, _outBool.cast());
    return (result, _outBool.value);
  }

  CResult<bool> _rowGetBool(int row, native.RowData data) {
    final result = native.ghostty_row_get(row, data, _outBool.cast());
    return (result, _outBool.value);
  }

  String? _extractWindowTitle(native.OscCommand commandPtr) {
    final outPtr = calloc<ffi.Pointer<ffi.Char>>();
    final success = native.ghostty_osc_command_data(
      commandPtr,
      native.OscCommandData.changeWindowTitleStr,
      outPtr.cast(),
    );
    if (!success) {
      calloc.free(outPtr);
      return null;
    }
    final charPtr = outPtr.value;
    calloc.free(outPtr);
    if (charPtr == ffi.nullptr) return null;
    return charPtr.cast<Utf8>().toDartString();
  }

  static Style _readNativeStyle(native.Style s) {
    final rawUnderlineColor = _readNativeColor(s.underline_color);
    return Style(
      foreground: cellColorFromRaw(_readNativeColor(s.fg_color)),
      background: cellColorFromRaw(_readNativeColor(s.bg_color)),
      underlineColor: switch (rawUnderlineColor.tag) {
        .rgb || .palette => cellColorFromRaw(rawUnderlineColor),
        .none => null,
      },
      bold: s.bold,
      italic: s.italic,
      faint: s.faint,
      blink: s.blink,
      inverse: s.inverse,
      invisible: s.invisible,
      strikethrough: s.strikethrough,
      overline: s.overline,
      underline: UnderlineStyle.fromValue(s.underline),
    );
  }

  static RawColor _readNativeColor(native.StyleColor c) => (
    tag: StyleColorTag.fromValue(c.tag.value),
    palette: c.value.palette,
    r: c.value.rgb.r,
    g: c.value.rgb.g,
    b: c.value.rgb.b,
  );

  static void _writeNativeColor(native.StyleColor ref, RawColor color) {
    ref.tagAsInt = color.tag.value;
    ref.value.palette = color.palette;
    ref.value.rgb.r = color.r;
    ref.value.rgb.g = color.g;
    ref.value.rgb.b = color.b;
  }

  static RawColor _cellColorToRaw(CellColor color) => switch (color) {
    DefaultColor() => defaultRawColor,
    PaletteColor(:final index) => (
      tag: StyleColorTag.palette,
      palette: index,
      r: 0,
      g: 0,
      b: 0,
    ),
    RgbColor(:final r, :final g, :final b) => (
      tag: StyleColorTag.rgb,
      palette: 0,
      r: r,
      g: g,
      b: b,
    ),
  };

  void _freeUtf8(int handle) {
    final ptr = _utf8Ptrs.remove(handle);
    if (ptr != null) calloc.free(ptr);
  }

  SgrAttribute _convertNativeSgrAttribute(native.SgrAttribute attr) {
    final tag = SgrAttributeTag.fromValue(attr.tagAsInt);
    final value = attr.value;
    return switch (tag) {
      .unknown => SgrAttribute(
        tag: tag,
        unknownFull: [
          for (var i = 0; i < value.unknown.full_len; i++)
            value.unknown.full_ptr[i],
        ],
        unknownPartial: [
          for (var i = 0; i < value.unknown.partial_len; i++)
            value.unknown.partial_ptr[i],
        ],
      ),
      .underline => SgrAttribute(
        tag: tag,
        underlineStyle: UnderlineStyle.fromValue(value.underlineAsInt),
      ),
      .underlineColor => SgrAttribute(
        tag: tag,
        color: RgbColor(
          value.underline_color.r,
          value.underline_color.g,
          value.underline_color.b,
        ),
      ),
      .directColorFg => SgrAttribute(
        tag: tag,
        color: RgbColor(
          value.direct_color_fg.r,
          value.direct_color_fg.g,
          value.direct_color_fg.b,
        ),
      ),
      .directColorBg => SgrAttribute(
        tag: tag,
        color: RgbColor(
          value.direct_color_bg.r,
          value.direct_color_bg.g,
          value.direct_color_bg.b,
        ),
      ),
      .underlineColor256 => SgrAttribute(
        tag: tag,
        paletteIndex: value.underline_color_256,
      ),
      .fg8 => SgrAttribute(tag: tag, paletteIndex: value.fg_8),
      .bg8 => SgrAttribute(tag: tag, paletteIndex: value.bg_8),
      .brightFg8 => SgrAttribute(tag: tag, paletteIndex: value.bright_fg_8),
      .brightBg8 => SgrAttribute(tag: tag, paletteIndex: value.bright_bg_8),
      .fg256 => SgrAttribute(tag: tag, paletteIndex: value.fg_256),
      .bg256 => SgrAttribute(tag: tag, paletteIndex: value.bg_256),
      _ => SgrAttribute(tag: tag),
    };
  }

  @override
  CResult<int> buildInfo(BuildInfo data) {
    final result = native.ghostty_build_info(data, _outI32.cast());
    return (result, _outI32.value);
  }

  @override
  CResult<bool> buildInfoBool(BuildInfo data) {
    final result = native.ghostty_build_info(data, _outBool.cast());
    return (result, _outBool.value);
  }

  @override
  CResult<String> buildInfoString(BuildInfo data) {
    final result = native.ghostty_build_info(data, _outGhosttyString.cast());
    final ptr = _outGhosttyString.ref.ptr;
    final len = _outGhosttyString.ref.len;
    if (len == 0 || ptr == ffi.nullptr) return (result, '');
    return (result, utf8.decode(ptr.asTypedList(len)));
  }

  @override
  CResult<String> modeReportEncode(int mode, ModeReportState state) {
    final outLen = calloc<ffi.Size>();
    final buf = calloc<ffi.Char>(64);
    final result = native.ghostty_mode_report_encode(
      mode,
      state,
      buf,
      64,
      outLen,
    );
    final len = outLen.value;
    final encoded = len == 0
        ? ''
        : utf8.decode(buf.cast<ffi.Uint8>().asTypedList(len));
    calloc.free(outLen);
    calloc.free(buf);
    return (result, encoded);
  }

  @override
  CResult<String> sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  ) {
    final size = calloc<native.SizeReportSize>();
    final outLen = calloc<ffi.Size>();
    final buf = calloc<ffi.Char>(64);
    size.ref.rows = rows;
    size.ref.columns = columns;
    size.ref.cell_width = cellWidth;
    size.ref.cell_height = cellHeight;
    final result = native.ghostty_size_report_encode(
      style,
      size.ref,
      buf,
      64,
      outLen,
    );
    final len = outLen.value;
    final encoded = len == 0
        ? ''
        : utf8.decode(buf.cast<ffi.Uint8>().asTypedList(len));
    calloc.free(size);
    calloc.free(outLen);
    calloc.free(buf);
    return (result, encoded);
  }

  @override
  Style styleDefault() {
    final style = calloc<native.Style>();
    style.ref.size = ffi.sizeOf<native.Style>();
    native.ghostty_style_default(style);
    final result = _readNativeStyle(style.ref);
    calloc.free(style);
    return result;
  }

  @override
  bool styleIsDefault(Style style) {
    final s = calloc<native.Style>();
    s.ref.size = ffi.sizeOf<native.Style>();
    _writeNativeColor(s.ref.fg_color, _cellColorToRaw(style.foreground));
    _writeNativeColor(s.ref.bg_color, _cellColorToRaw(style.background));
    _writeNativeColor(
      s.ref.underline_color,
      style.underlineColor != null
          ? _cellColorToRaw(style.underlineColor!)
          : defaultRawColor,
    );
    s.ref.bold = style.bold;
    s.ref.italic = style.italic;
    s.ref.faint = style.faint;
    s.ref.blink = style.blink;
    s.ref.inverse = style.inverse;
    s.ref.invisible = style.invisible;
    s.ref.strikethrough = style.strikethrough;
    s.ref.overline = style.overline;
    s.ref.underline = style.underline.value;
    final isDefault = native.ghostty_style_is_default(s);
    calloc.free(s);
    return isDefault;
  }

  @override
  CResult<int> terminalGridRef(int terminal, PointTag pointTag, int x, int y) {
    final point = calloc<native.Point>();
    final gridRef = calloc<native.GridRef>();
    point.ref.tagAsInt = pointTag.value;
    point.ref.value.coordinate.x = x;
    point.ref.value.coordinate.y = y;
    gridRef.ref.size = ffi.sizeOf<native.GridRef>();
    final result = native.ghostty_terminal_grid_ref(
      ffi.Pointer.fromAddress(terminal),
      point.ref,
      gridRef,
    );
    calloc.free(point);
    return (result, gridRef.address);
  }

  @override
  void gridRefFree(int ref) {
    calloc.free(ffi.Pointer<ffi.Void>.fromAddress(ref));
  }

  @override
  CResult<int> gridRefCell(int ref) {
    final result = native.ghostty_grid_ref_cell(
      ffi.Pointer.fromAddress(ref),
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<int> gridRefRow(int ref) {
    final result = native.ghostty_grid_ref_row(
      ffi.Pointer.fromAddress(ref),
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<Style> gridRefStyle(int ref) {
    _outStyle.ref.size = ffi.sizeOf<native.Style>();
    final result = native.ghostty_grid_ref_style(
      ffi.Pointer.fromAddress(ref),
      _outStyle,
    );
    return (result, _readNativeStyle(_outStyle.ref));
  }

  @override
  CResult<List<int>> gridRefGraphemes(int ref) {
    final outLen = calloc<ffi.Size>();
    var result = native.ghostty_grid_ref_graphemes(
      ffi.Pointer.fromAddress(ref),
      _graphemeBuf,
      32,
      outLen,
    );
    var len = outLen.value;

    if (result == Result.outOfSpace) {
      final bigBuf = calloc<ffi.Uint32>(len);
      result = native.ghostty_grid_ref_graphemes(
        ffi.Pointer.fromAddress(ref),
        bigBuf,
        len,
        outLen,
      );
      len = outLen.value;
      final graphemes = [for (var i = 0; i < len; i++) bigBuf[i]];
      calloc.free(bigBuf);
      calloc.free(outLen);
      return (result, graphemes);
    }

    final graphemes = [for (var i = 0; i < len; i++) _graphemeBuf[i]];
    calloc.free(outLen);
    return (result, graphemes);
  }

  @override
  CResult<int> formatterTerminalNew(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
  }) {
    final ptr = calloc<ffi.Pointer<native.FormatterImpl>>();
    final opts = calloc<native.FormatterTerminalOptions>();
    opts.ref
      ..size = ffi.sizeOf<native.FormatterTerminalOptions>()
      ..emitAsInt = format.value
      ..unwrap = unwrap
      ..trim = trim;

    opts.ref.extra
      ..size = ffi.sizeOf<native.FormatterTerminalExtra>()
      ..palette = extra.palette
      ..modes = extra.modes
      ..scrolling_region = extra.scrollingRegion
      ..tabstops = extra.tabstops
      ..pwd = extra.pwd
      ..keyboard = extra.keyboard;

    opts.ref.extra.screen
      ..size = ffi.sizeOf<native.FormatterScreenExtra>()
      ..cursor = extra.cursor
      ..style = extra.style
      ..hyperlink = extra.hyperlink
      ..protection = extra.protection
      ..kitty_keyboard = extra.kittyKeyboard
      ..charsets = extra.charsets;

    final result = native.ghostty_formatter_terminal_new(
      ffi.nullptr,
      ptr.cast(),
      ffi.Pointer.fromAddress(terminal),
      opts.ref,
    );
    final address = ptr.value.address;
    calloc.free(opts);
    calloc.free(ptr);
    return (result, address);
  }

  @override
  void formatterFree(int formatter) {
    native.ghostty_formatter_free(ffi.Pointer.fromAddress(formatter));
  }

  @override
  CResult<String> formatterFormat(int formatter) {
    final outPtr = calloc<ffi.Pointer<ffi.Uint8>>();
    final outLen = calloc<ffi.Size>();
    final result = native.ghostty_formatter_format_alloc(
      ffi.Pointer.fromAddress(formatter),
      ffi.nullptr,
      outPtr,
      outLen,
    );
    final len = outLen.value;
    final buf = outPtr.value;
    calloc.free(outPtr);
    calloc.free(outLen);
    if (len == 0 || buf == ffi.nullptr) return (result, '');
    final encoded = utf8.decode(buf.cast<ffi.Uint8>().asTypedList(len));
    native.ghostty_free(ffi.nullptr, buf, len);
    return (result, encoded);
  }

  @override
  void terminalSetOnWritePty(int handle, ValueSetter<Uint8List>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[native.TerminalOption.writePty]?.close();

    if (callback == null) {
      map.remove(native.TerminalOption.writePty);
      native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.writePty,
        ffi.nullptr,
      );
      return;
    }

    final callable =
        ffi.NativeCallable<
          ffi.Void Function(
            native.Terminal,
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<ffi.Uint8>,
            ffi.Size,
          )
        >.isolateLocal((
          native.Terminal terminal,
          ffi.Pointer<ffi.Void> userdata,
          ffi.Pointer<ffi.Uint8> data,
          int len,
        ) {
          try {
            callback(Uint8List.fromList(data.asTypedList(len)));
          } on Object catch (_) {}
        });
    map[native.TerminalOption.writePty] = callable;
    native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.writePty,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnBell(int handle, VoidCallback? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[native.TerminalOption.bell]?.close();

    if (callback == null) {
      map.remove(native.TerminalOption.bell);
      native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.bell,
        ffi.nullptr,
      );
      return;
    }

    final callable =
        ffi.NativeCallable<
          ffi.Void Function(native.Terminal, ffi.Pointer<ffi.Void>)
        >.isolateLocal((
          native.Terminal terminal,
          ffi.Pointer<ffi.Void> userdata,
        ) {
          try {
            callback();
          } on Object catch (_) {}
        });
    map[native.TerminalOption.bell] = callable;
    native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.bell,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnTitleChanged(int handle, VoidCallback? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[native.TerminalOption.titleChanged]?.close();

    if (callback == null) {
      map.remove(native.TerminalOption.titleChanged);
      native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.titleChanged,
        ffi.nullptr,
      );
      return;
    }

    final callable =
        ffi.NativeCallable<
          ffi.Void Function(native.Terminal, ffi.Pointer<ffi.Void>)
        >.isolateLocal((
          native.Terminal terminal,
          ffi.Pointer<ffi.Void> userdata,
        ) {
          try {
            callback();
          } on Object catch (_) {}
        });
    map[native.TerminalOption.titleChanged] = callable;
    native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.titleChanged,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnEnquiry(int handle, ValueGetter<Uint8List>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[native.TerminalOption.enquiry]?.close();

    if (callback == null) {
      map.remove(native.TerminalOption.enquiry);
      native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.enquiry,
        ffi.nullptr,
      );
      return;
    }

    final bufMap = _stringBuffers.putIfAbsent(handle, () => {});
    final strPtr =
        bufMap[native.TerminalOption.enquiry]?.str ?? calloc<native.String>();
    bufMap[native.TerminalOption.enquiry] = (
      str: strPtr,
      data:
          bufMap[native.TerminalOption.enquiry]?.data ??
          ffi.nullptr.cast<ffi.Uint8>(),
    );

    final callable =
        ffi.NativeCallable<
          native.String Function(native.Terminal, ffi.Pointer<ffi.Void>)
        >.isolateLocal((
          native.Terminal terminal,
          ffi.Pointer<ffi.Void> userdata,
        ) {
          try {
            final bytes = callback();
            final current = bufMap[native.TerminalOption.enquiry]!;
            if (current.data != ffi.nullptr) calloc.free(current.data);
            final dataPtr = calloc<ffi.Uint8>(bytes.length);
            dataPtr.asTypedList(bytes.length).setAll(0, bytes);
            bufMap[native.TerminalOption.enquiry] = (
              str: strPtr,
              data: dataPtr,
            );
            strPtr.ref.ptr = dataPtr;
            strPtr.ref.len = bytes.length;
            return strPtr.ref;
          } on Object catch (_) {
            strPtr.ref.ptr = ffi.nullptr;
            strPtr.ref.len = 0;
            return strPtr.ref;
          }
        });
    map[native.TerminalOption.enquiry] = callable;
    native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.enquiry,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnXtversion(int handle, ValueGetter<String>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[native.TerminalOption.xtversion]?.close();

    if (callback == null) {
      map.remove(native.TerminalOption.xtversion);
      native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.xtversion,
        ffi.nullptr,
      );
      return;
    }

    final bufMap = _stringBuffers.putIfAbsent(handle, () => {});
    final strPtr =
        bufMap[native.TerminalOption.xtversion]?.str ?? calloc<native.String>();
    bufMap[native.TerminalOption.xtversion] = (
      str: strPtr,
      data:
          bufMap[native.TerminalOption.xtversion]?.data ??
          ffi.nullptr.cast<ffi.Uint8>(),
    );

    final callable =
        ffi.NativeCallable<
          native.String Function(native.Terminal, ffi.Pointer<ffi.Void>)
        >.isolateLocal((
          native.Terminal terminal,
          ffi.Pointer<ffi.Void> userdata,
        ) {
          try {
            final result = callback();
            final bytes = utf8.encode(result);
            final current = bufMap[native.TerminalOption.xtversion]!;
            if (current.data != ffi.nullptr) calloc.free(current.data);
            final dataPtr = calloc<ffi.Uint8>(bytes.length);
            dataPtr.asTypedList(bytes.length).setAll(0, bytes);
            bufMap[native.TerminalOption.xtversion] = (
              str: strPtr,
              data: dataPtr,
            );
            strPtr.ref.ptr = dataPtr;
            strPtr.ref.len = bytes.length;
            return strPtr.ref;
          } on Object catch (_) {
            strPtr.ref.ptr = ffi.nullptr;
            strPtr.ref.len = 0;
            return strPtr.ref;
          }
        });
    map[native.TerminalOption.xtversion] = callable;
    native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.xtversion,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnColorScheme(
    int handle,
    ValueGetter<ColorScheme?>? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[native.TerminalOption.colorScheme]?.close();

    if (callback == null) {
      map.remove(native.TerminalOption.colorScheme);
      native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.colorScheme,
        ffi.nullptr,
      );
      return;
    }

    final callable =
        ffi.NativeCallable<
          ffi.Bool Function(
            native.Terminal,
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<ffi.UnsignedInt>,
          )
        >.isolateLocal((
          native.Terminal terminal,
          ffi.Pointer<ffi.Void> userdata,
          ffi.Pointer<ffi.UnsignedInt> outScheme,
        ) {
          try {
            final result = callback();
            if (result == null) return false;
            outScheme.value = result.value;
            return true;
          } on Object catch (_) {
            return false;
          }
        }, exceptionalReturn: false);
    map[native.TerminalOption.colorScheme] = callable;
    native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.colorScheme,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnSize(int handle, ValueGetter<TerminalSizeInfo?>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[native.TerminalOption.size]?.close();

    if (callback == null) {
      map.remove(native.TerminalOption.size);
      native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.size,
        ffi.nullptr,
      );
      return;
    }

    final callable =
        ffi.NativeCallable<
          ffi.Bool Function(
            native.Terminal,
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<native.SizeReportSize>,
          )
        >.isolateLocal((
          native.Terminal terminal,
          ffi.Pointer<ffi.Void> userdata,
          ffi.Pointer<native.SizeReportSize> outSize,
        ) {
          try {
            final result = callback();
            if (result == null) return false;
            outSize.ref.rows = result.rows;
            outSize.ref.columns = result.columns;
            outSize.ref.cell_width = result.cellWidth;
            outSize.ref.cell_height = result.cellHeight;
            return true;
          } on Object catch (_) {
            return false;
          }
        }, exceptionalReturn: false);
    map[native.TerminalOption.size] = callable;
    native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.size,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnDeviceAttributes(
    int handle,
    ValueGetter<DeviceAttributesResponse?>? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[native.TerminalOption.deviceAttributes]?.close();

    if (callback == null) {
      map.remove(native.TerminalOption.deviceAttributes);
      native.ghostty_terminal_set(
        ffi.Pointer.fromAddress(handle),
        native.TerminalOption.deviceAttributes,
        ffi.nullptr,
      );
      return;
    }

    final callable =
        ffi.NativeCallable<
          ffi.Bool Function(
            native.Terminal,
            ffi.Pointer<ffi.Void>,
            ffi.Pointer<native.DeviceAttributes>,
          )
        >.isolateLocal((
          native.Terminal terminal,
          ffi.Pointer<ffi.Void> userdata,
          ffi.Pointer<native.DeviceAttributes> outAttrs,
        ) {
          try {
            final result = callback();
            if (result == null) return false;
            outAttrs.ref.primary.conformance_level =
                result.primary.conformanceLevel;
            final featureCount = result.primary.features.length > 64
                ? 64
                : result.primary.features.length;
            for (var i = 0; i < featureCount; i++) {
              outAttrs.ref.primary.features[i] = result.primary.features[i];
            }
            outAttrs.ref.primary.num_features = featureCount;
            outAttrs.ref.secondary.device_type = result.secondary.deviceType;
            outAttrs.ref.secondary.firmware_version =
                result.secondary.firmwareVersion;
            outAttrs.ref.secondary.rom_cartridge =
                result.secondary.romCartridge;
            outAttrs.ref.tertiary.unit_id = result.tertiary.unitId;
            return true;
          } on Object catch (_) {
            return false;
          }
        }, exceptionalReturn: false);
    map[native.TerminalOption.deviceAttributes] = callable;
    native.ghostty_terminal_set(
      ffi.Pointer.fromAddress(handle),
      native.TerminalOption.deviceAttributes,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalDisposeCallbacks(int handle) {
    if (_callables.remove(handle) case Map(:final keys, :final values)) {
      for (final option in keys) {
        native.ghostty_terminal_set(
          ffi.Pointer.fromAddress(handle),
          option,
          ffi.nullptr,
        );
      }
      for (final c in values) {
        c.close();
      }
    }

    if (_stringBuffers.remove(handle) case Map(:final values)) {
      for (final buf in values) {
        if (buf.data != ffi.nullptr) calloc.free(buf.data);
        calloc.free(buf.str);
      }
    }
  }
}
