import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../services/note_actions.dart';
import '../services/secure_clipboard.dart';
import '../services/vault.dart';
import '../widgets/shadow_card.dart';
import 'note_edit_screen.dart';

/// Bir kaydı gösterir. Şifre buzlu açılır; not kısmında
/// satıra dokununca yalnızca o satır kopyalanır.
class NoteDetailScreen extends StatefulWidget {
  final String noteId;
  const NoteDetailScreen({super.key, required this.noteId});

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen> {
  final _revealed = <String>{};
  String? _copiedField;
  bool _copiedAll = false;
  int? _copiedLine;

  Future<void> _copyField(String key, String label, String value) async {
    await SecureClipboard.copy(value);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copiedField = key);
    _snack('$label kopyalandı · pano 60 sn sonra temizlenir');
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _copiedField == key) setState(() => _copiedField = null);
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  Future<void> _copyLine(int index, String line) async {
    await SecureClipboard.copy(line.trim());
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copiedLine = index);
    _snack('Satır kopyalandı · pano 60 sn sonra temizlenir');
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted && _copiedLine == index) setState(() => _copiedLine = null);
    });
  }

  Future<void> _copyAll(String text) async {
    await SecureClipboard.copy(text);
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copiedAll = true);
    _snack('Not kopyalandı · pano 60 sn sonra temizlenir');
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedAll = false);
    });
  }

  Future<void> _delete(Note note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: Icon(
          Icons.delete_outline_rounded,
          color: Theme.of(c).colorScheme.error,
          size: 36,
        ),
        title: const Text('Not silinsin mi?'),
        content: Text(
          '"${note.title}" silinecek. Hemen ardından geri alabilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    await NoteActions.deleteWithUndo(messenger, note);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Vault.instance,
      builder: (context, _) {
        final note = Vault.instance.byId(widget.noteId);
        if (note == null) return const Scaffold();
        final fmt = DateFormat('d MMMM y, HH:mm', 'tr');
        final lines = note.body.split('\n');
        return Scaffold(
          appBar: AppBar(
            actions: [
              IconButton(
                tooltip: note.pinned ? 'Sabitlemeyi kaldır' : 'En üste sabitle',
                icon: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (c, a) => RotationTransition(
                    turns: Tween(begin: -0.15, end: 0.0).animate(a),
                    child: ScaleTransition(scale: a, child: c),
                  ),
                  child: Icon(
                    note.pinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    key: ValueKey(note.pinned),
                    color: note.pinned ? cs.secondary : null,
                  ),
                ),
                onPressed: () =>
                    NoteActions.togglePin(ScaffoldMessenger.of(context), note),
              ),
              IconButton(
                tooltip: 'Düzenle',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => NoteEditScreen(existing: note),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Sil',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _delete(note),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Row(
                children: [
                  Hero(
                    tag: 'avatar-${note.id}',
                    child: LetterAvatar(title: note.title, size: 60),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: EntranceAnimation(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Son değişiklik: ${fmt.format(note.updatedAt)}',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (note.username.isNotEmpty || note.password.isNotEmpty) ...[
                EntranceAnimation(
                  index: 1,
                  child: ShadowCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      children: [
                        if (note.username.isNotEmpty)
                          _SecretField(
                            icon: Icons.person_outline_rounded,
                            label: 'Kullanıcı adı',
                            value: note.username,
                            secret: false,
                            revealed: true,
                            copied: _copiedField == 'user',
                            onToggle: () {},
                            onCopy: () => _copyField(
                              'user',
                              'Kullanıcı adı',
                              note.username,
                            ),
                          ),
                        if (note.username.isNotEmpty &&
                            note.password.isNotEmpty)
                          Divider(
                            height: 1,
                            indent: 56,
                            color: cs.outlineVariant.withValues(alpha: 0.4),
                          ),
                        if (note.password.isNotEmpty)
                          _SecretField(
                            icon: Icons.key_rounded,
                            label: 'Şifre',
                            value: note.password,
                            monospace: true,
                            revealed: _revealed.contains('pass'),
                            copied: _copiedField == 'pass',
                            onToggle: () => setState(
                              () => _revealed.contains('pass')
                                  ? _revealed.remove('pass')
                                  : _revealed.add('pass'),
                            ),
                            onCopy: () =>
                                _copyField('pass', 'Şifre', note.password),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (note.body.isNotEmpty) ...[
                EntranceAnimation(
                  index: 2,
                  child: ShadowCard(
                    padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 0, 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                size: 18,
                                color: cs.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'NOT',
                                style: TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: cs.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        for (var i = 0; i < lines.length; i++)
                          _LineTile(
                            text: lines[i],
                            copied: _copiedLine == i,
                            onTap: lines[i].trim().isEmpty
                                ? null
                                : () => _copyLine(i, lines[i]),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 15,
                        color: cs.outline,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Satıra dokunun, yalnızca o satır kopyalanır',
                        style: TextStyle(fontSize: 12.5, color: cs.outline),
                      ),
                    ],
                  ),
                ),
              ],
              if (note.body.isEmpty &&
                  note.username.isEmpty &&
                  note.password.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('(boş kayıt)', textAlign: TextAlign.center),
                ),
              if (note.body.isNotEmpty) const SizedBox(height: 20),
              if (note.body.isNotEmpty)
                EntranceAnimation(
                  index: 4,
                  child: SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: note.body.isEmpty
                          ? null
                          : () => _copyAll(note.body),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        transitionBuilder: (c, a) =>
                            ScaleTransition(scale: a, child: c),
                        child: Icon(
                          _copiedAll
                              ? Icons.check_rounded
                              : Icons.copy_all_rounded,
                          key: ValueKey(_copiedAll),
                        ),
                      ),
                      label: Text(
                        _copiedAll ? 'Kopyalandı' : 'Notun tamamını kopyala',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Notun tek bir satırı: dokununca kopyalanır ve kısa süre vurgulanır.
class _LineTile extends StatelessWidget {
  final String text;
  final bool copied;
  final VoidCallback? onTap;
  const _LineTile({required this.text, required this.copied, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (onTap == null) return const SizedBox(height: 14);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: copied
            ? cs.secondary.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(fontSize: 17, height: 1.4),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (c, a) =>
                      ScaleTransition(scale: a, child: c),
                  child: Icon(
                    copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                    key: ValueKey(copied),
                    size: 18,
                    color: copied ? cs.secondary : cs.outlineVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Kopyalanabilir alan (kullanıcı adı / şifre). [secret] ise buzlu açılır ve
/// göz ile görünür olur. Satırın kendisine dokunmak da kopyalar.
class _SecretField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool revealed;
  final bool copied;
  final bool monospace;

  /// false ise alan buzlanmaz ve göster/gizle düğmesi çıkmaz.
  final bool secret;
  final VoidCallback onToggle;
  final VoidCallback onCopy;

  const _SecretField({
    required this.icon,
    required this.label,
    required this.value,
    required this.revealed,
    required this.copied,
    required this.onToggle,
    required this.onCopy,
    this.monospace = false,
    this.secret = true,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: copied
            ? cs.secondary.withValues(alpha: 0.16)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onCopy,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: revealed ? 0 : 6),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        builder: (context, sigma, child) => ExcludeSemantics(
                          excluding: !revealed,
                          child: ImageFiltered(
                            enabled: sigma > 0.05,
                            imageFilter: ImageFilter.blur(
                              sigmaX: sigma,
                              sigmaY: sigma,
                            ),
                            child: child,
                          ),
                        ),
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            fontFamily: monospace ? 'monospace' : null,
                            letterSpacing: monospace ? 0.5 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (secret)
                  IconButton(
                    tooltip: revealed ? 'Gizle' : 'Göster',
                    onPressed: onToggle,
                    icon: Icon(
                      revealed
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 21,
                    ),
                  ),
                IconButton(
                  tooltip: 'Kopyala',
                  onPressed: onCopy,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) =>
                        ScaleTransition(scale: a, child: c),
                    child: Icon(
                      copied ? Icons.check_circle_rounded : Icons.copy_rounded,
                      key: ValueKey(copied),
                      size: 20,
                      color: copied ? cs.secondary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
