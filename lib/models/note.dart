import 'dart:math';

/// Tek bir kayıt: konu başlığı, kullanıcı adı, şifre ve not.
class Note {
  final String id;
  final String title;
  final String username;
  final String password;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Listenin en üstünde sabit duran not.
  final bool pinned;

  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.username = '',
    this.password = '',
    this.pinned = false,
  });

  factory Note.create({
    required String title,
    String username = '',
    String password = '',
    required String body,
  }) {
    final now = DateTime.now();
    return Note(
      id: _newId(),
      title: title,
      username: username,
      password: password,
      body: body,
      createdAt: now,
      updatedAt: now,
    );
  }

  Note copyWith({
    String? title,
    String? username,
    String? password,
    String? body,
  }) => Note(
    id: id,
    title: title ?? this.title,
    username: username ?? this.username,
    password: password ?? this.password,
    body: body ?? this.body,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    pinned: pinned,
  );

  /// Sabitleme durumunu değiştirir (değişiklik tarihine dokunmaz).
  Note withPinned(bool value) => Note(
    id: id,
    title: title,
    username: username,
    password: password,
    body: body,
    createdAt: createdAt,
    updatedAt: updatedAt,
    pinned: value,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    if (username.isNotEmpty) 'user': username,
    if (password.isNotEmpty) 'pass': password,
    'body': body,
    'created': createdAt.toIso8601String(),
    'updated': updatedAt.toIso8601String(),
    if (pinned) 'pinned': true,
  };

  /// Eski kayıtlarda 'user' / 'pass' yoktur: boş kalır, bilgiler notta durur.
  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] as String,
    title: j['title'] as String,
    username: j['user'] as String? ?? '',
    password: j['pass'] as String? ?? '',
    body: j['body'] as String,
    createdAt: DateTime.parse(j['created'] as String),
    updatedAt: DateTime.parse(j['updated'] as String),
    pinned: j['pinned'] as bool? ?? false,
  );

  static String _newId() {
    final r = Random.secure();
    final rand = List.generate(
      8,
      (_) => r.nextInt(16).toRadixString(16),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$rand';
  }
}
