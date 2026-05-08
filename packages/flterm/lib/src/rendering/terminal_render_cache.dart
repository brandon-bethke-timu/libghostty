import 'dart:ui' show FontWeight;

import 'package:meta/meta.dart';

import '../foundation.dart';
import 'atlas/glyph_atlas.dart';

class TerminalGlyphAtlasHandle {
  final TerminalRenderCache _owner;
  final TerminalRenderCacheKey key;
  final _GlyphAtlasEntry _entry;
  var _released = false;

  TerminalGlyphAtlasHandle._(this._owner, this.key, this._entry);

  GlyphAtlas get atlas => _entry.atlas;

  void release() {
    if (_released) return;
    _released = true;
    _owner._releaseGlyphAtlas(key, _entry);
  }
}

/// Owns render resources that can be shared by compatible terminal views.
///
/// This type is internal; public sharing is exposed through `TerminalScope`.
class TerminalRenderCache {
  final _glyphAtlases = <TerminalRenderCacheKey, _GlyphAtlasEntry>{};

  TerminalGlyphAtlasHandle acquireGlyphAtlas(TerminalRenderCacheKey key) {
    final entry = _glyphAtlases.putIfAbsent(key, () {
      final atlas = GlyphAtlas(
        fontSize: key.fontSize,
        fontWeight: key.fontWeight,
        fontFamily: key.fontFamily,
        fontFamilyFallback: key.fontFamilyFallback,
      )..configure(dpr: key.devicePixelRatio, metrics: key.metrics);
      return _GlyphAtlasEntry(atlas);
    });
    entry.references++;
    return TerminalGlyphAtlasHandle._(this, key, entry);
  }

  void dispose() {
    for (final entry in _glyphAtlases.values) {
      entry.atlas.dispose();
    }
    _glyphAtlases.clear();
  }

  void _releaseGlyphAtlas(
    TerminalRenderCacheKey key,
    _GlyphAtlasEntry releasedEntry,
  ) {
    final entry = _glyphAtlases[key];
    if (entry == null) return;
    if (!identical(entry, releasedEntry)) return;

    entry.references--;
    if (entry.references > 0) return;

    _glyphAtlases.remove(key);
    entry.atlas.dispose();
  }
}

@immutable
class TerminalRenderCacheKey {
  final double fontSize;
  final FontWeight fontWeight;
  final String fontFamily;
  final List<String> fontFamilyFallback;
  final CellMetrics metrics;
  final double devicePixelRatio;

  TerminalRenderCacheKey({
    required this.fontSize,
    required this.fontWeight,
    required this.fontFamily,
    required List<String> fontFamilyFallback,
    required this.metrics,
    required this.devicePixelRatio,
  }) : fontFamilyFallback = List.unmodifiable(fontFamilyFallback);

  factory TerminalRenderCacheKey.fromTheme({
    required TerminalTheme theme,
    required CellMetrics metrics,
    required double devicePixelRatio,
  }) {
    return TerminalRenderCacheKey(
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
      other is TerminalRenderCacheKey &&
      other.fontSize == fontSize &&
      other.fontWeight == fontWeight &&
      other.fontFamily == fontFamily &&
      _listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
      other.metrics == metrics &&
      other.devicePixelRatio == devicePixelRatio;

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _GlyphAtlasEntry {
  final GlyphAtlas atlas;
  var references = 0;

  _GlyphAtlasEntry(this.atlas);
}
