import 'dart:io';

// This tool must run before package resolution in the release artifact job.
// ignore: avoid_relative_lib_imports
import '../lib/src/hook/fix_ios_app_store_load_commands.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/fix_ios_app_store_load_commands.dart <ios-dylib>',
    );
    exitCode = 64;
    return;
  }

  final file = File(args.single);
  if (!file.existsSync()) {
    stderr.writeln('File not found: ${file.path}');
    exitCode = 66;
    return;
  }

  final changed = fixIosAppStoreLoadCommands(file);
  stdout.writeln(
    changed
        ? 'Added LC_ENCRYPTION_INFO_64 to ${file.path}'
        : 'LC_ENCRYPTION_INFO load command already present in ${file.path}',
  );
}
