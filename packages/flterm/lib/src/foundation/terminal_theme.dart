import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:libghostty/libghostty.dart';

import 'color_palette.dart';

const _defaultFontFamilyFallback = [
  'JetBrains Mono',
  'Menlo',
  'Consolas',
  'Ubuntu Mono',
  'DejaVu Sans Mono',
  'Courier New',
];

const _darkAnsiColors = [
  Color(0xFF282828), // 0: black
  Color(0xFFCC4242), // 1: red
  Color(0xFF66994C), // 2: green
  Color(0xFFE5B566), // 3: yellow
  Color(0xFF668ECC), // 4: blue
  Color(0xFFB266B2), // 5: magenta
  Color(0xFF4CB2B2), // 6: cyan
  Color(0xFFAAAAAA), // 7: white
  Color(0xFF505050), // 8: bright black
  Color(0xFFE66464), // 9: bright red
  Color(0xFF8CBE6E), // 10: bright green
  Color(0xFFF0C878), // 11: bright yellow
  Color(0xFF82A0DC), // 12: bright blue
  Color(0xFFC882C8), // 13: bright magenta
  Color(0xFF64C8C8), // 14: bright cyan
  Color(0xFFDCDCDC), // 15: bright white
];

const _lightAnsiColors = [
  Color(0xFF383A42), // 0: black
  Color(0xFFE45649), // 1: red
  Color(0xFF50A14F), // 2: green
  Color(0xFFC18401), // 3: yellow
  Color(0xFF0184BC), // 4: blue
  Color(0xFFA626A4), // 5: magenta
  Color(0xFF0997B3), // 6: cyan
  Color(0xFFA0A1A7), // 7: white
  Color(0xFF4F525E), // 8: bright black
  Color(0xFFE06C75), // 9: bright red
  Color(0xFF98C379), // 10: bright green
  Color(0xFFE5C07B), // 11: bright yellow
  Color(0xFF61AFEF), // 12: bright blue
  Color(0xFFC678DD), // 13: bright magenta
  Color(0xFF56B6C2), // 14: bright cyan
  Color(0xFFFFFFFF), // 15: bright white
];

/// The visual style of the terminal cursor.
///
/// ```dart
/// const cursor = CursorTheme(shape: CursorShape.bar);
/// ```
@immutable
final class CursorTheme {
  /// Cursor shape: block, underline, bar, or block-hollow.
  final CursorShape shape;

  /// Explicit cursor color. When null, defaults to the foreground color.
  final Color? color;

  /// Time between blink state toggles.
  final Duration blinkInterval;

  const CursorTheme({
    this.shape = CursorShape.block,
    this.color,
    this.blinkInterval = const Duration(milliseconds: 600),
  });

  @override
  int get hashCode => Object.hash(shape, color, blinkInterval);

  @override
  bool operator ==(Object other) =>
      other is CursorTheme &&
      other.shape == shape &&
      other.color == color &&
      other.blinkInterval == blinkInterval;

  @override
  String toString() =>
      'CursorTheme(shape: $shape, color: $color, '
      'blinkInterval: $blinkInterval)';

  /// Linearly interpolates between two cursor themes.
  ///
  /// Non-interpolable fields ([shape]) snap at `t >= 0.5`.
  static CursorTheme? lerp(CursorTheme? a, CursorTheme? b, double t) {
    if (identical(a, b)) return a;
    if (a == null || b == null) return t < 0.5 ? a : b;
    return CursorTheme(
      shape: t < 0.5 ? a.shape : b.shape,
      color: Color.lerp(a.color, b.color, t),
      blinkInterval: Duration(
        microseconds: lerpDouble(
          a.blinkInterval.inMicroseconds.toDouble(),
          b.blinkInterval.inMicroseconds.toDouble(),
          t,
        )!.round(),
      ),
    );
  }
}

/// Visual properties for hyperlinks in a single interaction state.
///
/// ```dart
/// const style = HyperlinkStyle(underline: UnderlineStyle.single);
/// ```
@immutable
final class HyperlinkStyle {
  /// Underline decoration for hyperlinked cells.
  ///
  /// Only applied when the cell has no explicit underline of its own.
  final UnderlineStyle underline;

  /// Explicit underline color. When null, the text foreground color is used.
  final Color? underlineColor;

  /// Override text color for hyperlinked cells. When null, the cell's
  /// resolved foreground color is used.
  final Color? textColor;

