/// Precomputed C struct sizes and field offsets for WASM32.
///
/// Parsed once from [ghostty_type_json] at initialization. All fields
/// are final ints resolved from the JSON, so method calls use direct
/// field access with no map lookups.
class Layouts {
  // GhosttyColorRgb
  late final int colorRgbSize;
  late final int colorRgbG;
  late final int colorRgbB;

  // GhosttyDeviceAttributes
  late final int deviceAttrsFeatures;
  late final int deviceAttrsNumFeatures;
  late final int deviceAttrsDeviceType;
  late final int deviceAttrsFirmwareVersion;
  late final int deviceAttrsRomCartridge;
  late final int deviceAttrsUnitId;

  // GhosttyFormatterTerminalOptions
  late final int formatterOptsSize;
  late final int formatterOptsFormat;
  late final int formatterOptsUnwrap;
  late final int formatterOptsTrim;
  late final int formatterOptsExtra;
  late final int formatterOptsSelection;

  // GhosttyFormatterTerminalExtra
  late final int formatterTermExtraSize;
  late final int formatterTermExtraPalette;
  late final int formatterTermExtraModes;
  late final int formatterTermExtraScrollingRegion;
  late final int formatterTermExtraTabstops;
  late final int formatterTermExtraPwd;
  late final int formatterTermExtraKeyboard;
  late final int formatterTermExtraScreen;

  // GhosttyFormatterScreenExtra
  late final int formatterScreenExtraSize;
  late final int formatterScreenExtraCursor;
  late final int formatterScreenExtraStyle;
  late final int formatterScreenExtraHyperlink;
  late final int formatterScreenExtraProtection;
  late final int formatterScreenExtraKittyKeyboard;
  late final int formatterScreenExtraCharsets;

  // GhosttySelection
  late final int selectionSize;
  late final int selectionStart;
  late final int selectionEnd;
  late final int selectionRectangle;

  // GhosttyGridRef
  late final int gridRefSize;

  // GhosttyKittyGraphicsPlacementRenderInfo
  late final int kittyRenderInfoSize;
  late final int kittyRenderInfoPixelWidth;
  late final int kittyRenderInfoPixelHeight;
  late final int kittyRenderInfoGridCols;
  late final int kittyRenderInfoGridRows;
  late final int kittyRenderInfoViewportCol;
  late final int kittyRenderInfoViewportRow;
  late final int kittyRenderInfoViewportVisible;
  late final int kittyRenderInfoSourceX;
  late final int kittyRenderInfoSourceY;
  late final int kittyRenderInfoSourceWidth;
  late final int kittyRenderInfoSourceHeight;

  // GhosttyPointCoordinate
  late final int pointCoordinateSize;
  late final int pointCoordinateX;
  late final int pointCoordinateY;

  // GhosttyMouseEncoderSize
  late final int mouseEncoderSizeSize;
  late final int mouseEncoderSizeScreenWidth;
  late final int mouseEncoderSizeScreenHeight;
  late final int mouseEncoderSizeCellWidth;
  late final int mouseEncoderSizeCellHeight;
  late final int mouseEncoderSizePaddingTop;
  late final int mouseEncoderSizePaddingBottom;
  late final int mouseEncoderSizePaddingRight;
  late final int mouseEncoderSizePaddingLeft;

  // GhosttyMousePosition
  late final int mousePosSize;
  late final int mousePosY;

  // GhosttyPoint
  late final int pointSize;
  late final int pointX;
  late final int pointY;

  // GhosttyRenderStateColors
  late final int colorsSize;
  late final int colorsBg;
  late final int colorsFg;
  late final int colorsCursor;
  late final int colorsCursorHasValue;
  late final int colorsPalette;

  // GhosttySizeReportSize
  late final int sizeReportSize;
  late final int sizeReportColumns;
  late final int sizeReportCellWidth;
  late final int sizeReportCellHeight;

  // GhosttyString
  late final int stringSize;
  late final int stringLen;

