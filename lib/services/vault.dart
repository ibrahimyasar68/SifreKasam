import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/note.dart';
import '../utils/turkish.dart';
import 'security.dart';

class BackupException implements Exception {
  final String message;
  BackupException(this.message);
  @override
  String toString() => message;
}

/// Notları AES-256-GCM ile şifreleyip cihaza kaydeden kasa.
class Vault extends ChangeNotifier {
  Vault._();
  static final instance = Vault._();

  static final _aes = AesGcm.with256bits();
  static const _fileName = 'kasa.bin';
  static const _backupMagic = 'SKYEDEK1';
  static const _backupIterations = 150000;

  List<Note> _notes = [];
  bool _loaded = false;
  bool _loading = false;
  String? _error;

  SecretKey? _key;

  bool get loaded => _loaded;

  /// Bellekteki veri anahtarı (PIN değiştirme / biyometri açma için).
  SecretKey? get dataKey => _key;
  String? get error => _error;

  /// Konu başlığına göre Türkçe alfabetik sıralı notlar.
  List<Note> get notes {
    final list = List<Note>.of(_notes);
    list.sort((a, b) => trCompare(a.title, b.title));
    return list;
  }

  Note? byId(String id) {
    for (final n in _notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Kilit açılınca PIN'den veya biyometriden gelen anahtarla notları açar.
  /// Anahtar yalnızca bellekte tutulur.
  Future<void> load(SecretKey key) async {
    _key = key;
    if (_loaded || _loading) return;
    _loading = true;
    _error = null;
    try {
      final f = await _file();
      if (await f.exists()) {
        final clear = await _decrypt(await f.readAsBytes(), key);
        _notes = _decodeNotes(clear);
      } else {
        _notes = [];
      }
      _loaded = true;
    } catch (e) {
      _error = 'Notlar açılamadı: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> upsert(Note note) async {
    _ensureLoaded();
    final i = _notes.indexWhere((n) => n.id == note.id);
    final updated = List<Note>.of(_notes);
    if (i >= 0) {
      updated[i] = note;
    } else {
      updated.add(note);
    }
    await _persist(updated);
  }

  Future<void> delete(String id) async {
    _ensureLoaded();
    await _persist(_notes.where((n) => n.id != id).toList());
  }

  // ------------------------------------------------------------ Yedek

  /// Tüm notları [password] ile şifrelenmiş tek bir dosya olarak döndürür.
  Future<Uint8List> exportBackup(String password) async {
    _ensureLoaded();
    final salt = Security.randomBytes(16);
    final key = SecretKey(
      await Security.deriveKey(password, salt, _backupIterations),
    );
    final enc = await _encrypt(_encodeNotes(_notes), key);
    return Uint8List.fromList([...utf8.encode(_backupMagic), ...salt, ...enc]);
  }

  /// Yedek dosyasını mevcut notlarla birleştirir. Aynı not iki tarafta da
  /// varsa daha yeni olanı tutulur. Eklenen/güncellenen not sayısını döndürür.
  Future<int> importBackup(Uint8List data, String password) async {
    _ensureLoaded();
    final magic = utf8.encode(_backupMagic);
    if (data.length < magic.length + 16 + 28 ||
        !listEquals(data.sublist(0, magic.length), magic)) {
      throw BackupException('Bu dosya bir Şifre Kasam yedeği değil.');
    }
    final salt = data.sublist(magic.length, magic.length + 16);
    final key = SecretKey(
      await Security.deriveKey(password, salt, _backupIterations),
    );
    final List<int> clear;
    try {
      clear = await _decrypt(data.sublist(magic.length + 16), key);
    } on SecretBoxAuthenticationError {
      throw BackupException('Yedek şifresi yanlış.');
    }
    final incoming = _decodeNotes(clear);
    final merged = {for (final n in _notes) n.id: n};
    var changed = 0;
    for (final n in incoming) {
      final cur = merged[n.id];
      if (cur == null || n.updatedAt.isAfter(cur.updatedAt)) {
        merged[n.id] = n;
        changed++;
      }
    }
    if (changed > 0) await _persist(merged.values.toList());
    return changed;
  }

  // ------------------------------------------------------------ İç

  void _ensureLoaded() {
    if (!_loaded) throw StateError('Kasa henüz açılmadı.');
  }

  Future<void> _persist(List<Note> notes) async {
    final key = _key;
    if (key == null) throw StateError('Kasa kilitli.');
    final enc = await _encrypt(_encodeNotes(notes), key);
    final f = await _file();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(enc, flush: true);
    await tmp.rename(f.path); // yarım yazılmış dosya oluşmasın
    _notes = notes;
    notifyListeners();
  }

  static List<int> _encodeNotes(List<Note> notes) => utf8.encode(
    jsonEncode({'v': 1, 'notes': notes.map((n) => n.toJson()).toList()}),
  );

  static List<Note> _decodeNotes(List<int> bytes) {
    final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return (j['notes'] as List)
        .map((e) => Note.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<int>> _encrypt(List<int> clear, SecretKey key) async {
    final box = await _aes.encrypt(clear, secretKey: key);
    return box.concatenation(); // nonce(12) + şifreli metin + mac(16)
  }

  static Future<List<int>> _decrypt(List<int> data, SecretKey key) {
    final box = SecretBox.fromConcatenation(
      data,
      nonceLength: _aes.nonceLength,
      macLength: 16,
      copy: true,
    );
    return _aes.decrypt(box, secretKey: key);
  }
}