  const HyperlinkStyle({
    this.underline = .none,
    this.underlineColor,
    this.textColor,
  });

  @override
  int get hashCode => Object.hash(underline, underlineColor, textColor);

  @override
  bool operator ==(Object other) =>
      other is HyperlinkStyle &&
      other.underline == underline &&
      other.underlineColor == underlineColor &&
      other.textColor == textColor;

  @override
  String toString() =>
      'HyperlinkStyle(underline: $underline, '
      'underlineColor: $underlineColor, textColor: $textColor)';

  static HyperlinkStyle? lerp(HyperlinkStyle? a, HyperlinkStyle? b, double t) {
    if (identical(a, b)) return a;
    if (a == null || b == null) return t < 0.5 ? a : b;
    return HyperlinkStyle(
      underline: t < 0.5 ? a.underline : b.underline,
      underlineColor: Color.lerp(a.underlineColor, b.underlineColor, t),
      textColor: Color.lerp(a.textColor, b.textColor, t),
    );
  }
}

/// Hyperlink appearance for idle and highlighted states.
///
/// ```dart
/// const theme = HyperlinkTheme(
///   highlighted: HyperlinkStyle(underline: UnderlineStyle.single),
/// );
/// ```
@immutable
final class HyperlinkTheme {
  /// Appearance when the hyperlink is not highlighted.
  final HyperlinkStyle idle;

  /// Appearance when the user Cmd+hovers over the hyperlink.
  final HyperlinkStyle highlighted;

  const HyperlinkTheme({
    this.idle = const HyperlinkStyle(),
    this.highlighted = const HyperlinkStyle(underline: .single),
  });

  @override
  int get hashCode => Object.hash(idle, highlighted);

  @override
  bool operator ==(Object other) =>
      other is HyperlinkTheme &&
      other.idle == idle &&
      other.highlighted == highlighted;

  @override
  String toString() => 'HyperlinkTheme(idle: $idle, highlighted: $highlighted)';

  static HyperlinkTheme? lerp(HyperlinkTheme? a, HyperlinkTheme? b, double t) {
    if (identical(a, b)) return a;
    if (a == null || b == null) return t < 0.5 ? a : b;
    return HyperlinkTheme(
      idle: HyperlinkStyle.lerp(a.idle, b.idle, t)!,
      highlighted: HyperlinkStyle.lerp(a.highlighted, b.highlighted, t)!,
    );
  }
}

/// Visual configuration for a terminal: colors, cursor, font, and palette.
///
/// ```dart
/// final theme = TerminalTheme.dark();
/// final fg = theme.resolveColor(cell.foreground, isForeground: true);
/// ```
@immutable
final class TerminalTheme {
  /// Default foreground color when a cell uses [DefaultColor].
  final Color foreground;

  /// Default background color when a cell uses [DefaultColor].
  final Color background;

  /// The resolved 256-color palette.
  final ColorPalette palette;

  /// Cursor appearance settings.
  final CursorTheme cursor;

  /// Hyperlink appearance for idle and Cmd+hover states.
  final HyperlinkTheme hyperlink;

  /// Font family name for rendering terminal text.
  final String fontFamily;

  /// Fallback font families tried when a glyph is missing from [fontFamily].
  ///
  /// Defaults to a cross-platform monospace chain (JetBrains Mono, Menlo,
  /// Consolas, Ubuntu Mono, DejaVu Sans Mono, Courier New).
  final List<String> fontFamilyFallback;

  /// Font size in logical pixels.
  final double fontSize;

  /// Selection highlight color.
  final Color selectionColor;

  /// [ansiColors] must contain exactly 16 entries. The full 256-color palette
  /// is auto-generated via CIELAB-based interpolation.
  TerminalTheme({
    required this.foreground,
    required this.background,
    required List<Color> ansiColors,
    this.cursor = const CursorTheme(),
    this.hyperlink = const HyperlinkTheme(),
    this.fontSize = 14.0,
    this.fontFamily = 'JetBrains Mono',
    this.fontFamilyFallback = _defaultFontFamilyFallback,
    this.selectionColor = const Color(0x3D7AA2F7),
  }) : assert(fontSize > 0, 'fontSize must be positive'),
       palette = .fromAnsiColors(
         ansiColors: ansiColors,
         background: background,
         foreground: foreground,
       );

