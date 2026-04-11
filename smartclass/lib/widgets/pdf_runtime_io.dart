import 'dart:io';
import 'dart:typed_data';

bool get isWindowsPlatform => Platform.isWindows;
bool get isAndroidPlatform => Platform.isAndroid;
bool get isIOSPlatform => Platform.isIOS;

Future<Uint8List?> readPdfFileBytes(String path) async {
  return File(path).readAsBytes();
}
