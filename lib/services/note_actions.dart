import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/note.dart';
import 'secure_clipboard.dart';
import 'vault.dart';

/// Notlar üzerinde ortak işlemler.
class NoteActions {
  NoteActions._();

  /// Notu siler ve birkaç saniye "Geri al" seçeneği sunar.
  static Future<void> deleteWithUndo(
    ScaffoldMessengerState messenger,
    Note note,
  ) async {
    HapticFeedback.mediumImpact();
    await Vault.instance.delete(note.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${note.title}" silindi'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Geri al',
            onPressed: () => Vault.instance.upsert(note),
          ),
        ),
      );
  }

  static Future<void> togglePin(
    ScaffoldMessengerState messenger,
    Note note,
  ) async {
    HapticFeedback.selectionClick();
    await Vault.instance.upsert(note.withPinned(!note.pinned));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            note.pinned ? 'Sabitleme kaldırıldı' : 'En üste sabitlendi',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  /// Listeden kaydırarak kopyalama: yalnızca şifreyi kopyalar.
  static Future<void> copyQuick(
    ScaffoldMessengerState messenger,
    Note note,
  ) async {
    if (note.password.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('"${note.title}" kaydında şifre alanı boş'),
            duration: const Duration(seconds: 2),
          ),
        );
      return;
    }
    await SecureClipboard.copy(note.password);
    HapticFeedback.mediumImpact();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${note.title}: şifre kopyalandı · pano 60 sn sonra temizlenir',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }
}
