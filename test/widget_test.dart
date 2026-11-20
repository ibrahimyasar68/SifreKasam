import 'package:flutter_test/flutter_test.dart';
import 'package:sifre_kasam/models/note.dart';
import 'package:sifre_kasam/utils/turkish.dart';

void main() {
  test('Türkçe alfabetik sıralama', () {
    final list = ['Şifre', 'zeytin', 'Çanta', 'ılık', 'İnternet', 'Banka',
        'Ütü', 'Ofis', 'Öğrenci', 'Gmail', 'Ğ harfi', 'Ceren', 'Wi-Fi', 'Sosyal'];
    list.sort(trCompare);
    expect(list, ['Banka', 'Ceren', 'Çanta', 'Gmail', 'Ğ harfi', 'ılık',
        'İnternet', 'Ofis', 'Öğrenci', 'Sosyal', 'Şifre', 'Ütü', 'Wi-Fi',
        'zeytin']);
  });

  test('Türkçe küçük harf', () {
    expect(trLower('IŞIK İĞNE'), 'ışık iğne');
  });

  test('Not JSON gidiş-dönüş', () {
    final n = Note.create(title: 'E-posta', body: 'kullanıcı: ali\nşifre: 123');
    final back = Note.fromJson(n.toJson());
    expect(back.id, n.id);
    expect(back.title, n.title);
    expect(back.body, n.body);
  });

  test('Sabitleme JSON ve eski kayıt uyumu', () {
    final n = Note.create(title: 'Banka', body: 'x').withPinned(true);
    expect(Note.fromJson(n.toJson()).pinned, isTrue);
    final legacy = n.toJson()..remove('pinned');
    expect(Note.fromJson(legacy).pinned, isFalse);
    expect(n.withPinned(false).updatedAt, n.updatedAt);
  });

  test('Kullanıcı adı / şifre alanları ve eski kayıt uyumu', () {
    final n = Note.create(
      title: 'Gmail',
      username: 'ali@ornek.com',
      password: 'Gizli#123',
      body: 'kurtarma kodu',
    );
    final back = Note.fromJson(n.toJson());
    expect(back.username, 'ali@ornek.com');
    expect(back.password, 'Gizli#123');
    expect(back.body, 'kurtarma kodu');
    // Eski kayıt: user/pass yok -> boş, bilgiler notta kalır.
    final legacy = {
      'id': '1',
      'title': 'Banka',
      'body': 'kullanıcı: ali\nşifre: 123',
      'created': DateTime(2026).toIso8601String(),
      'updated': DateTime(2026).toIso8601String(),
    };
    final old = Note.fromJson(legacy);
    expect(old.username, '');
    expect(old.password, '');
    expect(old.body, contains('şifre: 123'));
    expect(old.withPinned(true).password, '');
  });
}
