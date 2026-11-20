import 'package:flutter/material.dart';

import '../models/note.dart';
import '../services/backup_actions.dart';
import '../services/note_actions.dart';
import '../services/vault.dart';
import '../theme.dart';
import '../utils/turkish.dart';
import '../widgets/shadow_card.dart';
import 'note_detail_screen.dart';
import 'note_edit_screen.dart';
import 'settings_screen.dart';

/// Ana ekran: sabitlenen notlar, harf gruplarına ayrılmış alfabetik kartlar,
/// arama ve sağda hızlı harf çubuğu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _searchHeight = 76.0;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  bool _fabExtended = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final ext = _scroll.offset < 40;
      if (ext != _fabExtended) setState(() => _fabExtended = ext);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        builder: (context, t, child) => Transform.scale(scale: t, child: child),
        child: FloatingActionButton.extended(
          onPressed: () => _open(const NoteEditScreen()),
          isExtended: _fabExtended,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Yeni not'),
        ),
      ),
      body: ListenableBuilder(
        listenable: Vault.instance,
        builder: (context, _) {
          final vault = Vault.instance;
          final all = vault.loaded ? vault.notes : const <Note>[];
          final searching = _query.isNotEmpty;
          final q = trLower(_query);
          final results = searching
              ? all
                    .where(
                      (n) =>
                          trLower(n.title).contains(q) ||
                          trLower(n.username).contains(q) ||
                          trLower(n.body).contains(q),
                    )
                    .toList()
              : all;
          final pinned = searching
              ? const <Note>[]
              : all.where((n) => n.pinned).toList();
          final rest = searching
              ? results
              : all.where((n) => !n.pinned).toList();
          final children = <Widget>[];
          var i = 0;
          if (pinned.isNotEmpty) {
            children.add(
              const _SectionHeader(
                icon: Icons.push_pin_rounded,
                text: 'Sabitlenenler',
              ),
            );
            for (final n in pinned) {
              children.add(_card(n, i++, q));
            }
            if (rest.isNotEmpty) {
              children.add(
                const _SectionHeader(
                  icon: Icons.sort_by_alpha_rounded,
                  text: 'Tüm notlar',
                ),
              );
            }
          }
          for (final n in rest) {
            children.add(_card(n, i++, q));
          }

          return Stack(
            children: [
              // Gizli kaydırma çubuğu: yalnızca kaydırırken belirir;
              // tutup sürükleyerek listede hızla gezilebilir.
              Scrollbar(
                controller: _scroll,
                interactive: true,
                thickness: 6,
                radius: const Radius.circular(8),
                child: CustomScrollView(
                  controller: _scroll,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverAppBar.medium(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.asset(
                              'assets/icon/icon.png',
                              width: 30,
                              height: 30,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('Şifre Kasam'),
                        ],
                      ),
                      actions: [
                        IconButton(
                          tooltip: 'Ayarlar',
                          icon: const Icon(Icons.tune_rounded),
                          onPressed: () => _open(const SettingsScreen()),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          layoutBuilder: (cur, prev) => Stack(
                            alignment: Alignment.centerLeft,
                            children: [...prev, ?cur],
                          ),
                          child: Text(
                            !vault.loaded
                                ? ''
                                : searching
                                ? '${results.length} sonuç'
                                : '${all.length} kayıtlı not',
                            key: ValueKey(
                              '${all.length}-${results.length}-$searching',
                            ),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SearchHeader(
                        height: _searchHeight,
                        background: cs.surface,
                        child: _SearchField(
                          controller: _search,
                          query: _query,
                          onChanged: (v) => setState(() => _query = v.trim()),
                        ),
                      ),
                    ),
                    if (vault.loaded && all.isNotEmpty && !searching)
                      const SliverToBoxAdapter(child: _BackupReminder()),
                    if (vault.error != null)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              vault.error!,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      )
                    else if (!vault.loaded)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (results.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _Empty(hasNotes: all.isNotEmpty),
                      )
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          4,
                          16,
                          110 + MediaQuery.paddingOf(context).bottom,
                        ),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: children,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card(Note n, int index, String q) {
    return Padding(
      key: ValueKey(n.id),
      padding: const EdgeInsets.only(bottom: 8),
      child: EntranceAnimation(
        index: index,
        child: _SwipeActions(
          note: n,
          child: _NoteCard(note: n, query: q),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Kartlar

/// Sağa kaydır: sabitle / kaldır. Sola kaydır: şifreyi kopyala.
/// Silme, detay ekranından yapılır.
class _SwipeActions extends StatelessWidget {
  final Note note;
  final Widget child;
  const _SwipeActions({required this.note, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget bg(Color color, IconData icon, String label, Alignment align) =>
        Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: align,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
    return Dismissible(
      key: ValueKey('swipe-${note.id}'),
      dismissThresholds: const {
        DismissDirection.startToEnd: 0.3,
        DismissDirection.endToStart: 0.4,
      },
      background: bg(
        AppColors.gold,
        note.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
        note.pinned ? 'Kaldır' : 'Sabitle',
        Alignment.centerLeft,
      ),
      secondaryBackground: bg(
        cs.primary,
        Icons.copy_rounded,
        'Şifreyi kopyala',
        Alignment.centerRight,
      ),
      confirmDismiss: (dir) async {
        final messenger = ScaffoldMessenger.of(context);
        if (dir == DismissDirection.startToEnd) {
          await NoteActions.togglePin(messenger, note);
        } else {
          await NoteActions.copyQuick(messenger, note);
        }
        return false; // kart yerinde kalır
      },
      child: child,
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final String query;
  const _NoteCard({required this.note, required this.query});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final title = note.title.trim();
    final bodyMatch =
        query.isNotEmpty &&
        !trLower(title).contains(query) &&
        (trLower(note.username).contains(query) ||
            trLower(note.body).contains(query));
    return ShadowCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteDetailScreen(noteId: note.id)),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'avatar-${note.id}',
            child: LetterAvatar(title: note.title, size: 54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  _highlight(title, query, cs),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Yalnızca aramada, eşleşme başlıkta değilse kısa bir not.
                if (bodyMatch)
                  Row(
                    children: [
                      Icon(
                        Icons.manage_search_rounded,
                        size: 13,
                        color: cs.secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'İçerikte eşleşme',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ],
      ),
    );
  }

  /// Aramada eşleşen kısmı altın renkle vurgular.
  static TextSpan _highlight(String text, String q, ColorScheme cs) {
    if (q.isEmpty) return TextSpan(text: text);
    final lower = trLower(text);
    if (lower.length != text.length) return TextSpan(text: text);
    final spans = <TextSpan>[];
    var start = 0;
    while (true) {
      final i = lower.indexOf(q, start);
      if (i < 0) break;
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(
        TextSpan(
          text: text.substring(i, i + q.length),
          style: TextStyle(
            backgroundColor: AppColors.gold.withValues(alpha: 0.35),
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      start = i + q.length;
    }
    spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(children: spans);
  }
}

// ---------------------------------------------------------------- Başlıklar

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String text;
  const _SectionHeader({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.secondary),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Arama

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      enableIMEPersonalizedLearning: false,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: 'Notlarda ara',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: query.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _SearchHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color background;
  final double height;
  _SearchHeader({
    required this.child,
    required this.background,
    required this.height,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(
      color: background,
      height: maxExtent,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  @override
  bool shouldRebuild(_SearchHeader old) => true;
}

// ---------------------------------------------------------------- Yedek

class _BackupReminder extends StatelessWidget {
  const _BackupReminder();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        BackupActions.lastBackup,
        BackupActions.snoozedUntil,
      ]),
      builder: (context, _) {
        final due = BackupActions.reminderDue;
        final last = BackupActions.lastBackup.value;
        return AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: !due
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [AppColors.navyLight, AppColors.navy],
                      ),
                      boxShadow: AppTheme.cardShadow(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.cloud_upload_rounded,
                              color: AppColors.goldLight,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                last == null
                                    ? 'Henüz yedek almadınız'
                                    : 'Son yedek ${DateTime.now().difference(last).inDays} gün önce',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(34, 4, 8, 0),
                          child: Text(
                            'Telefon kaybolursa notlarınız yalnızca yedekle '
                            'kurtarılabilir.',
                            style: TextStyle(
                              color: Colors.white70,
                              height: 1.3,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: BackupActions.snooze,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                              ),
                              child: const Text('Sonra'),
                            ),
                            TextButton(
                              onPressed: () => BackupActions.export(context),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.goldLight,
                              ),
                              child: const Text(
                                'Yedek al',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final bool hasNotes;
  const _Empty({required this.hasNotes});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return EntranceAnimation(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primaryContainer.withValues(alpha: 0.5),
                ),
                child: Icon(
                  hasNotes
                      ? Icons.search_off_rounded
                      : Icons.lock_outline_rounded,
                  size: 44,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                hasNotes ? 'Sonuç bulunamadı' : 'Kasanız boş',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                hasNotes
                    ? 'Aramanıza uyan not yok.'
                    : '"Yeni not" ile ilk şifrenizi ekleyin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