  // GhosttyStyle
  late final int styleSize;
  late final int styleFg;
  late final int styleBg;
  late final int styleUnderlineColor;
  late final int styleBold;
  late final int styleItalic;
  late final int styleFaint;
  late final int styleBlink;
  late final int styleInverse;
  late final int styleInvisible;
  late final int styleStrikethrough;
  late final int styleOverline;
  late final int styleUnderline;

  // GhosttyStyleColor
  late final int styleColorR;
  late final int styleColorG;
  late final int styleColorB;

  // GhosttyTerminalOptions
  late final int terminalOptsSize;
  late final int terminalOptsRows;
  late final int terminalOptsMaxScrollback;

  // GhosttyTerminalScrollbar
  late final int scrollbarSize;
  late final int scrollbarOffset;
  late final int scrollbarVisible;

  // GhosttyTerminalScrollViewport
  late final int scrollViewportSize;
  late final int scrollViewportDelta;

  Layouts(Map<String, dynamic> types) {
    var struct = _Struct(types, 'GhosttyColorRgb');
    colorRgbSize = struct.size;
    colorRgbG = struct['g'];
    colorRgbB = struct['b'];

    struct = _Struct(types, 'GhosttyDeviceAttributes');
    final primaryOff = struct['primary'];
    final secondaryOff = struct['secondary'];
    final tertiaryOff = struct['tertiary'];
    var sub = _Struct(types, 'GhosttyDeviceAttributesPrimary');
    deviceAttrsFeatures = primaryOff + sub['features'];
    deviceAttrsNumFeatures = primaryOff + sub['num_features'];
    sub = _Struct(types, 'GhosttyDeviceAttributesSecondary');
    deviceAttrsDeviceType = secondaryOff + sub['device_type'];
    deviceAttrsFirmwareVersion = secondaryOff + sub['firmware_version'];
    deviceAttrsRomCartridge = secondaryOff + sub['rom_cartridge'];
    sub = _Struct(types, 'GhosttyDeviceAttributesTertiary');
    deviceAttrsUnitId = tertiaryOff + sub['unit_id'];

    struct = _Struct(types, 'GhosttyFormatterTerminalOptions');
    formatterOptsSize = struct.size;
    formatterOptsFormat = struct['emit'];
    formatterOptsUnwrap = struct['unwrap'];
    formatterOptsTrim = struct['trim'];
    formatterOptsExtra = struct['extra'];
    formatterOptsSelection = struct['selection'];

    struct = _Struct(types, 'GhosttyFormatterTerminalExtra');
    formatterTermExtraSize = struct.size;
    formatterTermExtraPalette = struct['palette'];
    formatterTermExtraModes = struct['modes'];
    formatterTermExtraScrollingRegion = struct['scrolling_region'];
    formatterTermExtraTabstops = struct['tabstops'];
    formatterTermExtraPwd = struct['pwd'];
    formatterTermExtraKeyboard = struct['keyboard'];
    formatterTermExtraScreen = struct['screen'];

    struct = _Struct(types, 'GhosttyFormatterScreenExtra');
    formatterScreenExtraSize = struct.size;
    formatterScreenExtraCursor = struct['cursor'];
    formatterScreenExtraStyle = struct['style'];
    formatterScreenExtraHyperlink = struct['hyperlink'];
    formatterScreenExtraProtection = struct['protection'];
    formatterScreenExtraKittyKeyboard = struct['kitty_keyboard'];
    formatterScreenExtraCharsets = struct['charsets'];

    struct = _Struct(types, 'GhosttySelection');
    selectionSize = struct.size;
    selectionStart = struct['start'];
    selectionEnd = struct['end'];
    selectionRectangle = struct['rectangle'];

    struct = _Struct(types, 'GhosttyGridRef');
    gridRefSize = struct.size;

    // TODO(elias8): migrate to `_Struct(types, ...)` once upstream ghostty
    // registers `GhosttyKittyGraphicsPlacementRenderInfo` in `types.zig`.
    kittyRenderInfoSize = 48;
    kittyRenderInfoPixelWidth = 4;
    kittyRenderInfoPixelHeight = 8;
    kittyRenderInfoGridCols = 12;
    kittyRenderInfoGridRows = 16;
    kittyRenderInfoViewportCol = 20;
    kittyRenderInfoViewportRow = 24;
    kittyRenderInfoViewportVisible = 28;
    kittyRenderInfoSourceX = 32;
    kittyRenderInfoSourceY = 36;
    kittyRenderInfoSourceWidth = 40;
    kittyRenderInfoSourceHeight = 44;

    struct = _Struct(types, 'GhosttyMouseEncoderSize');
    mouseEncoderSizeSize = struct.size;
    mouseEncoderSizeScreenWidth = struct['screen_width'];
    mouseEncoderSizeScreenHeight = struct['screen_height'];
    mouseEncoderSizeCellWidth = struct['cell_width'];
    mouseEncoderSizeCellHeight = struct['cell_height'];
    mouseEncoderSizePaddingTop = struct['padding_top'];
    mouseEncoderSizePaddingBottom = struct['padding_bottom'];
    mouseEncoderSizePaddingRight = struct['padding_right'];
    mouseEncoderSizePaddingLeft = struct['padding_left'];

    struct = _Struct(types, 'GhosttyMousePosition');
    mousePosSize = struct.size;
    mousePosY = struct['y'];

    struct = _Struct(types, 'GhosttyPoint');
    pointSize = struct.size;
    final valueOff = struct['value'];
    sub = _Struct(types, 'GhosttyPointCoordinate');
    pointX = valueOff + sub['x'];
    pointY = valueOff + sub['y'];
    pointCoordinateSize = sub.size;
    pointCoordinateX = sub['x'];
    pointCoordinateY = sub['y'];

    struct = _Struct(types, 'GhosttyRenderStateColors');
    colorsSize = struct.size;
    colorsBg = struct['background'];
    colorsFg = struct['foreground'];
    colorsCursor = struct['cursor'];
    colorsCursorHasValue = struct['cursor_has_value'];
    colorsPalette = struct['palette'];

    struct = _Struct(types, 'GhosttySizeReportSize');
    sizeReportSize = struct.size;
    sizeReportColumns = struct['columns'];
    sizeReportCellWidth = struct['cell_width'];
    sizeReportCellHeight = struct['cell_height'];

    struct = _Struct(types, 'GhosttyString');
    stringSize = struct.size;
    stringLen = struct['len'];

    struct = _Struct(types, 'GhosttyStyle');
    styleSize = struct.size;
    styleFg = struct['fg_color'];
    styleBg = struct['bg_color'];
    styleUnderlineColor = struct['underline_color'];
    styleBold = struct['bold'];
    styleItalic = struct['italic'];
    styleFaint = struct['faint'];
    styleBlink = struct['blink'];
    styleInverse = struct['inverse'];
    styleInvisible = struct['invisible'];
    styleStrikethrough = struct['strikethrough'];
    styleOverline = struct['overline'];
    styleUnderline = struct['underline'];

    struct = _Struct(types, 'GhosttyStyleColor');
    final scValueOff = struct['value'];
    sub = _Struct(types, 'GhosttyColorRgb');
    styleColorR = scValueOff + sub['r'];
    styleColorG = scValueOff + sub['g'];
    styleColorB = scValueOff + sub['b'];

    struct = _Struct(types, 'GhosttyTerminalOptions');
    terminalOptsSize = struct.size;
    terminalOptsRows = struct['rows'];
    terminalOptsMaxScrollback = struct['max_scrollback'];

    struct = _Struct(types, 'GhosttyTerminalScrollbar');
    scrollbarSize = struct.size;
    scrollbarOffset = struct['offset'];
    scrollbarVisible = struct['len'];

    struct = _Struct(types, 'GhosttyTerminalScrollViewport');
    scrollViewportSize = struct.size;
    scrollViewportDelta = struct['value'];
  }
}

/// Typed accessor for a single struct's layout from the JSON.
class _Struct {
  final int size;
  final Map<String, dynamic> _fields;

  _Struct(Map<String, dynamic> types, String name)
    : size = (types[name] as Map<String, dynamic>)['size'] as int,
      _fields =
          (types[name] as Map<String, dynamic>)['fields']
              as Map<String, dynamic>;

  int operator [](String field) {
    return (_fields[field] as Map<String, dynamic>)['offset'] as int;
  }
}
