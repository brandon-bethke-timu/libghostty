/// Terminal emulation powered by libghostty.
///
/// ```dart
/// import 'package:libghostty/libghostty.dart';
/// ```
library;

export 'src/bindings/bindings.dart' show initializeForWeb;
export 'src/bindings/types/types.dart'
    show
        CellColor,
        CellWidth,
        CursorShape,
        DefaultColor,
        DeviceAttributesPrimary,
        DeviceAttributesResponse,
        DeviceAttributesSecondary,
        DeviceAttributesTertiary,
        FormatterExtra,
        InvalidValueException,
        LibGhosttyException,
        MouseEncoderSize,
        MouseFormat,
        MouseTracking,
        NamedColor,
        OptimizeMode,
        OutOfMemoryException,
        PaletteColor,
        RgbColor,
        Scrollbar,
        SemanticContent,
        SemanticPrompt,
        SgrAttribute,
        Style,
        TerminalColors,
        TerminalSizeInfo,
        UnderlineStyle;
export 'src/ffi/libghostty_enums.g.dart'
    show
        ColorScheme,
        FocusEvent,
        FormatterFormat,
        Key,
        KeyAction,
        KittyImageCompression,
        KittyImageFormat,
        KittyPlacementLayer,
        ModeReportState,
        MouseAction,
        MouseButton,
        OptionAsAlt,
        OscCommandType,
        PointTag,
        SgrAttributeTag,
        SizeReportStyle,
        SysLogLevel,
        TerminalScreen;
export 'src/impl/build_info.dart' show LibGhosttyBuildInfo;
export 'src/impl/encode.dart' show FocusEventEncode, SizeReportStyleEncode;
export 'src/impl/key/key_encoder.dart' show KeyEncoder;
export 'src/impl/key/key_event.dart' show KeyEvent;
export 'src/impl/key/kitty_key_flags.dart' show KittyKeyFlags;
export 'src/impl/key/mods.dart' show Mods;
export 'src/impl/mouse/mouse_encoder.dart' show MouseEncoder;
export 'src/impl/mouse/mouse_event.dart' show MouseEvent;
export 'src/impl/osc_parser.dart' show OscCommand, OscParser;
export 'src/impl/paste.dart' show pasteEncode, pasteIsSafe;
export 'src/impl/sgr_parser.dart' show SgrParser;
export 'src/impl/sys.dart' show LibGhostty, LogCallback;
export 'src/impl/terminal/terminal.dart'
    show
        Cell,
        Cursor,
        DirtyState,
        Formatter,
        GridRef,
        KittyGraphics,
        KittyImage,
        Placement,
        RenderInfo,
        RenderState,
        Row,
        Selection,
        Terminal;
export 'src/impl/terminal/terminal_mode.dart' show TerminalMode;
export 'src/listenable.dart' show Listenable;
