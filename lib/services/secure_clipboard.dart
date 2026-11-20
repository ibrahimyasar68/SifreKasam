import 'dart:async';

import 'package:flutter/services.dart';

/// Kopyalanan metni "hassas" olarak işaretler (Android 13+ pano
/// önizlemesinde gizlenir) ve 60 saniye sonra panodan siler.
class SecureClipboard {
  SecureClipboard._();
  static const _channel = MethodChannel('sifre_kasam/clipboard');
  static const clearAfter = Duration(seconds: 60);
  static Timer? _timer;

  static Future<void> copy(String text) async {
    try {
      await _channel.invokeMethod('copySensitive', {'text': text});
    } on MissingPluginException {
      await Clipboard.setData(ClipboardData(text: text));
    }
    _timer?.cancel();
    _timer = Timer(clearAfter, () async {
      try {
        await _channel.invokeMethod('clearIfEquals', {'text': text});
      } on MissingPluginException {
        final cur = await Clipboard.getData(Clipboard.kTextPlain);
        if (cur?.text == text) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      }
    });
  }
}
