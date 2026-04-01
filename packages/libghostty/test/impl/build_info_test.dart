@Tags(['ffi'])
library;

import 'package:libghostty/libghostty.dart';
import 'package:test/test.dart';

void main() {
  group('LibGhosttyBuildInfo', () {
    test('singleton returns consistent instance', () {
      final a = LibGhosttyBuildInfo.instance;
      final b = LibGhosttyBuildInfo.instance;
      expect(identical(a, b), isTrue);
    });

    test('boolean fields return valid values', () {
      final info = LibGhosttyBuildInfo.instance;
      expect(info.simd, isA<bool>());
      expect(info.kittyGraphics, isA<bool>());
      expect(info.tmuxControlMode, isA<bool>());
    });

    test('optimizeMode is a valid OptimizeMode', () {
      expect(LibGhosttyBuildInfo.instance.optimizeMode, isA<OptimizeMode>());
    });

    test('versionString is non-empty', () {
      expect(LibGhosttyBuildInfo.instance.versionString, isNotEmpty);
    });

    test('version components are non-negative', () {
      final info = LibGhosttyBuildInfo.instance;
      expect(info.versionMajor, greaterThanOrEqualTo(0));
      expect(info.versionMinor, greaterThanOrEqualTo(0));
      expect(info.versionPatch, greaterThanOrEqualTo(0));
      expect(info.versionBuild, isA<String>());
    });
  });
}
