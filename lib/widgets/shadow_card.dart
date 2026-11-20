import 'package:flutter/material.dart';

import '../theme.dart';

/// Gölgeli, yuvarlak köşeli kart. Dokununca hafifçe içeri basılır.
class ShadowCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  const ShadowCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
  });

  @override
  State<ShadowCard> createState() => _ShadowCardState();
}

class _ShadowCardState extends State<ShadowCard> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap != null && _pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          color: AppTheme.cardColor(context),
          borderRadius: r,
          boxShadow: AppTheme.cardShadow(context, pressed: _pressed),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: r,
            onTap: widget.onTap,
            onHighlightChanged: _set,
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );
  }
}

/// Listeye giren öğeler için aşağıdan kayarak belirme animasyonu.
class EntranceAnimation extends StatelessWidget {
  final Widget child;
  final int index;
  const EntranceAnimation({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    final ms = 280 + (index.clamp(0, 10) * 45);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Başlığın ilk harfini gradyanlı yuvarlak kare içinde gösterir.
class LetterAvatar extends StatelessWidget {
  final String title;
  final double size;
  const LetterAvatar({super.key, required this.title, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final t = title.trim();
    final first = t.isEmpty ? '?' : t.characters.first;
    final letter = first == 'i'
        ? 'İ'
        : first == 'ı'
        ? 'I'
        : first.toUpperCase();
    final g =
        AppColors.avatarGradients[letter.codeUnitAt(0) %
            AppColors.avatarGradients.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: g,
        ),
        boxShadow: [
          BoxShadow(
            color: g.last.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
