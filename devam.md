# Şifre Kasam: Devam Notları

Bu dosya, projeye daha sonra (yeni bir oturumda ya da başka biriyle) kaldığı yerden devam edebilmek için hazırlandı. Uygulamanın ne yaptığını, nasıl kurulduğunu, nasıl derlendiğini ve nelere dikkat edilmesi gerektiğini anlatır.

**Son güncelleme:** 20 Kasım 2026
**Kaynak kod:** https://github.com/ibrahimyasar68/SifreKasam (dal: `main`)
**Güncel sürüm:** 1.2.2 (sürüm kodu 5), telefonda kurulu ve çalışıyor (parmak izi dahil)

---

## 1. Uygulama ne yapıyor?

Kişisel şifreleri saklayan, sadece Android için yapılmış bir Flutter uygulaması. İnternet izni yok, hiçbir veri cihazdan dışarı çıkmaz.

- Her kayıtta dört alan var: **Konu başlığı, Kullanıcı adı, Şifre, Not**.
- Kayıtlar başlığa göre Türk alfabesine uygun sırada (Ç, Ğ, İ, Ö, Ş, Ü doğru yerde) kart olarak listelenir.
- Uygulama **6 haneli PIN** veya **parmak izi / yüz tanıma** ile açılır.
- Veriler cihazda **AES-256-GCM** ile şifreli saklanır.
- Uygulama simgesi: lacivert zemin üzerinde altın kilit ve sağ alt köşede "İY Labs" etiketi.

## 2. Özellikler (güncel durum)

**Ana ekran (liste)**
- Sadeleştirilmiş kartlar: büyük harf sembolü (54 px) ve başlık. Tarih gösterilmiyor.
- Harf gruplaması ve sağdaki harf çubuğu **kaldırıldı** (kullanıcı isteği).
- Sabitlenen kayıtlar en üstte, "Sabitlenenler" başlığı altında durur.
- Arama başlıkta, kullanıcı adında ve notta arar. Şifrede **aramaz**. Eşleşen kısım altın renkle vurgulanır.
- **Sağa kaydırma:** sabitle / sabitlemeyi kaldır.
- **Sola kaydırma:** sadece **şifreyi** kopyalar, kart yerinde kalır. Şifre alanı boşsa "şifre alanı boş" uyarısı çıkar. Kaydırarak silme **yok**.
- Gizli kaydırma çubuğu: sadece kaydırırken görünür, sürüklenebilir.
- Yedek hatırlatıcısı: hiç yedek alınmadıysa ya da son yedek 30 günden eskiyse görünür. "Sonra" 7 gün erteler.

**Detay ekranı**
- **Kullanıcı adı açık** görünür (buzlu değil), yanında kopyala butonu var.
- **Şifre buzlu** görünür. Göz simgesiyle açılır, kopyala butonu var. Satıra dokunmak da kopyalar.
- Not kısmı düz görünür. Satıra dokununca yalnızca o satır kopyalanır.
- Sabitle, düzenle ve sil (geri alınabilir) butonları var.

**Düzenleme ekranı**
- Dört alan. Şifre alanında göster/gizle ve ✨ **güçlü şifre üretici** (uzunluk 8-32, büyük harf / rakam / sembol seçimi, güç göstergesi).
- Kaydedilmemiş değişiklik varken çıkılırsa onay sorulur.

**Ayarlar**
- Tema: Sistem / Açık / Koyu.
- Biyometrik giriş aç/kapat.
- Otomatik kilit süresi: Hemen / 30 sn (varsayılan) / 1 dk / 5 dk.
- PIN değiştirme.
- Yedek al / Yedekten yükle (son yedek tarihi gösterilir).
- Altta sürüm numarası.

**Güvenlik ayrıntıları**
- Ekran görüntüsü ve "son uygulamalar" önizlemesi engelli (`FLAG_SECURE`).
- Kopyalanan metin "hassas" olarak işaretlenir. Android 13+ pano önizlemesinde "••••••" görünür. 60 saniye sonra panodan silinir.
- Klavyenin öğrenmesi (`enableIMEPersonalizedLearning: false`) tüm hassas alanlarda kapalı.
- 5 yanlış PIN'den sonra artan bekleme süresi başlar (30 sn, 1 dk, 2 dk… en fazla 15 dk).
- Android bulut yedeği kapalı (`allowBackup="false"`).

## 3. ⚠️ Kritik kurallar (bozulursa veri kaybı olur)

