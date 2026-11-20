package com.ibrahim.sifre_kasam

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.PersistableBundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity: biyometrik doğrulama için gerekli.
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Ekran görüntüsünü ve "son uygulamalar" önizlemesini engelle.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sifre_kasam/clipboard")
            .setMethodCallHandler { call, result ->
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                when (call.method) {
                    // Metni "hassas" olarak kopyalar: Android 13+ pano önizlemesinde gizlenir.
                    "copySensitive" -> {
                        val clip = ClipData.newPlainText("Şifre Kasam", call.argument<String>("text") ?: "")
                        clip.description.extras = PersistableBundle().apply {
                            if (Build.VERSION.SDK_INT >= 33) {
                                putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
                            } else {
                                putBoolean("android.content.extra.IS_SENSITIVE", true)
                            }
                        }
                        cm.setPrimaryClip(clip)
                        result.success(null)
                    }
                    // Panoda hâlâ bizim kopyaladığımız metin varsa temizler.
                    "clearIfEquals" -> {
                        val expected = call.argument<String>("text")
                        val current = try {
                            cm.primaryClip?.getItemAt(0)?.text?.toString()
                        } catch (e: Exception) { null }
                        // Arka planda pano okunamıyorsa (Android 10+) yine de temizle.
                        if (current == null || current == expected) {
                            if (Build.VERSION.SDK_INT >= 28) cm.clearPrimaryClip()
                            else cm.setPrimaryClip(ClipData.newPlainText("", ""))
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
