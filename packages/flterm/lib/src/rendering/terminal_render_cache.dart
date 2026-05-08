import 'atlas/glyph_atlas.dart';

class TerminalGlyphAtlasHandle {
  final TerminalRenderCache _owner;
  final GlyphAtlasConfig config;
  final _GlyphAtlasEntry _entry;
  var _released = false;

  TerminalGlyphAtlasHandle._(this._owner, this.config, this._entry);

  GlyphAtlas get atlas => _entry.atlas;

  void release() {
    if (_released) return;
    _released = true;
    _owner._releaseGlyphAtlas(config, _entry);
  }
}

/// Owns render resources that can be shared by compatible terminal views.
///
/// Render boxes derive a [GlyphAtlasConfig] from their current
/// theme/metrics/DPR and use it directly as the sharing key.
///
/// This type is internal; public sharing is exposed through `TerminalScope`.
class TerminalRenderCache {
  final _glyphAtlases = <GlyphAtlasConfig, _GlyphAtlasEntry>{};

  TerminalGlyphAtlasHandle acquireGlyphAtlas(GlyphAtlasConfig config) {
    final entry = _glyphAtlases.putIfAbsent(
      config,
      () => _GlyphAtlasEntry(GlyphAtlas(config)),
    );
    entry.references++;
    return TerminalGlyphAtlasHandle._(this, config, entry);
  }

  void dispose() {
    for (final entry in _glyphAtlases.values) {
      entry.atlas.dispose();
    }
    _glyphAtlases.clear();
  }

  void _releaseGlyphAtlas(
    GlyphAtlasConfig config,
    _GlyphAtlasEntry releasedEntry,
  ) {
    final entry = _glyphAtlases[config];
    if (entry == null) return;
    if (!identical(entry, releasedEntry)) return;

    entry.references--;
    if (entry.references > 0) return;

    _glyphAtlases.remove(config);
    entry.atlas.dispose();
  }
}

class _GlyphAtlasEntry {
  final GlyphAtlas atlas;
  var references = 0;

  _GlyphAtlasEntry(this.atlas);
}