  /// A dark-background terminal theme.
  factory TerminalTheme.dark() => TerminalTheme(
    foreground: const Color(0xFFD8D8D8),
    background: const Color(0xFF181818),
    ansiColors: _darkAnsiColors,
  );

  /// A light-background terminal theme.
  factory TerminalTheme.light() => TerminalTheme(
    foreground: const Color(0xFF383A42),
    background: const Color(0xFFFAFAFA),
    ansiColors: _lightAnsiColors,
  );

  const TerminalTheme._withPalette({
    required this.foreground,
    required this.background,
    required this.palette,
    required this.cursor,
    required this.fontSize,
    required this.hyperlink,
    required this.fontFamily,
    required this.fontFamilyFallback,
    required this.selectionColor,
  });

  @override
  int get hashCode => Object.hash(
    foreground,
    background,
    palette,
    cursor,
    hyperlink,
    fontSize,
    fontFamily,
    Object.hashAll(fontFamilyFallback),
    selectionColor,
  );

  @override
  bool operator ==(Object other) =>
      other is TerminalTheme &&
      other.foreground == foreground &&
      other.background == background &&
      other.palette == palette &&
      other.cursor == cursor &&
      other.hyperlink == hyperlink &&
      other.fontSize == fontSize &&
      other.fontFamily == fontFamily &&
      listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
      other.selectionColor == selectionColor;

  /// Returns a copy of this theme with the given fields replaced.
  TerminalTheme copyWith({
    Color? foreground,
    Color? background,
    List<Color>? ansiColors,
    CursorTheme? cursor,
    HyperlinkTheme? hyperlink,
    double? fontSize,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    Color? selectionColor,
  }) {
    final newForeground = foreground ?? this.foreground;
    final newBackground = background ?? this.background;
    final regenerate =
        ansiColors != null ||
        newForeground != this.foreground ||
        newBackground != this.background;

    if (regenerate) {
      return TerminalTheme(
        foreground: newForeground,
        background: newBackground,
        cursor: cursor ?? this.cursor,
        hyperlink: hyperlink ?? this.hyperlink,
        fontSize: fontSize ?? this.fontSize,
        fontFamily: fontFamily ?? this.fontFamily,
        fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
        selectionColor: selectionColor ?? this.selectionColor,
        ansiColors: ansiColors ?? List<Color>.generate(16, (i) => palette[i]),
      );
    }

    return TerminalTheme._withPalette(
      palette: palette,
      foreground: newForeground,
      background: newBackground,
      cursor: cursor ?? this.cursor,
      hyperlink: hyperlink ?? this.hyperlink,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      selectionColor: selectionColor ?? this.selectionColor,
    );
  }

  /// Resolves a [CellColor] from the core package to a Flutter [Color].
  ///
  /// When [isForeground] is true, [DefaultColor] resolves to [foreground];
  /// otherwise it resolves to [background].
  Color resolveColor(CellColor color, {required bool isForeground}) {
    return switch (color) {
      DefaultColor() => isForeground ? foreground : background,
      RgbColor(:final r, :final g, :final b) => Color.fromARGB(255, r, g, b),
    };
  }

  @override
  String toString() =>
      'TerminalTheme(foreground: $foreground, '
      'background: $background, fontFamily: $fontFamily, fontSize: $fontSize)';

  /// Linearly interpolates between two terminal themes.
  ///
  /// Non-interpolable fields ([fontFamily]) snap at `t >= 0.5`.
  static TerminalTheme? lerp(TerminalTheme? a, TerminalTheme? b, double t) {
    if (identical(a, b)) return a;
    if (a == null || b == null) return t < 0.5 ? a : b;
    return TerminalTheme._withPalette(
      foreground: Color.lerp(a.foreground, b.foreground, t)!,
      background: Color.lerp(a.background, b.background, t)!,
      palette: ColorPalette.lerp(a.palette, b.palette, t)!,
      cursor: CursorTheme.lerp(a.cursor, b.cursor, t)!,
      hyperlink: HyperlinkTheme.lerp(a.hyperlink, b.hyperlink, t)!,
      fontSize: lerpDouble(a.fontSize, b.fontSize, t)!,
      fontFamily: t < 0.5 ? a.fontFamily : b.fontFamily,
      fontFamilyFallback: t < 0.5 ? a.fontFamilyFallback : b.fontFamilyFallback,
      selectionColor: Color.lerp(a.selectionColor, b.selectionColor, t)!,
    );
  }
}
