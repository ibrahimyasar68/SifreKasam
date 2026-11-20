import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Güçlü şifre üretici. Seçilen şifreyi döndürür (iptalde null).
Future<String?> showPasswordGenerator(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _GeneratorSheet(),
  );
}

class _GeneratorSheet extends StatefulWidget {
  const _GeneratorSheet();
  @override
  State<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<_GeneratorSheet> {
  static const _lower = 'abcdefghijkmnopqrstuvwxyz';
  static const _upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const _digits = '23456789';
  static const _symbols = '!@#\$%&*?-_+=';

  double _length = 16;
  bool _useUpper = true;
  bool _useDigits = true;
  bool _useSymbols = true;
  String _value = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    final r = Random.secure();
    final sets = [
      _lower,
      if (_useUpper) _upper,
      if (_useDigits) _digits,
      if (_useSymbols) _symbols,
    ];
    final all = sets.join();
    // Her seçili gruptan en az bir karakter olsun.
    final chars = [for (final s in sets) s[r.nextInt(s.length)]];
    while (chars.length < _length.round()) {
      chars.add(all[r.nextInt(all.length)]);
    }
    chars.shuffle(r);
    setState(() => _value = chars.join());
    HapticFeedback.selectionClick();
  }

  String get _strength {
    var pool = _lower.length;
    if (_useUpper) pool += _upper.length;
    if (_useDigits) pool += _digits.length;
    if (_useSymbols) pool += _symbols.length;
    final bits = _length * log(pool) / ln2;
    if (bits >= 90) return 'Çok güçlü';
    if (bits >= 65) return 'Güçlü';
    if (bits >= 45) return 'Orta';
    return 'Zayıf';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final strength = _strength;
    final strengthColor = switch (strength) {
      'Çok güçlü' => Colors.green,
      'Güçlü' => Colors.lightGreen,
      'Orta' => Colors.orange,
      _ => cs.error,
    };
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Şifre üret',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 6, 14),
              decoration: BoxDecoration(
                color: AppTheme.cardColor(context),
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppTheme.cardShadow(context),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (c, a) => FadeTransition(
                        opacity: a,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(0, 0.4),
                            end: Offset.zero,
                          ).animate(a),
                          child: c,
                        ),
                      ),
                      child: Text(
                        _value,
                        key: ValueKey(_value),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Yeniden üret',
                    onPressed: _generate,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.shield_rounded, size: 16, color: strengthColor),
                const SizedBox(width: 6),
                Text(
                  strength,
                  style: TextStyle(
                    color: strengthColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Uzunluk'),
                Expanded(
                  child: Slider(
                    value: _length,
                    min: 8,
                    max: 32,
                    divisions: 24,
                    label: '${_length.round()}',
                    onChanged: (v) {
                      _length = v;
                      _generate();
                    },
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: Text(
                    '${_length.round()}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Büyük harf'),
                  selected: _useUpper,
                  onSelected: (v) {
                    _useUpper = v;
                    _generate();
                  },
                ),
                FilterChip(
                  label: const Text('Rakam'),
                  selected: _useDigits,
                  onSelected: (v) {
                    _useDigits = v;
                    _generate();
                  },
                ),
                FilterChip(
                  label: const Text('Sembol'),
                  selected: _useSymbols,
                  onSelected: (v) {
                    _useSymbols = v;
                    _generate();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context, _value),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nota ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
