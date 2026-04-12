import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import '../../ffi/libghostty.g.dart'
    as native
    show MouseEncoderSize, SgrAttribute, String, Style;
import '../../ffi/libghostty.g.dart'
    hide MouseEncoderSize, SgrAttribute, String, Style;
import '../../ffi/libghostty_enums.g.dart';
import '../interface.dart';

typedef _StringBuffer = ({Pointer<native.String> str, Pointer<Uint8> data});

final GhosttyBindings bindings = NativeBindings();

Future<void> initializeForWeb(Uri wasmUri) async {}

class NativeBindings implements GhosttyBindings {
  final _utf8Ptrs = <int, Pointer<Char>>{};
  final _callables = <int, Map<TerminalOption, NativeCallable>>{};
  final _stringBuffers = <int, Map<TerminalOption, _StringBuffer>>{};

  final _outU8 = calloc<Uint8>();
  final _outU16 = calloc<Uint16>();
  final _outU32 = calloc<Uint32>();
  final _outU64 = calloc<Uint64>();
  final _outI32 = calloc<Int32>();
  final _outBool = calloc<Bool>();
  final _outStyle = calloc<native.Style>();
  final _outScrollbar = calloc<TerminalScrollbar>();
  final _outColors = calloc<RenderStateColors>();
  final _outSize = calloc<Size>();
  final _outGhosttyString = calloc<native.String>();
  final _outColorRgb = calloc<ColorRgb>();
  final _graphemeBuf = calloc<Uint32>(32);

  NativeBindings() {
    _outColors.ref.size = sizeOf<RenderStateColors>();
    _outStyle.ref.size = sizeOf<native.Style>();
  }

