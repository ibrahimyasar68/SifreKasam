// Türkçe harflere uygun küçük harfe çevirme ve alfabetik sıralama.

const _alphabet = 'abcçdefgğhıijklmnoöpqrsştuüvwxyz';

String trLower(String s) {
  final b = StringBuffer();
  for (final ch in s.runes) {
    final c = String.fromCharCode(ch);
    if (c == 'I') {
      b.write('ı');
    } else if (c == 'İ') {
      b.write('i');
    } else {
      b.write(c.toLowerCase());
    }
  }
  return b.toString();
}

int _rank(String c) {
  final i = _alphabet.indexOf(c);
  if (i >= 0) return 1000 + i; // harfler
  final code = c.codeUnitAt(0);
  if (code >= 48 && code <= 57) return 500 + code; // rakamlar harflerden önce
  return 2000 + code; // diğer karakterler en sona
}

/// Türk alfabesine göre karşılaştırma (büyük/küçük harf duyarsız).
int trCompare(String a, String b) {
  final x = trLower(a.trim()).runes.map(String.fromCharCode).toList();
  final y = trLower(b.trim()).runes.map(String.fromCharCode).toList();
  final n = x.length < y.length ? x.length : y.length;
  for (var i = 0; i < n; i++) {
    final d = _rank(x[i]) - _rank(y[i]);
    if (d != 0) return d;
  }
  return x.length - y.length;
}
