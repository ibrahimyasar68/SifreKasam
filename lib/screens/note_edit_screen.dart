import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/vault.dart';
import '../widgets/password_generator.dart';
import '../widgets/shadow_card.dart';

/// Yeni kayıt ekleme veya düzenleme: başlık, kullanıcı adı, şifre, not.
class NoteEditScreen extends StatefulWidget {
  final Note? existing;
  const NoteEditScreen({super.key, this.existing});
  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _user = TextEditingController(text: widget.existing?.username);
  late final _pass = TextEditingController(text: widget.existing?.password);
  late final _body = TextEditingController(text: widget.existing?.body);
  bool _saving = false;
  bool _showPass = false;
  String? _titleError;

  bool get _dirty =>
      _title.text != (widget.existing?.title ?? '') ||
      _user.text != (widget.existing?.username ?? '') ||
      _pass.text != (widget.existing?.password ?? '') ||
      _body.text != (widget.existing?.body ?? '');

  @override
  void dispose() {
    _title.dispose();
    _user.dispose();
    _pass.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Konu başlığı boş olamaz');
      return;
    }
    setState(() => _saving = true);
    final user = _user.text.trim();
    final pass = _pass.text;
    final body = _body.text;
    final note = widget.existing == null
        ? Note.create(title: title, username: user, password: pass, body: body)
        : widget.existing!.copyWith(
            title: title,
            username: user,
            password: pass,
            body: body,
          );
    try {
      await Vault.instance.upsert(note);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    }
  }

  /// Üretilen şifreyi şifre alanına yazar.
  Future<void> _generate() async {
    final pw = await showPasswordGenerator(context);
    if (pw == null) return;
    setState(() {
      _pass.text = pw;
      _showPass = true;
    });
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Değişiklikler kaydedilmedi'),
        content: const Text('Çıkarsanız yaptığınız değişiklikler kaybolacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Çık'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Düzenlemeye devam et'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existing == null ? 'Yeni not' : 'Notu düzenle'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Kaydet'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            24 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            EntranceAnimation(
              child: TextField(
                controller: _title,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                enableIMEPersonalizedLearning: false,
                onChanged: (_) => setState(() => _titleError = null),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Konu başlığı',
                  hintText: 'ör. E-posta, Banka, Wi-Fi',
                  errorText: _titleError,
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            EntranceAnimation(
              index: 1,
              child: TextField(
                controller: _user,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Kullanıcı adı',
                  hintText: 'ör. ad@ornek.com',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
            ),
            const SizedBox(height: 14),
            EntranceAnimation(
              index: 2,
              child: TextField(
                controller: _pass,
                obscureText: !_showPass,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.visiblePassword,
                autocorrect: false,
                enableSuggestions: false,
                enableIMEPersonalizedLearning: false,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  prefixIcon: const Icon(Icons.key_rounded),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _showPass ? 'Gizle' : 'Göster',
                        icon: Icon(
                          _showPass
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                        ),
                        onPressed: () => setState(() => _showPass = !_showPass),
                      ),
                      IconButton(
                        tooltip: 'Güçlü şifre üret',
                        icon: const Icon(Icons.auto_awesome_rounded),
                        onPressed: _generate,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            EntranceAnimation(
              index: 3,
              child: TextField(
                controller: _body,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.multiline,
                minLines: 6,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                enableSuggestions: false,
                autocorrect: false,
                enableIMEPersonalizedLearning: false,
                style: const TextStyle(fontSize: 16, height: 1.5),
                decoration: const InputDecoration(
                  labelText: 'Not',
                  hintText: 'Ek bilgiler, açıklamalar…',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
