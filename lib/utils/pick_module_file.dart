/// Ask the reader for a module file and hand back its name and bytes.
///
/// Deliberately narrow: it returns the CONTENT and the file's name and nothing
/// else. No path, no handle, no upload — the bytes go to the parser and that is
/// all. There is nothing here a network could be attached to.
///
/// One door for every platform (`file_selector`: the Flutter team's own
/// package, endorsed implementations for web, iOS, Android, macOS, Windows and
/// Linux). No file-type filter: module files have extensions no OS knows
/// (`.bbl.mybible`, `.SQLite3`, `.ont`) and a filter that hides the reader's own
/// file is worse than none — the parser decides what a file is, by content.
library;

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:file_selector/file_selector.dart';
import 'package:yahwehs_words/utils/addons/addon_types.dart';
import 'package:yahwehs_words/utils/addons/parse_module.dart' show kMaxModuleBytes;

typedef PickedModuleFile = ({String name, Uint8List bytes});

/// The reader's choice, or null when they cancelled. Throws [ImportRefusal]
/// (tooLarge) for a file over the limit WITHOUT reading it into memory.
Future<PickedModuleFile?> pickModuleFile() async {
  final XFile? f;
  try {
    f = await openFile();
  } catch (e, st) {
    // NOT a cancel: a cancel is a null from the dialog. This is the platform
    // failing to show it (a plugin that is not registered, a sandbox that
    // refuses) and the reader is told, rather than left to think nothing
    // happened.
    debugPrint('pickModuleFile: the file chooser failed: $e\n$st');
    throw const ImportRefusal(ImportProblem.pickerFailed);
  }
  if (f == null) return null;
  final size = await f.length();
  if (size > kMaxModuleBytes) {
    throw ImportRefusal(ImportProblem.tooLarge, detail: formatBytes(size));
  }
  return (name: f.name, bytes: await f.readAsBytes());
}

/// `12.3 MB`, `640 KB`.
String formatBytes(int n) {
  if (n >= 1024 * 1024) return '${(n / (1024 * 1024)).toStringAsFixed(1)} MB';
  if (n >= 1024) return '${(n / 1024).toStringAsFixed(0)} KB';
  return '$n B';
}
