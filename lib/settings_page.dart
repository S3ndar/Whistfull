import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/theme_provider.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:whistly/billing/purchase_provider.dart';
import 'scoring_settings.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<ScoringSettings>();
    final loc = context.watch<LocalizationProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final colors = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('settings_title'))),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.translate('settings_language').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
                const SizedBox(height: 10),
                WhistlyToggleRow<AppLanguage>(
                  options: [
                    (AppLanguage.en, loc.translate('settings_lang_en')),
                    (AppLanguage.nl, loc.translate('settings_lang_nl')),
                  ],
                  selected: loc.currentLanguage,
                  onChanged: (val) => loc.setLanguage(val),
                ),
                const SizedBox(height: 24),
                Text(loc.translate('settings_theme').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
                const SizedBox(height: 10),
                WhistlyToggleRow<ThemeMode>(
                  options: [
                    (ThemeMode.dark, loc.translate('settings_theme_dark')),
                    (ThemeMode.light, loc.translate('settings_theme_light')),
                    (ThemeMode.system, loc.translate('settings_theme_system')),
                  ],
                  selected: themeProvider.themeMode,
                  onChanged: (val) => themeProvider.setThemeMode(val),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line, width: 2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.translate('settings_adjust'), style: WhistlyText.sectionHead(colors.ink)),
                const SizedBox(height: 4),
                Text(loc.translate('settings_auto_save'), style: WhistlyText.body(colors.muted, size: 13)),
              ],
            ),
          ),

          _ScoringSection(
            title: loc.translate('settings_partnership'),
            children: [
              _ScoreAdjustmentRow(
                title: loc.translate('bid_ask_join'),
                value: settings.askAndJoinBase,
                onChanged: (val) => context.read<ScoringSettings>().updateScore(askAndJoinBase: val),
              ),
              _ScoreAdjustmentRow(
                title: loc.translate('bid_trull'),
                value: settings.trull,
                onChanged: (val) => context.read<ScoringSettings>().updateScore(trull: val),
              ),
            ],
          ),

          _ScoringSection(
            title: loc.translate('settings_solo'),
            children: [
              _ScoreAdjustmentRow(
                title: loc.translate('bid_alone'),
                value: settings.aloneBase,
                onChanged: (val) => context.read<ScoringSettings>().updateScore(aloneBase: val),
              ),
              _ScoreAdjustmentRow(
                title: loc.translate('bid_abundance'),
                value: settings.abundanceBase,
                onChanged: (val) => context.read<ScoringSettings>().updateScore(abundanceBase: val),
              ),
              _ScoreAdjustmentRow(
                title: loc.translate('bid_misere'),
                value: settings.misere,
                onChanged: (val) => context.read<ScoringSettings>().updateScore(misere: val),
              ),
              _ScoreAdjustmentRow(
                title: loc.translate('bid_open_misere'),
                value: settings.openMisere,
                onChanged: (val) => context.read<ScoringSettings>().updateScore(openMisere: val),
              ),
              _ScoreAdjustmentRow(
                title: loc.translate('bid_solo_slim'),
                value: settings.soloSlim,
                onChanged: (val) => context.read<ScoringSettings>().updateScore(soloSlim: val),
              ),
            ],
          ),

          _SupportSection(),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
            child: Text(
              loc.translate('settings_danger_zone').toUpperCase(),
              style: WhistlyText.eyebrow(colors.accent),
            ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line, width: 2))),
            child: InkWell(
              onTap: () => _showDeleteConfirmation(context, loc),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: colors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        loc.translate('settings_delete_all'),
                        style: WhistlyText.rowTitle(colors.accent),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: colors.muted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, LocalizationProvider loc) {
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = AppTheme.of(ctx);
        return AlertDialog(
          title: Text(loc.translate('delete_confirm_title'), style: WhistlyText.sectionHead(colors.accent)),
          content: Text(loc.translate('delete_confirm_desc'), style: WhistlyText.body(colors.muted, size: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.translate('cancel').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
            ),
            TextButton(
              onPressed: () async {
                final pp = context.read<PlayerProvider>();
                final gp = context.read<GameProvider>();
                await pp.clearAll();
                await gp.clearAllData();
                if (context.mounted) {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data has been cleared.')),
                  );
                }
              },
              child: Text(loc.translate('delete_confirm_btn').toUpperCase(), style: WhistlyText.eyebrow(colors.accent)),
            ),
          ],
        );
      },
    );
  }
}

/// "Support" section: a "Remove ads" purchase button and an always-visible
/// "Restore purchases" control (Apple requires the latter to be visible
/// regardless of purchase state). Stateful only so it can show a one-shot
/// SnackBar for purchase/restore results without re-showing it on every
/// rebuild.
class _SupportSection extends StatefulWidget {
  const _SupportSection();

  @override
  State<_SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<_SupportSection> {
  String? _lastShownMessageKey;

  @override
  Widget build(BuildContext context) {
    final purchase = context.watch<PurchaseProvider>();
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    final messageKey = purchase.lastMessageKey;
    if (messageKey != null && messageKey != _lastShownMessageKey) {
      _lastShownMessageKey = messageKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.translate(messageKey))),
        );
        purchase.clearMessage();
      });
    }

    final priceLabel = purchase.removeAdsProduct?.price ?? '€2.99';

    return _ScoringSection(
      title: loc.translate('settings_support'),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.translate('settings_remove_ads_desc'), style: WhistlyText.body(colors.muted, size: 13)),
              const SizedBox(height: 12),
              purchase.adsRemoved
                  ? Row(
                      children: [
                        Icon(Icons.check_circle, color: colors.ink, size: 18),
                        const SizedBox(width: 8),
                        Text(loc.translate('settings_purchased'), style: WhistlyText.rowTitle(colors.ink)),
                      ],
                    )
                  : WhistlyPrimaryButton(
                      label: purchase.purchasePending
                          ? '…'
                          : '${loc.translate('settings_remove_ads')} — $priceLabel',
                      showChevron: false,
                      onPressed: purchase.purchasePending ? null : () => purchase.buyRemoveAds(),
                    ),
              const SizedBox(height: 4),
              Center(
                child: WhistlyTextAction(
                  label: loc.translate('settings_restore'),
                  onPressed: purchase.purchasePending ? null : () => purchase.restorePurchases(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A settings section: eyebrow+title header with a 2px top rule, then its
/// rows (spec §3: separation is a rule, never a surface tint).
class _ScoringSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _ScoringSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line, width: 2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
            child: Text(title.toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ScoreAdjustmentRow extends StatelessWidget {
  final String title;
  final int value;
  final ValueChanged<int> onChanged;

  const _ScoreAdjustmentRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final loc = context.watch<LocalizationProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: WhistlyText.rowTitle(colors.ink)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.remove, size: 18, color: colors.ink),
            tooltip: loc.translate('settings_decrease').replaceFirst('{}', title),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 30,
            child: Text('$value', textAlign: TextAlign.center, style: WhistlyText.mono(colors.ink, size: 16, weight: FontWeight.w800)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.add, size: 18, color: colors.ink),
            tooltip: loc.translate('settings_increase').replaceFirst('{}', title),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}
