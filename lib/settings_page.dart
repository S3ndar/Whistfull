import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/theme_provider.dart';
import 'package:whistly/theme/app_theme.dart';
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
    final textSecondary = colors.textMuted;
    final dividerColor = colors.border;

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('settings_title'))),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          // Language Selection
          Text(
            loc.translate('settings_language'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            segments: [
              ButtonSegment<AppLanguage>(
                value: AppLanguage.en,
                label: Text('🇺🇸 ${loc.translate('settings_lang_en')}'),
                icon: const Icon(Icons.language),
              ),
              ButtonSegment<AppLanguage>(
                value: AppLanguage.nl,
                label: Text('🇳🇱 ${loc.translate('settings_lang_nl')}'),
                icon: const Icon(Icons.language),
              ),
            ],
            selected: {loc.currentLanguage},
            onSelectionChanged: (newSelection) {
              loc.setLanguage(newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.selectedBg,
              selectedForegroundColor: AppColors.white,
            ),
          ),
          const SizedBox(height: 24),

          // Appearance (Theme) Selection
          Text(
            loc.translate('settings_theme'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                label: Text(loc.translate('settings_theme_dark')),
                icon: const Icon(Icons.dark_mode_outlined),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                label: Text(loc.translate('settings_theme_light')),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                label: Text(loc.translate('settings_theme_system')),
                icon: const Icon(Icons.brightness_auto_outlined),
              ),
            ],
            selected: {themeProvider.themeMode},
            onSelectionChanged: (newSelection) {
              themeProvider.setThemeMode(newSelection.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.selectedBg,
              selectedForegroundColor: AppColors.white,
            ),
          ),
          const SizedBox(height: 32),
          Divider(color: dividerColor),
          const SizedBox(height: 16),

          Text(
            loc.translate('settings_adjust'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            loc.translate('settings_auto_save'),
            style: TextStyle(fontSize: 14, color: textSecondary),
          ),
          const SizedBox(height: 24),

          // Partnership Contracts Card
          _ScoringCard(
            title: loc.translate('settings_partnership'),
            icon: Icons.people_outline,
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

          // Solo Contracts Card (Including Misery)
          _ScoringCard(
            title: loc.translate('settings_solo'),
            icon: Icons.person_outline,
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



          const SizedBox(height: 8),
          _SupportSection(),

          const SizedBox(height: 24),
          Divider(color: dividerColor),
          const SizedBox(height: 16),

          // Danger Zone
          _sectionHeader(context, loc.translate('settings_danger_zone'), isDanger: true),
          const SizedBox(height: 8),
          
          ListTile(
            onTap: () => _showDeleteConfirmation(context, loc),
            tileColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.danger.withValues(alpha: 0.1)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: Text(
              loc.translate('settings_delete_all'),
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
            ),
            trailing: Icon(Icons.chevron_right, color: colors.textFaint),
          ),
          const SizedBox(height: 64),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, LocalizationProvider loc) {
    showDialog(
      context: context,
      builder: (ctx) {
        final dialogColors = AppTheme.of(ctx);
        return AlertDialog(
        backgroundColor: dialogColors.surfaceDim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.translate('delete_confirm_title'),
          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
        ),
        content: Text(
          loc.translate('delete_confirm_desc'),
          style: TextStyle(color: dialogColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('cancel'), style: TextStyle(color: dialogColors.textFaint)),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(loc.translate('delete_confirm_btn')),
          ),
        ],
        );
      },
    );
  }

  Widget _sectionHeader(BuildContext context, String title, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDanger ? AppColors.danger : AppTheme.of(context).error,
        ),
      ),
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

    return _ScoringCard(
      title: loc.translate('settings_support'),
      icon: Icons.favorite_border,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.translate('settings_remove_ads_desc'),
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: purchase.adsRemoved
                    ? OutlinedButton.icon(
                        onPressed: null,
                        icon: Icon(Icons.check_circle, color: colors.success),
                        label: Text(
                          loc.translate('settings_purchased'),
                          style: TextStyle(color: colors.success, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.success),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: purchase.purchasePending ? null : () => purchase.buyRemoveAds(),
                        child: purchase.purchasePending
                            ? SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: colors.textPrimary),
                              )
                            : Text('${loc.translate('settings_remove_ads')} — $priceLabel'),
                      ),
              ),
              const SizedBox(height: 4),
              Center(
                child: TextButton(
                  onPressed: purchase.purchasePending ? null : () => purchase.restorePurchases(),
                  child: Text(
                    loc.translate('settings_restore'),
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScoringCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _ScoringCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderFaint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(icon, color: colors.error, size: 20),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: children),
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.borderFaint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.remove, size: 18, color: colors.error),
                  onPressed: value > 0 ? () => onChanged(value - 1) : null,
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.add, size: 18, color: colors.error),
                  onPressed: () => onChanged(value + 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
