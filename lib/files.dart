import 'package:flutter/services.dart';

// Android's own "Save as" / "Open" screens (Storage Access Framework),
// reached through MainActivity.kt, so no plugin is needed.
const _files = MethodChannel('pumplex/files');

/// Lets the user pick where to save. False if they backed out.
Future<bool> saveTextFile({
  required String name,
  required String mime,
  required String content,
}) async =>
    await _files.invokeMethod<bool>('saveText', {
      'name': name,
      'mime': mime,
      'content': content,
    }) ??
    false;

/// Lets the user pick a file and returns its text. Null if they backed out.
Future<String?> openTextFile() => _files.invokeMethod<String>('openText');

/// Unicode byte-order mark (U+FEFF).
final bom = String.fromCharCode(0xFEFF);