1. **Şifreleme anahtarı PIN'e bağlı (sürüm 1.1.0'dan beri).** PIN unutulursa notlar **kurtarılamaz**, tek çare yedek dosyasıdır. Kullanıcı bunu bilerek onayladı. Verileri koruyan bir "PIN sıfırlama" özelliği **eklenemez**.
2. **İmza anahtarı asla değişmemeli.** Şu iki dosya kaybolursa ya da değişirse güncelleme kurulamaz. O durumda uygulamayı silip yeniden kurmak gerekir, bu da tüm notların silinmesi demektir:
   - `android/key.properties` (şifreleri içerir, `.gitignore`'da)
   - `android/app/sifre_kasam.jks` (`.gitignore`'da)
   - Sertifika SHA-256'sının başı: `7d0d2d7c229d…` (her derlemede bununla karşılaştırın)
   - Bu iki dosyanın bilgisayar dışında bir yedeği olması önerilir.
3. **Depolama biçimi değiştirilecekse eski sürümden geçiş yolu korunmalı** ve eski sürüm kurulup üzerine yeni sürüm yüklenerek test edilmeli (bkz. Bölüm 7).
4. `flutter_secure_storage` her zaman `resetOnError: false` ile kullanılmalı. Varsayılan `true` değeri hata anında anahtarları siler.

## 4. Mimari ve dosyalar

```
lib/
  main.dart                 Giriş noktası: kenardan kenara ekran, tema, kilit, yaşam döngüsü
  theme.dart                Renkler (lacivert/altın), açık/koyu tema, kart gölgeleri, Manrope yazı tipi
  models/note.dart          Kayıt modeli: title, username, password, body, pinned, tarihler
  services/
    security.dart           PIN, PIN'e bağlı anahtar, biyometri deposu, yanlış deneme kilidi, ayarlar
    vault.dart              Şifreli dosya (kasa.bin), kayıt ekle/sil, yedek al/yükle
    app_lock.dart           Kilit durumu, otomatik kilit süresi, kilit ekranını açma/kapatma
    backup_actions.dart     Yedek alma/yükleme arayüzü, son yedek tarihi, hatırlatıcı
    note_actions.dart       Geri alınabilir silme, sabitleme, kaydırarak şifre kopyalama
    secure_clipboard.dart   Hassas pano (yerel kanal) ve 60 sn sonra temizleme
    biometrics.dart         Cihazda biyometri var mı kontrolü
    theme_controller.dart   Tema seçimi (Sistem/Açık/Koyu)
  screens/
    lock_screen.dart        Kilit ekranı + ilk kurulum + eski sürümden geçiş önerisi
    home_screen.dart        Liste, arama, kaydırma eylemleri, yedek hatırlatıcısı
    note_detail_screen.dart Detay: açık kullanıcı adı, buzlu şifre, satır kopyalama
    note_edit_screen.dart   Dört alanlı form + şifre üretici
    settings_screen.dart    Ayarlar + PIN değiştirme ekranı
  widgets/
    pin_pad.dart            PIN tuş takımı (yanlış PIN'de sallanma animasyonu)
    shadow_card.dart        Gölgeli kart, giriş animasyonu, harf sembolü (LetterAvatar)
    password_generator.dart Şifre üretici alt sayfası
  utils/turkish.dart        Türkçe küçük harf ve alfabetik sıralama

android/app/src/main/kotlin/.../MainActivity.kt
                            FlutterFragmentActivity, FLAG_SECURE, hassas pano kanalı
                            (sifre_kasam/clipboard: copySensitive, clearIfEquals)
assets/icon/                icon.png (klasik), icon_foreground.png (uyarlanabilir + açılış ekranı)
assets/fonts/               Manrope (400-800 sabit kalınlıklar) + OFL lisansı
tool/make_icon.py           Simgeyi Pillow ile yeniden üreten betik
test/                       6 otomatik test (Türkçe sıralama, JSON, eski kayıt uyumu vb.)
```

### Şifreleme yapısı
- **Veri anahtarı:** 32 bayt rastgele. Yalnızca bellekte açık durur.
- **PIN kopyası** (`data_key_pin`): PBKDF2-HMAC-SHA256 (150.000 tur, 16 bayt tuz) ile PIN'den türetilen anahtarla AES-GCM şifreli. PIN doğrulaması bu şifreyi çözerek yapılır.
- **Biyometri kopyası:** `flutter_secure_storage` biyometrik deposunda (ad alanı `kasa_bio`, güçlü biyometri, her okumada doğrulama). Cihaza yeni parmak izi eklenirse geçersiz olur ve biyometri otomatik kapanır, kullanıcı PIN ile girer.
- **Notlar dosyası:** `getApplicationSupportDirectory()/kasa.bin` = nonce(12) + şifreli JSON + mac(16). Yazarken önce `.tmp` dosyasına yazılıp yeniden adlandırılır.
- **JSON biçimi:** `{"v":1,"notes":[{id,title,user?,pass?,body,created,updated,pinned?}]}`. `user` / `pass` / `pinned` alanları boşsa hiç yazılmaz. Eski kayıtlarda bu alanlar yoksa boş kabul edilir.
- **Yedek dosyası (.skb):** `"SKYEDEK1"` + tuz(16) + AES-GCM (yedek şifresinden PBKDF2 150.000 tur). Yüklerken kayıtlar birleştirilir, aynı kayıt iki tarafta da varsa daha yeni olanı kalır.
- **Sürüm 1.0'dan geçiş:** Eski `pin_hash` + açıkta duran `data_key` ilk doğru PIN girişinde PIN'e bağlanır, doğrulanır ve ancak ondan sonra eskileri silinir (`Security._migrateLegacy`).

## 5. Derleme ve teslim

Flutter 3.47.9 (`/Users/ibrahimyasar/flutter/flutter/bin/flutter`), Android SDK `~/Library/Android/sdk`.

```bash
cd /Users/ibrahimyasar/Desktop/SifreKasam
```

```bash
flutter analyze && flutter test
```

```bash
flutter build apk --release --split-per-abi && flutter build apk --release
```

```bash
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk SifreKasam.apk && cp build/app/outputs/flutter-apk/app-release.apk SifreKasam-tum-cihazlar.apk
```

- **SifreKasam.apk** (~19 MB, arm64): kullanıcıya verilen asıl dosya.
- **SifreKasam-tum-cihazlar.apk** (~53 MB): yedek dosya, sadece ilki kurulmazsa.
- Her yeni sürümde `pubspec.yaml` içindeki `version:` artırılmalı (ör. `1.2.3+6`).
- İmza kontrolü (SHA-256 `7d0d2d7c229d…` ile başlamalı):

```bash
~/Library/Android/sdk/build-tools/$(ls ~/Library/Android/sdk/build-tools | tail -1)/apksigner verify --print-certs SifreKasam.apk | grep SHA-256
```

- Simge değişirse: `python3 tool/make_icon.py` ve ardından `dart run flutter_launcher_icons`
- Açılış ekranı değişirse: `dart run flutter_native_splash:create`

## 6. Kurulum (telefonda)

APK telefona aktarılır (kablo, Drive ya da WhatsApp'ta kendine gönderme) ve dosyaya dokunularak kurulur. Eskisinin üzerine kurulduğunda veriler korunur. Güncellemeden önce kullanıcıya **yedek almasını** hatırlatın.

## 7. Test yöntemi (emülatör)

- **Emülatör:** `flutter_emulator` (1080x1920). Açmak için: `~/Library/Android/sdk/emulator/emulator -avd flutter_emulator -no-snapshot -no-boot-anim`. Anlık görüntüden açınca kapanma sorunu yaşandı, `-no-snapshot` ile açılmalı. İş bitince `adb emu kill` ile kapatılmalı.
- **Kullanıcının kendi uygulamasına dokunmayın.** Emülatörlerde kullanıcının kendi geliştirme sürümü ve başka uygulamaları (ör. BudgetFlow) olabilir.
- **Ekran görüntülü test kopyası:** `FLAG_SECURE` yüzünden ekran görüntüsü siyah çıkar. Test için geçici olarak:
  1. `MainActivity.kt` içinde `window.setFlags(` satırının başına `if (false) ` eklenir,
  2. `build.gradle.kts` içinde `debug { applicationIdSuffix = ".test" }` eklenir (ayrı paket adı, kullanıcının verisine dokunmaz),
  3. `flutter build apk --debug` ile derlenip kurulur,
  4. **iki dosya hemen eski haline getirilir** ve `grep -c 'if (false)'` ile kontrol edilir,
  5. test bitince `adb uninstall com.ibrahim.sifre_kasam.test` ile kaldırılır.
- Ekran öğeleri `adb shell uiautomator dump` ile okunabilir (`FLAG_SECURE` bunu engellemez). Dokunma için `adb shell input tap X Y` kullanılır.
- Test PIN'i olarak 123456 kullanıldı (sadece test kopyalarında).
- Debug derlemede PIN ile kilit açma 10-20 sn sürebilir (PBKDF2). Release derlemede çok daha hızlı.
- **Geçiş testi:** Eski sürümü kurun, PIN belirleyip kayıt ekleyin, yeni sürümü üzerine kurun, PIN ile açın ve kayıtların korunduğunu doğrulayın.

## 8. Bilinen konular / açık noktalar

- Testte bir kez, çok hızlı otomatik dokunuşlardan sonra ana ekranda hafif bir gri örtü görüldü. Kilitleyip açınca düzeldi, tekrar oluşmadı. Kullanıcı telefonda görürse incelenmeli (sayfa geçiş animasyonu `FadeForwardsPageTransitionsBuilder` şüpheli).
- PIN ile kilit açma, saf Dart PBKDF2 (150.000 tur) nedeniyle birkaç saniye sürebilir. Yavaş bulunursa `cryptography_flutter` paketiyle yerel (native) hızlandırma eklenebilir. Tur sayısını değiştirmek için `it` alanı JSON'da saklanıyor, eski kayıtlar okunmaya devam eder.
- Proje artık git ile takip ediliyor (bkz. Bölüm 10).

## 9. Sürüm geçmişi

| Sürüm | Tarih | Öne çıkanlar |
|---|---|---|
| 1.0.0 | 13 Kas 2026 | İlk sürüm: başlık + not, AES-256, PIN / parmak izi, yedekleme, simge |
| 1.0.0 (görünüm) | 14 Kas 2026 | İY Labs etiketi, tema seçimi, gölgeli kartlar, animasyonlar |
| 1.1.0 | 14 Kas 2026 | Anahtar PIN'e bağlandı, otomatik kilit süresi, satır kopyalama, geri alma, sabitleme, şifre üretici, yedek hatırlatıcısı, hassas pano, açılış ekranı, Manrope, 19 MB APK |
| 1.2.0 | 15 Kas 2026 | Dört alan (başlık, kullanıcı adı, şifre, not), buzlu alanlar, harf gruplaması kaldırıldı |
| 1.2.1 | 15 Kas 2026 | Listede tarih kaldırıldı, ince kartlar, gizli kaydırma çubuğu |
| 1.2.2 | 16 Kas 2026 | Harf sembolü %50 büyüdü, sola kaydırma = şifre kopyala, kullanıcı adı buzsuz |

## 10. Git ve GitHub

- **Depo:** https://github.com/ibrahimyasar68/SifreKasam.git, dal `main`. İlk gönderim 20 Kasım 2026'da yapıldı (sürüm 1.2.2).
- **Depoya KONMAYANLAR** (`.gitignore`):
  - `android/key.properties` ve `android/app/sifre_kasam.jks`: imza anahtarı. **Asla depoya eklenmemeli.** Bilgisayarda ayrıca saklanmalı.
  - `*.apk`: derlenmiş dosyalar. Depodan indiren kişi Bölüm 5'teki komutlarla kendisi derler.
  - `build/`, `.dart_tool/`, `.idea/` gibi otomatik üretilen klasörler.
- **Önemli:** Depodan yeni bir bilgisayara indirilirse imza anahtarı orada olmaz. Telefondaki uygulamayı güncelleyebilmek için `key.properties` ve `.jks` dosyalarını eski bilgisayardan (ya da yedekten) aynı konumlara kopyalamak gerekir. Anahtar olmadan yapılan derleme telefondakinin üzerine kurulamaz.
- **Commit kimliği:** Depoda yerel olarak `ibrahimyasar68 <ibrahimyasar68@users.noreply.github.com>` kullanılıyor. Böylece gerçek e-posta adresi GitHub'da görünmüyor.
- **Değişiklik gönderme:**

```bash
cd /Users/ibrahimyasar/Desktop/SifreKasam && git add -A && git status
```

```bash
git commit -m "Kısa açıklama" && git push
```

- `git add` sonrası `git status` çıktısında `key.properties` veya `.jks` görünüyorsa **commit yapmayın**.

## 11. Kullanıcı tercihleri

- Türkçe iletişim kurulur. Büyük değişikliklerden önce plan sunulup onay alınır.
- Sade ve kullanışlı bir uygulama isteniyor. Kullanıcı tasarım geri bildirimlerini doğrudan verir.
- Her değişiklikten sonra yeni APK üretilir ve dosyanın konumu bildirilir.
