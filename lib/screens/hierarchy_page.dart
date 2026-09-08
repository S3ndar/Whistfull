import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/scoring_settings.dart';
import 'package:whistly/theme/app_theme.dart';

class HierarchyPage extends StatelessWidget {
  const HierarchyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(loc.translate('hierarchy_title'))),
      body: ListView(
        padding: const EdgeInsets.all(24.0),
        children: [
          _buildHierarchyTable(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHierarchyTable(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final settings = context.watch<ScoringSettings>();
    final colors = AppTheme.of(context);

    String formatCombined(int askVal, int aloneVal) {
      if (askVal == aloneVal) {
        return '$askVal*';
      }
      return '$askVal* / $aloneVal*';
    }
    
    // Grouped Bids (Names handle the tricks now)
    final List<_BidRow> tableRows = [
      _BidRow(loc.translate('bid_solo_slim'),              '14', '${settings.soloSlim}'),
      _BidRow('${loc.translate('bid_abundance')} (12)',    '13', '${settings.abundanceBase + 3}*'),
      _BidRow(loc.translate('bid_open_misere'),            '12', '${settings.openMisere}'),
      _BidRow('${loc.translate('bid_abundance')} (11)',    '11', '${settings.abundanceBase + 2}*'),
      _BidRow('${loc.translate('bid_abundance')} (10)',    '10', '${settings.abundanceBase + 1}*'),
      _BidRow(loc.translate('bid_misere'),                 '9',  '${settings.misere}'),
      _BidRow(loc.translate('bid_trull'),                  '8',  '${settings.trull}*'),
      _BidRow('${loc.translate('bid_abundance')} (9)',     '7',  '${settings.abundanceBase}*'),
      _BidRow(loc.translate('setup_tricks_n').replaceFirst('{}', '13'), '6', '${settings.askAndJoinBase + 5}*'),
      _BidRow(loc.translate('setup_tricks_n').replaceFirst('{}', '12'), '5', '${settings.askAndJoinBase + 4}*'),
      _BidRow('${loc.translate('setup_tricks_n').replaceFirst('{}', '11')} / ${loc.translate('bid_alone')} (8)', '4', formatCombined(settings.askAndJoinBase + 3, settings.aloneBase + 3)),
      _BidRow('${loc.translate('setup_tricks_n').replaceFirst('{}', '10')} / ${loc.translate('bid_alone')} (7)', '3', formatCombined(settings.askAndJoinBase + 2, settings.aloneBase + 2)),
      _BidRow('${loc.translate('setup_tricks_n').replaceFirst('{}', '9')} / ${loc.translate('bid_alone')} (6)', '2', formatCombined(settings.askAndJoinBase + 1, settings.aloneBase + 1)),
      _BidRow('${loc.translate('setup_tricks_n').replaceFirst('{}', '8')} / ${loc.translate('bid_alone')} (5)', '1 (Min)', formatCombined(settings.askAndJoinBase, settings.aloneBase)),
    ];

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Table(
            border: TableBorder.all(color: colors.borderFaint, width: 1),
            // Column 0 was FlexColumnWidth(1.2) — too narrow for the
            // "Priority" header at this font size, which wrapped mid-word
            // ("Priori"/"ty" on two lines). Widened at column 1's expense.
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(4),
              2: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: colors.surface),
                children: [
                  _tableHeader(context, loc.translate('rules_table_priority')),
                  _tableHeader(context, loc.translate('rules_table_type')),
                  _tableHeader(context, loc.translate('rules_table_base')),
                ],
              ),
              ...tableRows.asMap().entries.map((e) {
                final isEven = e.key.isEven;
                final row = e.value;
                return TableRow(
                  decoration: BoxDecoration(
                    color: isEven ? colors.background : colors.surface,
                  ),
                  children: [
                    _tableCell(context, row.priority, center: true),
                    _tableCell(context, row.name, bold: true),
                    _tableCell(context, row.basePoints, center: true),
                  ],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          loc.translate('rules_footer_note'),
          style: TextStyle(fontSize: 12, color: colors.textFaint, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  static Widget _tableHeader(BuildContext context, String text) {
    final colors = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: colors.textPrimary), textAlign: TextAlign.center),
    );
  }

  static Widget _tableCell(BuildContext context, String text, {bool bold = false, bool center = false}) {
    final colors = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: colors.textSecondary,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
        textAlign: center ? TextAlign.center : TextAlign.start,
      ),
    );
  }
}

class _BidRow {
  final String name;
  final String priority;
  final String basePoints;
  const _BidRow(this.name, this.priority, this.basePoints);
}
