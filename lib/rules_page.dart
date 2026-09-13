import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/screens/hierarchy_page.dart';

import 'theme/app_theme.dart';
import 'theme/whistly_components.dart';
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
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.translate('rules_title').split('(').first.trim(), style: WhistlyText.sectionHead(colors.ink)),
                        const SizedBox(height: 4),
                        Text(loc.translate('rules_hero'), style: WhistlyText.body(colors.muted, size: 14)),
                      ],
                    ),
                  ),

                  _buildExpansionSection(
                    context: context,
                    title: loc.translate('rules_section1_title'),
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
                    children: [
                      Text(loc.translate('rules_sec3_intro_desc'), style: WhistlyText.body(colors.muted, size: 13)),
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
                    children: [
                      _RuleStep(title: loc.translate('rules_sec4_lead_title'), desc: loc.translate('rules_sec4_lead_desc')),
                      _RuleStep(title: loc.translate('rules_sec4_follow_title'), desc: loc.translate('rules_sec4_follow_desc'), isHighlighted: true),
                      _RuleStep(title: loc.translate('rules_sec4_win_title'), desc: loc.translate('rules_sec4_win_desc')),
                    ],
                  ),

                  _buildExpansionSection(
                    context: context,
                    title: loc.translate('rules_section5_title'),
                    children: [
                      _RuleStep(title: loc.translate('rules_sec5_success_title'), desc: loc.translate('rules_sec5_success_desc')),
                      _RuleStep(title: loc.translate('rules_sec5_bonus_title'), desc: loc.translate('rules_sec5_bonus_desc')),
                      _RuleStep(title: loc.translate('rules_sec5_fail_title'), desc: loc.translate('rules_sec5_fail_desc')),
                      const SizedBox(height: 12),
                      Text(loc.translate('rules_sec5_hierarchy_cta'), style: WhistlyText.body(colors.muted, size: 13)),
                      const SizedBox(height: 16),
                      WhistlySecondaryButton(
                        label: loc.translate('rules_view_hierarchy'),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const HierarchyPage()));
                        },
                        border: Border.all(color: colors.line, width: 2),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),

                  const SizedBox(height: 24),
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

  Widget _buildExpansionSection({required BuildContext context, required String title, required List<Widget> children}) {
    final colors = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.line, width: 2))),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          iconColor: colors.ink,
          collapsedIconColor: colors.muted,
          tilePadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
          title: Text(title, style: WhistlyText.rowTitle(colors.ink)),
          childrenPadding: const EdgeInsets.only(left: 22, right: 22, bottom: 20),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
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
      padding: const EdgeInsets.only(left: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: isHighlighted ? colors.accent : colors.line, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: WhistlyText.rowTitle(colors.ink)),
          const SizedBox(height: 6),
          Text(desc, style: WhistlyText.body(colors.muted, size: 13).copyWith(height: 1.5)),
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
      (loc.translate('rules_suit_hearts'), '♥', true),
      (loc.translate('rules_suit_diamonds'), '♦', true),
      (loc.translate('rules_suit_clubs'), '♣', false),
      (loc.translate('rules_suit_spades'), '♠', false),
    ];

    return Container(
      color: colors.line,
      child: Row(
        children: List.generate(suits.length, (i) {
          final (name, glyph, isRed) = suits[i];
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
              color: colors.bg,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(glyph, style: TextStyle(fontSize: 24, color: isRed ? colors.suitRed : colors.suitInk)),
                  const SizedBox(height: 4),
                  Text(name, style: WhistlyText.body(colors.muted, size: 11)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
