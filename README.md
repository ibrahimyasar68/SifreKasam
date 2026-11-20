# Şifre Kasam

Kişisel şifreleri telefonda şifreli olarak saklayan, sade bir Android uygulaması (Flutter).

- Her kayıtta dört alan: konu başlığı, kullanıcı adı, şifre ve not
- 6 haneli PIN veya parmak izi / yüz tanıma ile giriş
- Veriler AES-256-GCM ile şifreli. Şifreleme anahtarı PIN'e bağlı.
- İnternet izni yok: hiçbir veri cihazdan çıkmaz
- Şifreli yedek alma / yükleme, güçlü şifre üretici, açık / koyu tema

Ayrıntılı teknik notlar, derleme adımları ve dikkat edilmesi gerekenler için: [devam.md](devam.md)

İmza anahtarı (`android/key.properties`, `android/app/*.jks`) bu depoda bulunmaz.

İY Labs