  @override
  CResult<int> keyEventNew() {
    return using((arena) {
      final ptr = arena<Pointer<KeyEventImpl>>();
      final result = ghostty_key_event_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void keyEventFree(int handle) {
    _freeUtf8(handle);
    ghostty_key_event_free(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetAction(int handle, KeyAction action) {
    ghostty_key_event_set_action(Pointer.fromAddress(handle), action);
  }

  @override
  KeyAction keyEventGetAction(int handle) {
    return ghostty_key_event_get_action(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetKey(int handle, Key key) {
    ghostty_key_event_set_key(Pointer.fromAddress(handle), key);
  }

  @override
  Key keyEventGetKey(int handle) {
    return ghostty_key_event_get_key(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetMods(int handle, int mods) {
    ghostty_key_event_set_mods(Pointer.fromAddress(handle), mods);
  }

  @override
  int keyEventGetMods(int handle) {
    return ghostty_key_event_get_mods(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetConsumedMods(int handle, int mods) {
    ghostty_key_event_set_consumed_mods(Pointer.fromAddress(handle), mods);
  }

  @override
  int keyEventGetConsumedMods(int handle) {
    return ghostty_key_event_get_consumed_mods(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetComposing(int handle, {required bool composing}) {
    ghostty_key_event_set_composing(Pointer.fromAddress(handle), composing);
  }

  @override
  bool keyEventGetComposing(int handle) {
    return ghostty_key_event_get_composing(Pointer.fromAddress(handle));
  }

  @override
  void keyEventSetUtf8(int handle, String? text) {
    _freeUtf8(handle);
    final ptr = Pointer<KeyEventImpl>.fromAddress(handle);
    if (text == null) {
      ghostty_key_event_set_utf8(ptr, nullptr, 0);
      return;
    }
    final encoded = utf8.encode(text);
    final charPtr = calloc<Char>(encoded.length);
    final dst = charPtr.cast<Uint8>().asTypedList(encoded.length);
    dst.setAll(0, encoded);
    _utf8Ptrs[handle] = charPtr;
    ghostty_key_event_set_utf8(ptr, charPtr, encoded.length);
  }

  @override
  String? keyEventGetUtf8(int handle) {
    return using((arena) {
      final lenPtr = arena<Size>();
      final charPtr = ghostty_key_event_get_utf8(
        Pointer.fromAddress(handle),
        lenPtr,
      );
      if (charPtr == nullptr) return null;
      final len = lenPtr.value;
      if (len == 0) return null;
      return utf8.decode(charPtr.cast<Uint8>().asTypedList(len));
    });
  }

  @override
  void keyEventSetUnshiftedCodepoint(int handle, int codepoint) {
    ghostty_key_event_set_unshifted_codepoint(
      Pointer.fromAddress(handle),
      codepoint,
    );
  }

  @override
  int keyEventGetUnshiftedCodepoint(int handle) {
    return ghostty_key_event_get_unshifted_codepoint(
      Pointer.fromAddress(handle),
    );
  }

  @override
  CResult<int> keyEncoderNew() {
    return using((arena) {
      final ptr = arena<Pointer<KeyEncoderImpl>>();
      final result = ghostty_key_encoder_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void keyEncoderFree(int handle) {
    ghostty_key_encoder_free(Pointer.fromAddress(handle));
  }

  @override
  void keyEncoderSetBoolOpt(
    int handle,
    KeyEncoderOption option, {
    required bool value,
  }) {
    using((arena) {
      final ptr = arena<Bool>()..value = value;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(handle),
        option,
        ptr.cast(),
      );
    });
  }

  @override
  void keyEncoderSetKittyFlags(int handle, int flags) {
    using((arena) {
      final ptr = arena<Uint8>()..value = flags;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(handle),
        KeyEncoderOption.kittyFlags,
        ptr.cast(),
      );
    });
  }

  @override
  void keyEncoderSetOptionAsAlt(int handle, OptionAsAlt value) {
    using((arena) {
      final ptr = arena<Int32>()..value = value.value;
      ghostty_key_encoder_setopt(
        Pointer.fromAddress(handle),
        KeyEncoderOption.macosOptionAsAlt,
        ptr.cast(),
      );
    });
  }

  @override
  void keyEncoderSetOptFromTerminal(int encoder, int terminal) {
    ghostty_key_encoder_setopt_from_terminal(
      Pointer.fromAddress(encoder),
      Pointer.fromAddress(terminal),
    );
  }

  @override
  CResult<String> keyEncoderEncode(int encoder, int event) {
    return using((arena) {
      final outLen = arena<Size>();
      var bufSize = 128;
      var buf = arena<Char>(bufSize);
      var result = ghostty_key_encoder_encode(
        Pointer.fromAddress(encoder),
        Pointer.fromAddress(event),
        buf,
        bufSize,
        outLen,
      );

      // Retry with the required size if the initial buffer was too small.
      if (result == Result.outOfSpace) {
        bufSize = outLen.value;
        buf = arena<Char>(bufSize);
        result = ghostty_key_encoder_encode(
          Pointer.fromAddress(encoder),
          Pointer.fromAddress(event),
          buf,
          bufSize,
          outLen,
        );
      }

      final len = outLen.value;
      return (result, utf8.decode(buf.cast<Uint8>().asTypedList(len)));
    });
  }

  @override
  CResult<int> mouseEventNew() {
    return using((arena) {
      final ptr = arena<Pointer<MouseEventImpl>>();
      final result = ghostty_mouse_event_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void mouseEventFree(int handle) {
    ghostty_mouse_event_free(Pointer.fromAddress(handle));
  }

  @override
  void mouseEventSetAction(int handle, MouseAction action) {
    ghostty_mouse_event_set_action(Pointer.fromAddress(handle), action);
  }

  @override
  MouseAction mouseEventGetAction(int handle) {
    return ghostty_mouse_event_get_action(Pointer.fromAddress(handle));
  }

  @override
  void mouseEventSetButton(int handle, MouseButton button) {
    ghostty_mouse_event_set_button(Pointer.fromAddress(handle), button);
  }

  @override
  void mouseEventClearButton(int handle) {
    ghostty_mouse_event_clear_button(Pointer.fromAddress(handle));
  }

  @override
  CResult<MouseButton> mouseEventGetButton(int handle) {
    return using((arena) {
      final out = arena<Int32>();
      final hasButton = ghostty_mouse_event_get_button(
        Pointer.fromAddress(handle),
        out.cast(),
      );
      final result = hasButton ? Result.success : Result.noValue;
      return (result, MouseButton.fromValue(out.value));
    });
  }

  @override
  void mouseEventSetMods(int handle, int mods) {
    ghostty_mouse_event_set_mods(Pointer.fromAddress(handle), mods);
  }

  @override
  int mouseEventGetMods(int handle) {
    return ghostty_mouse_event_get_mods(Pointer.fromAddress(handle));
  }

  @override
  void mouseEventSetPosition(int handle, double x, double y) {
    using((arena) {
      final pos = arena<MousePosition>();
      pos.ref.x = x;
      pos.ref.y = y;
      ghostty_mouse_event_set_position(Pointer.fromAddress(handle), pos.ref);
    });
  }

  @override
  (double, double) mouseEventGetPosition(int handle) {
    final pos = ghostty_mouse_event_get_position(Pointer.fromAddress(handle));
    return (pos.x, pos.y);
  }

  @override
  CResult<int> mouseEncoderNew() {
    return using((arena) {
      final ptr = arena<Pointer<MouseEncoderImpl>>();
      final result = ghostty_mouse_encoder_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void mouseEncoderFree(int handle) {
    ghostty_mouse_encoder_free(Pointer.fromAddress(handle));
  }

  @override
  void mouseEncoderSetBoolOpt(
    int handle,
    MouseEncoderOption option, {
    required bool value,
  }) {
    using((arena) {
      final ptr = arena<Bool>()..value = value;
      ghostty_mouse_encoder_setopt(
        Pointer.fromAddress(handle),
        option,
        ptr.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetTrackingMode(int handle, MouseTrackingMode mode) {
    using((arena) {
      final ptr = arena<Int32>()..value = mode.value;
      ghostty_mouse_encoder_setopt(
        Pointer.fromAddress(handle),
        MouseEncoderOption.event,
        ptr.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetFormat(int handle, MouseFormat format) {
    using((arena) {
      final ptr = arena<Int32>()..value = format.value;
      ghostty_mouse_encoder_setopt(
        Pointer.fromAddress(handle),
        MouseEncoderOption.format,
        ptr.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetSize(int handle, MouseEncoderSize size) {
    using((arena) {
      final ptr = arena<native.MouseEncoderSize>();
      ptr.ref
        ..size = sizeOf<native.MouseEncoderSize>()
        ..screen_width = size.screenWidth
        ..screen_height = size.screenHeight
        ..cell_width = size.cellWidth
        ..cell_height = size.cellHeight
        ..padding_top = size.paddingTop
        ..padding_bottom = size.paddingBottom
        ..padding_left = size.paddingLeft
        ..padding_right = size.paddingRight;
      ghostty_mouse_encoder_setopt(
        Pointer.fromAddress(handle),
        MouseEncoderOption.size,
        ptr.cast(),
      );
    });
  }

  @override
  void mouseEncoderSetOptFromTerminal(int encoder, int terminal) {
    ghostty_mouse_encoder_setopt_from_terminal(
      Pointer.fromAddress(encoder),
      Pointer.fromAddress(terminal),
    );
  }

  @override
  void mouseEncoderReset(int handle) {
    ghostty_mouse_encoder_reset(Pointer.fromAddress(handle));
  }

  @override
  CResult<String> mouseEncoderEncode(int encoder, int event) {
    return using((arena) {
      final outLen = arena<Size>();
      var bufSize = 128;
      var buf = arena<Char>(bufSize);
      var result = ghostty_mouse_encoder_encode(
        Pointer.fromAddress(encoder),
        Pointer.fromAddress(event),
        buf,
        bufSize,
        outLen,
      );

      // Retry with the required size if the initial buffer was too small.
      if (result == Result.outOfSpace) {
        bufSize = outLen.value;
        buf = arena<Char>(bufSize);
        result = ghostty_mouse_encoder_encode(
          Pointer.fromAddress(encoder),
          Pointer.fromAddress(event),
          buf,
          bufSize,
          outLen,
        );
      }

      final len = outLen.value;
      return (result, utf8.decode(buf.cast<Uint8>().asTypedList(len)));
    });
  }

  @override
  CResult<int> oscNew() {
    return using((arena) {
      final ptr = arena<Pointer<OscParserImpl>>();
      final result = ghostty_osc_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void oscFree(int handle) {
    ghostty_osc_free(Pointer.fromAddress(handle));
  }

  @override
  void oscFeedByte(int handle, int byte) {
    ghostty_osc_next(Pointer.fromAddress(handle), byte);
  }

  @override
  int oscEnd(int handle, int terminator) {
    return ghostty_osc_end(Pointer.fromAddress(handle), terminator).address;
  }

  @override
  OscCommandType oscCommandType(int command) {
    return ghostty_osc_command_type(OscCommand.fromAddress(command));
  }

  @override
  String? oscCommandWindowTitle(int command) {
    return _extractWindowTitle(OscCommand.fromAddress(command));
  }

  @override
  void oscReset(int handle) {
    ghostty_osc_reset(Pointer.fromAddress(handle));
  }

  @override
  CResult<int> sgrNew() {
    return using((arena) {
      final ptr = arena<Pointer<SgrParserImpl>>();
      final result = ghostty_sgr_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void sgrFree(int handle) {
    ghostty_sgr_free(Pointer.fromAddress(handle));
  }

  @override
  Result sgrSetParams(int handle, List<int> params, List<String>? separators) {
    return using((arena) {
      final nativeParams = arena<Uint16>(params.length);
      for (var i = 0; i < params.length; i++) {
        nativeParams[i] = params[i];
      }

      Pointer<Char> nativeSeps = nullptr;
      if (separators != null) {
        nativeSeps = arena<Char>(separators.length);
        for (var i = 0; i < separators.length; i++) {
          (nativeSeps + i).value = separators[i].codeUnitAt(0);
        }
      }

      return ghostty_sgr_set_params(
        Pointer.fromAddress(handle),
        nativeParams,
        nativeSeps,
        params.length,
      );
    });
  }

  @override
  SgrAttribute? sgrNext(int handle) {
    return using((arena) {
      final attrPtr = arena<native.SgrAttribute>();
      final hasNext = ghostty_sgr_next(Pointer.fromAddress(handle), attrPtr);
      if (!hasNext) return null;
      return _convertNativeSgrAttribute(attrPtr.ref);
    });
  }

  @override
  void sgrReset(int handle) {
    ghostty_sgr_reset(Pointer.fromAddress(handle));
  }

  @override
  bool pasteIsSafe(String data) {
    return using((arena) {
      final encoded = utf8.encode(data);
      final ptr = arena<Char>(encoded.length);
      ptr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      return ghostty_paste_is_safe(ptr, encoded.length);
    });
  }

  @override
  CResult<int> terminalNew(int cols, int rows, int maxScrollback) {
    return using((arena) {
      final ptr = arena<Pointer<TerminalImpl>>();
      final opts = arena<TerminalOptions>();
      opts.ref.cols = cols;
      opts.ref.rows = rows;
      opts.ref.max_scrollback = maxScrollback;
      final result = ghostty_terminal_new(nullptr, ptr, opts.ref);
      return (result, ptr.value.address);
    });
  }

  @override
  void terminalFree(int handle) {
    ghostty_terminal_free(Pointer.fromAddress(handle));
  }

  @override
  void terminalVtWrite(int handle, Uint8List data) {
    if (data.isEmpty) return;
    using((arena) {
      final ptr = arena<Uint8>(data.length);
      ptr.asTypedList(data.length).setAll(0, data);
      ghostty_terminal_vt_write(Pointer.fromAddress(handle), ptr, data.length);
    });
  }

  @override
  Result terminalResize(
    int handle,
    int cols,
    int rows,
    int cellWidthPx,
    int cellHeightPx,
  ) {
    return ghostty_terminal_resize(
      Pointer.fromAddress(handle),
      cols,
      rows,
      cellWidthPx,
      cellHeightPx,
    );
  }

  @override
  void terminalReset(int handle) {
    ghostty_terminal_reset(Pointer.fromAddress(handle));
  }

  @override
  void terminalScrollViewport(
    int handle,
    TerminalScrollViewportTag tag,
    int delta,
  ) {
    using((arena) {
      final sv = arena<TerminalScrollViewport>();
      sv.ref.tagAsInt = tag.value;
      sv.ref.value.delta = delta;
      ghostty_terminal_scroll_viewport(Pointer.fromAddress(handle), sv.ref);
    });
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
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      .activeScreen,
      _outI32.cast(),
    );
    return (result, TerminalScreen.fromValue(_outI32.value));
  }

  @override
  CResult<int> terminalGetKittyKeyboardFlags(int handle) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      .kittyKeyboardFlags,
      _outU8.cast(),
    );
    return (result, _outU8.value);
  }

  @override
  CResult<Scrollbar> terminalGetScrollbar(int handle) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
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
    final result = ghostty_terminal_mode_get(
      Pointer.fromAddress(handle),
      mode,
      _outBool,
    );
    return (result, _outBool.value);
  }

  @override
  Result terminalModeSet(int handle, int mode, {required bool value}) {
    return ghostty_terminal_mode_set(Pointer.fromAddress(handle), mode, value);
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
      return ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.colorPalette,
        nullptr,
      );
    }
    return using((arena) {
      final ptr = arena<ColorRgb>(256);
      for (var i = 0; i < 256; i++) {
        ptr[i].r = palette[i].r;
        ptr[i].g = palette[i].g;
        ptr[i].b = palette[i].b;
      }
      return ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.colorPalette,
        ptr.cast(),
      );
    });
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
    return using((arena) {
      final encoded = utf8.encode(data);
      final dataPtr = arena<Char>(encoded.length);
      dataPtr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);
      final outWritten = arena<Size>();

      // First call to get the required buffer size.
      var result = ghostty_paste_encode(
        dataPtr,
        encoded.length,
        bracketed,
        nullptr,
        0,
        outWritten,
      );

      if (result != .outOfSpace) return (result, Uint8List(0));

      final bufLen = outWritten.value;
      final buf = arena<Char>(bufLen);

      // Re-encode the data since the first call modified it in place.
      dataPtr.cast<Uint8>().asTypedList(encoded.length).setAll(0, encoded);

      result = ghostty_paste_encode(
        dataPtr,
        encoded.length,
        bracketed,
        buf,
        bufLen,
        outWritten,
      );

      final written = outWritten.value;
      return (
        result,
        Uint8List.fromList(buf.cast<Uint8>().asTypedList(written)),
      );
    });
  }

  @override
  CResult<int> renderStateNew() {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateImpl>>();
      final result = ghostty_render_state_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void renderStateFree(int handle) {
    ghostty_render_state_free(Pointer.fromAddress(handle));
  }

  @override
  Result renderStateUpdate(int state, int terminal) {
    return ghostty_render_state_update(
      Pointer.fromAddress(state),
      Pointer.fromAddress(terminal),
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
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      RenderStateData.dirty,
      _outI32.cast(),
    );
    return (result, .fromValue(_outI32.value));
  }

  @override
  Result renderStateSetDirty(int state, RenderStateDirty dirty) {
    _outI32.value = dirty.value;
    return ghostty_render_state_set(
      Pointer.fromAddress(state),
      RenderStateOption.dirty,
      _outI32.cast(),
    );
  }

  @override
  CResult<TerminalColors> renderStateGetColors(int state) {
    final result = ghostty_render_state_colors_get(
      Pointer.fromAddress(state),
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
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      RenderStateData.cursorVisualStyle,
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
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowIteratorImpl>>();
      final result = ghostty_render_state_row_iterator_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void rowIteratorFree(int handle) {
    ghostty_render_state_row_iterator_free(Pointer.fromAddress(handle));
  }

  @override
  Result rowIteratorInit(int iterator, int renderState) {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowIterator>>();
      ptr.value = Pointer.fromAddress(iterator);
      return ghostty_render_state_get(
        Pointer.fromAddress(renderState),
        RenderStateData.rowIterator,
        ptr.cast(),
      );
    });
  }

  @override
  bool rowIteratorNext(int iterator) {
    return ghostty_render_state_row_iterator_next(
      Pointer.fromAddress(iterator),
    );
  }

  @override
  CResult<bool> rowIteratorGetDirty(int iterator) {
    final result = ghostty_render_state_row_get(
      Pointer.fromAddress(iterator),
      RenderStateRowData.dirty,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  @override
  Result rowIteratorSetDirty(int iterator, {required bool dirty}) {
    _outBool.value = dirty;
    return ghostty_render_state_row_set(
      Pointer.fromAddress(iterator),
      RenderStateRowOption.dirty,
      _outBool.cast(),
    );
  }

  @override
  CResult<int> rowIteratorGetRawRow(int iterator) {
    final result = ghostty_render_state_row_get(
      Pointer.fromAddress(iterator),
      RenderStateRowData.raw,
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<int> rowCellsNew() {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowCellsImpl>>();
      final result = ghostty_render_state_row_cells_new(nullptr, ptr);
      return (result, ptr.value.address);
    });
  }

  @override
  void rowCellsFree(int handle) {
    ghostty_render_state_row_cells_free(Pointer.fromAddress(handle));
  }

  @override
  Result rowCellsInit(int cells, int iterator) {
    return using((arena) {
      final ptr = arena<Pointer<RenderStateRowCells>>();
      ptr.value = Pointer.fromAddress(cells);
      return ghostty_render_state_row_get(
        Pointer.fromAddress(iterator),
        RenderStateRowData.cells,
        ptr.cast(),
      );
    });
  }

  @override
  bool rowCellsNext(int cells) {
    return ghostty_render_state_row_cells_next(Pointer.fromAddress(cells));
  }

  @override
  Result rowCellsSelect(int cells, int x) {
    return ghostty_render_state_row_cells_select(Pointer.fromAddress(cells), x);
  }

  @override
  CResult<int> rowCellsGetRawCell(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.raw,
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<Style> rowCellsGetStyle(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.style,
      _outStyle.cast(),
    );
    return (result, _readNativeStyle(_outStyle.ref));
  }

  @override
  CResult<int> rowCellsGetGraphemeLen(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.graphemesLen,
      _outU32.cast(),
    );
    return (result, _outU32.value);
  }

  @override
  CResult<List<int>> rowCellsGetGraphemes(int cells, int len) {
    if (len <= 0) return (Result.success, const []);
    final buf = len <= 32 ? _graphemeBuf : calloc<Uint32>(len);
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.graphemesBuf,
      buf.cast(),
    );
    final graphemes = [for (var i = 0; i < len; i++) buf[i]];
    if (len > 32) calloc.free(buf);
    return (result, graphemes);
  }

  @override
  CResult<RgbColor> rowCellsGetBgColor(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.bgColor,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  @override
  CResult<RgbColor> rowCellsGetFgColor(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      RenderStateRowCellsData.fgColor,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  @override
  CResult<int> rowCellsGetBgColorArgb(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .bgColor,
      _outColorRgb.cast(),
    );
    final color = _outColorRgb.ref;
    return (result, 0xFF000000 | (color.r << 16) | (color.g << 8) | color.b);
  }

  @override
  CResult<int> rowCellsGetFgColorArgb(int cells) {
    final result = ghostty_render_state_row_cells_get(
      Pointer.fromAddress(cells),
      .fgColor,
      _outColorRgb.cast(),
    );
    final color = _outColorRgb.ref;
    return (result, 0xFF000000 | (color.r << 16) | (color.g << 8) | color.b);
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
    final result = ghostty_cell_get(cell, .styleId, _outU16.cast());
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
    final result = ghostty_cell_get(cell, .colorPalette, _outU8.cast());
    return (result, _outU8.value);
  }

  @override
  CResult<RgbColor> cellGetColorRgb(int cell) {
    return using((arena) {
      final out = arena<ColorRgb>();
      final result = ghostty_cell_get(cell, .colorRgb, out.cast());
      return (result, RgbColor(out.ref.r, out.ref.g, out.ref.b));
    });
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
    final result = ghostty_row_get(row, .semanticPrompt, _outI32.cast());
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
    return using((arena) {
      final outLen = arena<Size>();
      final buf = arena<Char>(8);
      final result = ghostty_focus_encode(event, buf, 8, outLen);
      final len = outLen.value;
      final encoded = len == 0
          ? ''
          : utf8.decode(buf.cast<Uint8>().asTypedList(len));
      return (result, encoded);
    });
  }

  CResult<int> _terminalGetU16(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outU16.cast(),
    );
    return (result, _outU16.value);
  }

  CResult<int> _terminalGetU32(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outU32.cast(),
    );
    return (result, _outU32.value);
  }

  CResult<int> _terminalGetSize(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outSize.cast(),
    );
    return (result, _outSize.value);
  }

  CResult<String> _terminalGetString(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outGhosttyString.cast(),
    );
    final ptr = _outGhosttyString.ref.ptr;
    final len = _outGhosttyString.ref.len;
    if (len == 0 || ptr == nullptr) return (result, '');
    return (result, utf8.decode(ptr.asTypedList(len)));
  }

  Result _terminalSetString(int handle, TerminalOption option, String? value) {
    if (value == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    return using((arena) {
      final encoded = utf8.encode(value);
      final strPtr = arena<native.String>();
      final bytesPtr = arena<Uint8>(encoded.length);
      bytesPtr.asTypedList(encoded.length).setAll(0, encoded);
      strPtr.ref.ptr = bytesPtr;
      strPtr.ref.len = encoded.length;
      return ghostty_terminal_set(
        Pointer.fromAddress(handle),
        option,
        strPtr.cast(),
      );
    });
  }

  CResult<bool> _terminalGetBool(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  CResult<int> _terminalGetU64(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  CResult<Style> _terminalGetStyle(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outStyle.cast(),
    );
    return (result, _readNativeStyle(_outStyle.ref));
  }

  Result _terminalSetBool(int handle, TerminalOption option, bool? value) {
    if (value == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    _outBool.value = value;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      _outBool.cast(),
    );
  }

  Result _terminalSetU64(int handle, TerminalOption option, int? value) {
    if (value == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    _outU64.value = value;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      _outU64.cast(),
    );
  }

  CResult<RgbColor> _terminalGetColor(int handle, TerminalData data) {
    final result = ghostty_terminal_get(
      Pointer.fromAddress(handle),
      data,
      _outColorRgb.cast(),
    );
    return (
      result,
      RgbColor(_outColorRgb.ref.r, _outColorRgb.ref.g, _outColorRgb.ref.b),
    );
  }

  CResult<List<RgbColor>> _terminalGetPalette(int handle, TerminalData data) {
    return using((arena) {
      final ptr = arena<ColorRgb>(256);
      final result = ghostty_terminal_get(
        Pointer.fromAddress(handle),
        data,
        ptr.cast(),
      );

      if (result != .success) return (result, const <RgbColor>[]);

      return (
        result,
        <RgbColor>[
          for (var i = 0; i < 256; i++) RgbColor(ptr[i].r, ptr[i].g, ptr[i].b),
        ],
      );
    });
  }

  Result _terminalSetColor(int handle, TerminalOption option, RgbColor? color) {
    if (color == null) {
      return ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
    }
    _outColorRgb.ref.r = color.r;
    _outColorRgb.ref.g = color.g;
    _outColorRgb.ref.b = color.b;
    return ghostty_terminal_set(
      Pointer.fromAddress(handle),
      option,
      _outColorRgb.cast(),
    );
  }

  CResult<int> _renderStateGetU16(int state, RenderStateData data) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      data,
      _outU16.cast(),
    );
    return (result, _outU16.value);
  }

  CResult<bool> _renderStateGetBool(int state, RenderStateData data) {
    final result = ghostty_render_state_get(
      Pointer.fromAddress(state),
      data,
      _outBool.cast(),
    );
    return (result, _outBool.value);
  }

  CResult<int> _cellGetU32(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outU32.cast());
    return (result, _outU32.value);
  }

  CResult<int> _cellGetI32(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outI32.cast());
    return (result, _outI32.value);
  }

  CResult<bool> _cellGetBool(int cell, CellData data) {
    final result = ghostty_cell_get(cell, data, _outBool.cast());
    return (result, _outBool.value);
  }

  CResult<bool> _rowGetBool(int row, RowData data) {
    final result = ghostty_row_get(row, data, _outBool.cast());
    return (result, _outBool.value);
  }

  String? _extractWindowTitle(OscCommand commandPtr) {
    return using((arena) {
      final outPtr = arena<Pointer<Char>>();
      final success = ghostty_osc_command_data(
        commandPtr,
        OscCommandData.changeWindowTitleStr,
        outPtr.cast(),
      );
      if (!success) return null;
      final charPtr = outPtr.value;
      if (charPtr == nullptr) return null;
      return charPtr.cast<Utf8>().toDartString();
    });
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

  static RawColor _readNativeColor(StyleColor c) => (
    tag: StyleColorTag.fromValue(c.tag.value),
    palette: c.value.palette,
    r: c.value.rgb.r,
    g: c.value.rgb.g,
    b: c.value.rgb.b,
  );

  static void _writeNativeColor(StyleColor ref, RawColor color) {
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
    final result = ghostty_build_info(data, _outSize.cast());
    return (result, _outSize.value);
  }

  @override
  CResult<bool> buildInfoBool(BuildInfo data) {
    final result = ghostty_build_info(data, _outBool.cast());
    return (result, _outBool.value);
  }

  @override
  CResult<String> buildInfoString(BuildInfo data) {
    final result = ghostty_build_info(data, _outGhosttyString.cast());
    final ptr = _outGhosttyString.ref.ptr;
    final len = _outGhosttyString.ref.len;
    if (len == 0 || ptr == nullptr) return (result, '');
    return (result, utf8.decode(ptr.asTypedList(len)));
  }

  @override
  CResult<String> modeReportEncode(int mode, ModeReportState state) {
    return using((arena) {
      final outLen = arena<Size>();
      final buf = arena<Char>(64);
      final result = ghostty_mode_report_encode(mode, state, buf, 64, outLen);
      final len = outLen.value;
      final encoded = len == 0
          ? ''
          : utf8.decode(buf.cast<Uint8>().asTypedList(len));
      return (result, encoded);
    });
  }

  @override
  CResult<String> sizeReportEncode(
    SizeReportStyle style,
    int rows,
    int columns,
    int cellWidth,
    int cellHeight,
  ) {
    return using((arena) {
      final size = arena<SizeReportSize>();
      final outLen = arena<Size>();
      final buf = arena<Char>(64);
      size.ref.rows = rows;
      size.ref.columns = columns;
      size.ref.cell_width = cellWidth;
      size.ref.cell_height = cellHeight;
      final result = ghostty_size_report_encode(
        style,
        size.ref,
        buf,
        64,
        outLen,
      );
      final len = outLen.value;
      final encoded = len == 0
          ? ''
          : utf8.decode(buf.cast<Uint8>().asTypedList(len));
      return (result, encoded);
    });
  }

  @override
  Style styleDefault() {
    return using((arena) {
      final style = arena<native.Style>();
      style.ref.size = sizeOf<native.Style>();
      ghostty_style_default(style);
      return _readNativeStyle(style.ref);
    });
  }

  @override
  bool styleIsDefault(Style style) {
    return using((arena) {
      final s = arena<native.Style>();
      s.ref.size = sizeOf<native.Style>();
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
      return ghostty_style_is_default(s);
    });
  }

  @override
  CResult<int> terminalGridRef(int terminal, PointTag pointTag, int x, int y) {
    return using((arena) {
      final point = arena<Point>();
      point.ref.tagAsInt = pointTag.value;
      point.ref.value.coordinate.x = x;
      point.ref.value.coordinate.y = y;
      final gridRef = calloc<GridRef>();
      gridRef.ref.size = sizeOf<GridRef>();
      final result = ghostty_terminal_grid_ref(
        Pointer.fromAddress(terminal),
        point.ref,
        gridRef,
      );
      return (result, gridRef.address);
    });
  }

  @override
  void gridRefFree(int ref) {
    calloc.free(Pointer<Void>.fromAddress(ref));
  }

  @override
  CResult<int> gridRefCell(int ref) {
    final result = ghostty_grid_ref_cell(
      Pointer.fromAddress(ref),
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<int> gridRefRow(int ref) {
    final result = ghostty_grid_ref_row(
      Pointer.fromAddress(ref),
      _outU64.cast(),
    );
    return (result, _outU64.value);
  }

  @override
  CResult<Style> gridRefStyle(int ref) {
    _outStyle.ref.size = sizeOf<native.Style>();
    final result = ghostty_grid_ref_style(Pointer.fromAddress(ref), _outStyle);
    return (result, _readNativeStyle(_outStyle.ref));
  }

  @override
  CResult<List<int>> gridRefGraphemes(int ref) {
    return using((arena) {
      final outLen = arena<Size>();
      var result = ghostty_grid_ref_graphemes(
        Pointer.fromAddress(ref),
        _graphemeBuf,
        32,
        outLen,
      );
      var len = outLen.value;

      if (result == Result.outOfSpace) {
        final bigBuf = arena<Uint32>(len);
        result = ghostty_grid_ref_graphemes(
          Pointer.fromAddress(ref),
          bigBuf,
          len,
          outLen,
        );
        len = outLen.value;
        return (result, [for (var i = 0; i < len; i++) bigBuf[i]]);
      }

      return (result, [for (var i = 0; i < len; i++) _graphemeBuf[i]]);
    });
  }

  @override
  CResult<String> gridRefHyperlinkUri(int ref) {
    return using((arena) {
      final gridRef = Pointer<GridRef>.fromAddress(ref);
      final outLen = arena<Size>();
      var buf = arena<Uint8>(256);
      var result = ghostty_grid_ref_hyperlink_uri(gridRef, buf, 256, outLen);
      var len = outLen.value;

      if (result == Result.outOfSpace) {
        buf = arena<Uint8>(len);
        result = ghostty_grid_ref_hyperlink_uri(gridRef, buf, len, outLen);
        len = outLen.value;
      }

      if (len == 0) return (result, '');
      return (result, utf8.decode(buf.asTypedList(len)));
    });
  }

  @override
  CResult<({int col, int row})> terminalPointFromGridRef(
    int terminal,
    int ref,
    PointTag pointTag,
  ) {
    return using((arena) {
      final out = arena<PointCoordinate>();
      final result = ghostty_terminal_point_from_grid_ref(
        Pointer.fromAddress(terminal),
        Pointer<GridRef>.fromAddress(ref),
        pointTag,
        out,
      );
      return (result, (col: out.ref.x, row: out.ref.y));
    });
  }

  @override
  CResult<int> formatterTerminalNew(
    int terminal,
    FormatterFormat format, {
    bool unwrap = false,
    bool trim = false,
    FormatterExtra extra = const FormatterExtra(),
  }) {
    return using((arena) {
      final ptr = arena<Pointer<FormatterImpl>>();
      final opts = arena<FormatterTerminalOptions>();
      opts.ref
        ..size = sizeOf<FormatterTerminalOptions>()
        ..emitAsInt = format.value
        ..unwrap = unwrap
        ..trim = trim;

      opts.ref.extra
        ..size = sizeOf<FormatterTerminalExtra>()
        ..palette = extra.palette
        ..modes = extra.modes
        ..scrolling_region = extra.scrollingRegion
        ..tabstops = extra.tabstops
        ..pwd = extra.pwd
        ..keyboard = extra.keyboard;

      opts.ref.extra.screen
        ..size = sizeOf<FormatterScreenExtra>()
        ..cursor = extra.cursor
        ..style = extra.style
        ..hyperlink = extra.hyperlink
        ..protection = extra.protection
        ..kitty_keyboard = extra.kittyKeyboard
        ..charsets = extra.charsets;

      final result = ghostty_formatter_terminal_new(
        nullptr,
        ptr.cast(),
        Pointer.fromAddress(terminal),
        opts.ref,
      );
      return (result, ptr.value.address);
    });
  }

  @override
  void formatterFree(int formatter) {
    ghostty_formatter_free(Pointer.fromAddress(formatter));
  }

  @override
  CResult<String> formatterFormat(int formatter) {
    return using((arena) {
      final outPtr = arena<Pointer<Uint8>>();
      final outLen = arena<Size>();
      final result = ghostty_formatter_format_alloc(
        Pointer.fromAddress(formatter),
        nullptr,
        outPtr,
        outLen,
      );
      final len = outLen.value;
      final buf = outPtr.value;
      if (len == 0 || buf == nullptr) return (result, '');
      final encoded = utf8.decode(buf.cast<Uint8>().asTypedList(len));
      ghostty_free(nullptr, buf, len);
      return (result, encoded);
    });
  }

  @override
  void terminalSetOnWritePty(int handle, ValueSetter<Uint8List>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.writePty]?.close();

    if (callback == null) {
      map.remove(TerminalOption.writePty);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.writePty,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<
          Void Function(Terminal, Pointer<Void>, Pointer<Uint8>, Size)
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<Uint8> data,
          int len,
        ) {
          try {
            callback(Uint8List.fromList(data.asTypedList(len)));
          } on Object catch (_) {}
        });
    map[TerminalOption.writePty] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.writePty,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnBell(int handle, VoidCallback? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.bell]?.close();

    if (callback == null) {
      map.remove(TerminalOption.bell);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.bell,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<Void Function(Terminal, Pointer<Void>)>.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
        ) {
          try {
            callback();
          } on Object catch (_) {}
        });
    map[TerminalOption.bell] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.bell,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnTitleChanged(int handle, VoidCallback? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.titleChanged]?.close();

    if (callback == null) {
      map.remove(TerminalOption.titleChanged);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.titleChanged,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<Void Function(Terminal, Pointer<Void>)>.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
        ) {
          try {
            callback();
          } on Object catch (_) {}
        });
    map[TerminalOption.titleChanged] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.titleChanged,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnEnquiry(int handle, ValueGetter<Uint8List>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.enquiry]?.close();

    if (callback == null) {
      map.remove(TerminalOption.enquiry);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.enquiry,
        nullptr,
      );
      return;
    }

    final bufMap = _stringBuffers.putIfAbsent(handle, () => {});
    final strPtr =
        bufMap[TerminalOption.enquiry]?.str ?? calloc<native.String>();
    bufMap[TerminalOption.enquiry] = (
      str: strPtr,
      data: bufMap[TerminalOption.enquiry]?.data ?? nullptr.cast<Uint8>(),
    );

    final callable =
        NativeCallable<
          native.String Function(Terminal, Pointer<Void>)
        >.isolateLocal((Terminal terminal, Pointer<Void> userdata) {
          try {
            final bytes = callback();
            final current = bufMap[TerminalOption.enquiry]!;
            if (current.data != nullptr) calloc.free(current.data);
            final dataPtr = calloc<Uint8>(bytes.length);
            dataPtr.asTypedList(bytes.length).setAll(0, bytes);
            bufMap[TerminalOption.enquiry] = (str: strPtr, data: dataPtr);
            strPtr.ref.ptr = dataPtr;
            strPtr.ref.len = bytes.length;
            return strPtr.ref;
          } on Object catch (_) {
            strPtr.ref.ptr = nullptr;
            strPtr.ref.len = 0;
            return strPtr.ref;
          }
        });
    map[TerminalOption.enquiry] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.enquiry,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnXtversion(int handle, ValueGetter<String>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.xtversion]?.close();

    if (callback == null) {
      map.remove(TerminalOption.xtversion);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.xtversion,
        nullptr,
      );
      return;
    }

    final bufMap = _stringBuffers.putIfAbsent(handle, () => {});
    final strPtr =
        bufMap[TerminalOption.xtversion]?.str ?? calloc<native.String>();
    bufMap[TerminalOption.xtversion] = (
      str: strPtr,
      data: bufMap[TerminalOption.xtversion]?.data ?? nullptr.cast<Uint8>(),
    );

    final callable =
        NativeCallable<
          native.String Function(Terminal, Pointer<Void>)
        >.isolateLocal((Terminal terminal, Pointer<Void> userdata) {
          try {
            final result = callback();
            final bytes = utf8.encode(result);
            final current = bufMap[TerminalOption.xtversion]!;
            if (current.data != nullptr) calloc.free(current.data);
            final dataPtr = calloc<Uint8>(bytes.length);
            dataPtr.asTypedList(bytes.length).setAll(0, bytes);
            bufMap[TerminalOption.xtversion] = (str: strPtr, data: dataPtr);
            strPtr.ref.ptr = dataPtr;
            strPtr.ref.len = bytes.length;
            return strPtr.ref;
          } on Object catch (_) {
            strPtr.ref.ptr = nullptr;
            strPtr.ref.len = 0;
            return strPtr.ref;
          }
        });
    map[TerminalOption.xtversion] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.xtversion,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnColorScheme(
    int handle,
    ValueGetter<ColorScheme?>? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.colorScheme]?.close();

    if (callback == null) {
      map.remove(TerminalOption.colorScheme);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.colorScheme,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<
          Bool Function(Terminal, Pointer<Void>, Pointer<UnsignedInt>)
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<UnsignedInt> outScheme,
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
    map[TerminalOption.colorScheme] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.colorScheme,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnSize(int handle, ValueGetter<TerminalSizeInfo?>? callback) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.size]?.close();

    if (callback == null) {
      map.remove(TerminalOption.size);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.size,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<
          Bool Function(Terminal, Pointer<Void>, Pointer<SizeReportSize>)
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<SizeReportSize> outSize,
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
    map[TerminalOption.size] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.size,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalSetOnDeviceAttributes(
    int handle,
    ValueGetter<DeviceAttributesResponse?>? callback,
  ) {
    final map = _callables.putIfAbsent(handle, () => {});
    map[TerminalOption.deviceAttributes]?.close();

    if (callback == null) {
      map.remove(TerminalOption.deviceAttributes);
      ghostty_terminal_set(
        Pointer.fromAddress(handle),
        TerminalOption.deviceAttributes,
        nullptr,
      );
      return;
    }

    final callable =
        NativeCallable<
          Bool Function(Terminal, Pointer<Void>, Pointer<DeviceAttributes>)
        >.isolateLocal((
          Terminal terminal,
          Pointer<Void> userdata,
          Pointer<DeviceAttributes> outAttrs,
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
    map[TerminalOption.deviceAttributes] = callable;
    ghostty_terminal_set(
      Pointer.fromAddress(handle),
      TerminalOption.deviceAttributes,
      callable.nativeFunction.cast(),
    );
  }

  @override
  void terminalDisposeCallbacks(int handle) {
    if (_callables.remove(handle) case Map(:final keys, :final values)) {
      for (final option in keys) {
        ghostty_terminal_set(Pointer.fromAddress(handle), option, nullptr);
      }
      for (final c in values) {
        c.close();
      }
    }

    if (_stringBuffers.remove(handle) case Map(:final values)) {
      for (final buf in values) {
        if (buf.data != nullptr) calloc.free(buf.data);
        calloc.free(buf.str);
      }
    }
  }
}
