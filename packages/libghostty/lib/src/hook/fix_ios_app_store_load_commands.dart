import 'dart:io';
import 'dart:typed_data';

const _lcEncryptionInfo = 0x21;
const _lcEncryptionInfo64 = 0x2C;
const _lcSegment64 = 0x19;
const _machoHeaderSize64 = 32;
const _machoMagic64 = 0xFEEDFACF;
const _encryptionInfo64CommandSize = 24;

/// Adds the iOS App Store encryption-info load command if it is missing.
///
/// The iOS App Store validation pipeline rejects dynamically bundled device
/// Mach-O binaries that do not carry an encryption-info command. Ghostty's
/// Zig-built dylib does not currently include one, so add the same unencrypted
/// LC_ENCRYPTION_INFO_64 command shape produced by Apple's linker.
bool fixIosAppStoreLoadCommands(File libFile) {
  final bytes = libFile.readAsBytesSync();
  if (bytes.length < _machoHeaderSize64) return false;

  final data = ByteData.sublistView(bytes);
  final magic = data.getUint32(0, Endian.little);
  if (magic != _machoMagic64) return false;

  final ncmds = data.getUint32(16, Endian.little);
  final sizeofcmds = data.getUint32(20, Endian.little);
  final commandEnd = _machoHeaderSize64 + sizeofcmds;
  if (commandEnd > bytes.length) {
    throw const FormatException(
      'Mach-O load commands extend past end of file.',
    );
  }

  var offset = _machoHeaderSize64;
  int? firstDataOffset;
  for (var i = 0; i < ncmds; i++) {
    if (offset + 8 > commandEnd) {
      throw const FormatException('Malformed Mach-O load command table.');
    }
    final cmd = data.getUint32(offset, Endian.little);
    final cmdsize = data.getUint32(offset + 4, Endian.little);
    if (cmdsize < 8 || offset + cmdsize > commandEnd) {
      throw const FormatException('Malformed Mach-O load command size.');
    }

    if (cmd == _lcEncryptionInfo || cmd == _lcEncryptionInfo64) {
      return false;
    }

    if (cmd == _lcSegment64) {
      firstDataOffset = _minPositive(
        firstDataOffset,
        data.getUint64(offset + 40, Endian.little),
      );

      final nsects = data.getUint32(offset + 64, Endian.little);
      var sectionOffset = offset + 72;
      for (var section = 0; section < nsects; section++) {
        if (sectionOffset + 80 > offset + cmdsize) {
          throw const FormatException('Malformed Mach-O section table.');
        }
        firstDataOffset = _minPositive(
          firstDataOffset,
          data.getUint32(sectionOffset + 48, Endian.little),
        );
        sectionOffset += 80;
      }
    }

    offset += cmdsize;
  }

  if (offset != commandEnd) {
    throw const FormatException(
      'Mach-O load command table ended at an unexpected offset.',
    );
  }

  final availablePadding = (firstDataOffset ?? bytes.length) - commandEnd;
  if (availablePadding < _encryptionInfo64CommandSize) {
    throw StateError(
      'Not enough Mach-O load-command padding to add LC_ENCRYPTION_INFO_64.',
    );
  }

  data.setUint32(commandEnd, _lcEncryptionInfo64, Endian.little);
  data.setUint32(commandEnd + 4, _encryptionInfo64CommandSize, Endian.little);
  data.setUint32(commandEnd + 8, 0, Endian.little); // cryptoff
  data.setUint32(commandEnd + 12, 0, Endian.little); // cryptsize
  data.setUint32(commandEnd + 16, 0, Endian.little); // cryptid
  data.setUint32(commandEnd + 20, 0, Endian.little); // pad
  data.setUint32(16, ncmds + 1, Endian.little);
  data.setUint32(20, sizeofcmds + _encryptionInfo64CommandSize, Endian.little);

  libFile.writeAsBytesSync(bytes);
  return true;
}

int? _minPositive(int? current, int value) {
  if (value <= 0) return current;
  if (current == null || value < current) return value;
  return current;
}
