import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/screens/hierarchy_page.dart';

import 'app_colors.dart';
import 'theme/app_theme.dart';
import 'ads/banner_ad_widget.dart';

class RulesPage extends StatelessWidget {
  const RulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('rules_title'))),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              loc.translate('rules_title').split('(').first.trim(),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              loc.translate('rules_hero'),
              style: TextStyle(fontSize: 16, color: colors.textMuted),
            ),
          ),
          const SizedBox(height: 32),

          // Expansion Sections
          _buildExpansionSection(
            context: context,
            title: loc.translate('rules_section1_title'),
            icon: Icons.info_outline,
            children: [
              _RuleStep(title: loc.translate('rules_sec1_obj_title'), desc: loc.translate('rules_sec1_obj_desc')),
              _RuleStep(title: loc.translate('rules_sec1_cards_title'), desc: loc.translate('rules_sec1_cards_desc')),
              _RuleStep(title: loc.translate('rules_sec1_trump_title'), desc: loc.translate('rules_sec1_trump_desc')),
              _RuleStep(title: loc.translate('rules_sec1_deal_title'), desc: loc.translate('rules_sec1_deal_desc')),
            ],
          ),

          _buildExpansionSection(
            context: context,
            title: loc.translate('rules_section2_title'),
            icon: Icons.gavel,
            children: [
              _RuleStep(title: loc.translate('rules_sec2_stage1_title'), desc: loc.translate('rules_sec2_stage1_desc')),
              _RuleStep(title: loc.translate('rules_sec2_stage2_title'), desc: loc.translate('rules_sec2_stage2_desc')),
              _RuleStep(title: loc.translate('rules_sec2_stage3_title'), desc: loc.translate('rules_sec2_stage3_desc')),
              const _SuitPriorityRow(),
              const SizedBox(height: 8),
            ],
          ),

          _buildExpansionSection(
            context: context,
            title: loc.translate('rules_section3_title'),
            icon: Icons.star_border,
            children: [
              Text(
                loc.translate('rules_sec3_intro_desc'),
                style: TextStyle(fontSize: 15, color: colors.textSecondary, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              _RuleStep(title: loc.translate('rules_sec3_trull_title'), desc: loc.translate('rules_sec3_trull_desc')),
              _RuleStep(title: loc.translate('rules_sec3_alone_title'), desc: loc.translate('rules_sec3_alone_desc')),
              _RuleStep(title: loc.translate('rules_sec3_misery_title'), desc: loc.translate('rules_sec3_misery_desc')),
              _RuleStep(title: loc.translate('rules_sec3_abundance_title'), desc: loc.translate('rules_sec3_abundance_desc')),
              _RuleStep(title: loc.translate('rules_sec3_soloslim_title'), desc: loc.translate('rules_sec3_soloslim_desc')),
            ],
          ),

          _buildExpansionSection(
            context: context,
            title: loc.translate('rules_section4_title'),
            icon: Icons.play_arrow_outlined,
            children: [
              _RuleStep(title: loc.translate('rules_sec4_lead_title'), desc: loc.translate('rules_sec4_lead_desc')),
              _RuleStep(title: loc.translate('rules_sec4_follow_title'), desc: loc.translate('rules_sec4_follow_desc'), isHighlighted: true),
              _RuleStep(title: loc.translate('rules_sec4_win_title'), desc: loc.translate('rules_sec4_win_desc')),
            ],
          ),

          _buildExpansionSection(
            context: context,
            title: loc.translate('rules_section5_title'),
            icon: Icons.calculate_outlined,
            children: [
              _RuleStep(title: loc.translate('rules_sec5_success_title'), desc: loc.translate('rules_sec5_success_desc')),
              _RuleStep(title: loc.translate('rules_sec5_bonus_title'), desc: loc.translate('rules_sec5_bonus_desc')),
              _RuleStep(title: loc.translate('rules_sec5_fail_title'), desc: loc.translate('rules_sec5_fail_desc')),
              const SizedBox(height: 12),
              Text(
                loc.translate('rules_sec5_hierarchy_cta'),
                style: TextStyle(fontSize: 14, color: colors.textMuted, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const HierarchyPage()));
                  },
                  icon: const Icon(Icons.table_chart),
                  label: Text(loc.translate('rules_view_hierarchy')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
          
          const SizedBox(height: 48),
        ],
              ),
            ),
            // Reserves its own height and collapses entirely once ads are
            // removed — this page has no floating action button, so
            // there is no accidental-tap risk here.
            const AdaptiveBannerAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildExpansionSection({required BuildContext context, required String title, required IconData icon, required List<Widget> children,}) {
    final colors = AppTheme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        iconColor: Theme.of(context).colorScheme.secondary,
        collapsedIconColor: colors.textMuted,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
        childrenPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _RuleStep extends StatelessWidget {
  final String title;
  final String desc;
  final bool isHighlighted;

  const _RuleStep({
    required this.title,
    required this.desc,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isHighlighted ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : colors.scrim,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted ? Theme.of(context).colorScheme.secondary : colors.borderFaint,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isHighlighted ? Theme.of(context).colorScheme.secondary : colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: TextStyle(fontSize: 14, color: colors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SuitPriorityRow extends StatelessWidget {
  const _SuitPriorityRow();

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);
    final suits = [
      {'icon': '♥', 'name': loc.translate('rules_suit_hearts'), 'color': AppColors.suitRed},
      {'icon': '♦', 'name': loc.translate('rules_suit_diamonds'), 'color': AppColors.suitRed},
      {'icon': '♣', 'name': loc.translate('rules_suit_clubs'), 'color': AppColors.suitBlack},
      {'icon': '♠', 'name': loc.translate('rules_suit_spades'), 'color': AppColors.suitBlack},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.borderFaint,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: suits.map((s) {
          return Column(
            children: [
              Text(s['icon'] as String, style: TextStyle(fontSize: 28, color: s['color'] as Color)),
              const SizedBox(height: 4),
              Text(s['name'] as String, style: TextStyle(fontSize: 12, color: colors.textMuted)),
            ],
          );
        }).toList(),
      ),
    );
  }
}
