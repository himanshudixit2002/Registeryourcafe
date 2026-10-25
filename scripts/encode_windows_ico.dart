import 'dart:io';

import 'package:image/image.dart' as img;

/// Builds `windows/runner/resources/app_icon.ico` from project root [logo.png].
void main() {
  final root = Directory.current.path;
  final decoded = img.decodeImage(File('$root/logo.png').readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Failed to decode logo.png');
    exit(1);
  }
  final icon = img.copyResize(decoded, width: 16, height: 16);
  for (final s in [32, 48, 64, 128, 256]) {
    icon.addFrame(img.copyResize(decoded, width: s, height: s));
  }
  File('$root/windows/runner/resources/app_icon.ico')
      .writeAsBytesSync(img.encodeIco(icon));
}
