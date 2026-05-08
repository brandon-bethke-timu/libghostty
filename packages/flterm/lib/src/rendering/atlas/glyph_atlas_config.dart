import 'dart:ui' show FontWeight;

import 'package:meta/meta.dart';

import '../../foundation.dart';

@immutable
class GlyphAtlasConfig {
  final double fontSize;
  final String fontFamily;
  final FontWeight fontWeight;
  final List<String> fontFamilyFallback;
  final CellMetrics metrics;
  final double devicePixelRatio;

  GlyphAtlasConfig({
    required this.fontSize,
    required this.fontFamily,
    required this.fontWeight,
    required List<String> fontFamilyFallback,
    required this.metrics,
    required this.devicePixelRatio,
  }) : fontFamilyFallback = .unmodifiable(fontFamilyFallback);

  factory GlyphAtlasConfig.fromTheme({
    required TerminalTheme theme,
    required CellMetrics metrics,
    required double devicePixelRatio,
  }) {
    return GlyphAtlasConfig(
      fontSize: theme.fontSize,
      fontWeight: theme.fontWeight,
      fontFamily: theme.fontFamily,
      fontFamilyFallback: theme.fontFamilyFallback,
      metrics: metrics,
      devicePixelRatio: devicePixelRatio,
    );
  }

  @override
  int get hashCode => Object.hash(
    fontSize,
    fontWeight,
    fontFamily,
    Object.hashAll(fontFamilyFallback),
    metrics,
    devicePixelRatio,
  );

  @override
  bool operator ==(Object other) =>
      other is GlyphAtlasConfig &&
      other.fontSize == fontSize &&
      other.fontWeight == fontWeight &&
      other.fontFamily == fontFamily &&
      _listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
      other.metrics == metrics &&
      other.devicePixelRatio == devicePixelRatio;

  GlyphAtlasConfig copyWith({
    double? fontSize,
    FontWeight? fontWeight,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    CellMetrics? metrics,
    double? devicePixelRatio,
  }) {
    return GlyphAtlasConfig(
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontFamily: fontFamily ?? this.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? this.fontFamilyFallback,
      metrics: metrics ?? this.metrics,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
