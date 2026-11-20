import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/security.dart';
import '../theme.dart';

/// 6 haneli PIN girişi için nokta göstergesi ve sayı tuş takımı.
class PinPad extends StatefulWidget {
  final String title;
  final String? message;
  final bool isError;
  final bool enabled;

  /// Her artışında noktalar "hayır" der gibi sallanır (yanlış PIN).
  final int errorTick;

  /// PIN tamamlandığında çağrılır. İşlem bitince alan temizlenir.
  final Future<void> Function(String pin) onCompleted;

  /// Sol alttaki tuş (ör. parmak izi). Yoksa boş kalır.
  final Widget? extraKey;

  const PinPad({
    super.key,
    required this.title,
    required this.onCompleted,
    this.message,
    this.isError = false,
    this.enabled = true,
    this.errorTick = 0,
    this.extraKey,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  bool _busy = false;
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (widget.errorTick != old.errorTick) _shake.forward(from: 0);
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _press(String d) async {
    if (!widget.enabled || _busy || _pin.length >= Security.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() => _pin += d);
    if (_pin.length == Security.pinLength) {
      setState(() => _busy = true);
      try {
        await widget.onCompleted(_pin);
      } finally {
        if (mounted) {
          setState(() {
            _pin = '';
            _busy = false;
          });
        }
      }
    }
  }

  void _back() {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = cs.brightness == Brightness.dark
        ? AppColors.gold
        : cs.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.3),
                end: Offset.zero,
              ).animate(a),
              child: c,
            ),
          ),
          child: Text(
            widget.title,
            key: ValueKey(widget.title),
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 22),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
              sin(_shake.value * pi * 6) * 14 * (1 - _shake.value),
              0,
            ),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(Security.pinLength, (i) {
              final filled = i < _pin.length;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: filled ? 18 : 14,
                height: filled ? 18 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled
                      ? (widget.isError && _pin.isEmpty ? cs.error : accent)
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.isError ? cs.error : accent,
                    width: 2,
                  ),
                  boxShadow: filled
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ),
        SizedBox(
          height: 52,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      widget.message ?? '',
                      key: ValueKey(widget.message),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: widget.isError ? cs.error : cs.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final d in row)
                _Key(label: d, onTap: widget.enabled ? () => _press(d) : null),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 92,
              height: 80,
              child: Center(child: widget.extraKey),
            ),
            _Key(label: '0', onTap: widget.enabled ? () => _press('0') : null),
            SizedBox(
              width: 92,
              height: 80,
              child: IconButton(
                onPressed: _back,
                icon: const Icon(Icons.backspace_outlined),
                tooltip: 'Sil',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Basınca büyüyüp parlayan yuvarlak sayı tuşu.
class _Key extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _Key({required this.label, this.onTap});
  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = cs.brightness == Brightness.dark;
    final base = dark ? Colors.white : AppColors.navy;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: GestureDetector(
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: base.withValues(alpha: _down ? 0.22 : 0.07),
            border: Border.all(color: base.withValues(alpha: 0.12)),
          ),
          alignment: Alignment.center,
          child: AnimatedScale(
            scale: _down ? 1.15 : 1,
            duration: const Duration(milliseconds: 120),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: widget.onTap == null
                    ? cs.onSurface.withValues(alpha: 0.3)
                    : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
