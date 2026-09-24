import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/screens/player_stats_page.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:whistly/ads/banner_ad_widget.dart';
import 'package:whistly/stats/crown_badge.dart';

class PlayersPage extends StatelessWidget {
  const PlayersPage({super.key});

  void _showAddPlayerDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    final loc = context.read<LocalizationProvider>();

    showDialog(
      context: context,
      builder: (context) {
        final colors = AppTheme.of(context);
        return AlertDialog(
          title: Text(loc.translate('players_add_new'), style: WhistlyText.sectionHead(colors.ink)),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: WhistlyText.rowTitle(colors.ink),
            decoration: InputDecoration(
              labelText: loc.translate('players_name_label'),
              labelStyle: WhistlyText.body(colors.muted),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: colors.line)),
              border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: colors.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: colors.ink, width: 2)),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.translate('cancel').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  context.read<PlayerProvider>().addPlayer(name);
                  Navigator.pop(context);
                }
              },
              child: Text(loc.translate('add').toUpperCase(), style: WhistlyText.eyebrow(colors.ink)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('players_title')),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: playerProvider.players.length < 4,
              backgroundColor: colors.accent,
              smallSize: 8,
              child: Icon(Icons.person_add, color: colors.ink),
            ),
            onPressed: () => _showAddPlayerDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Text(loc.translate('players_desc'), style: WhistlyText.body(colors.muted, size: 13)),
            ),
            Divider(height: 2, thickness: 2, color: colors.line),
            Expanded(
              child: playerProvider.players.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(loc.translate('players_empty'), textAlign: TextAlign.center, style: WhistlyText.body(colors.muted, size: 14)),
                          const SizedBox(height: 24),
                          WhistlySecondaryButton(
                            label: loc.translate('players_add_new'),
                            onPressed: () => _showAddPlayerDialog(context),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: playerProvider.players.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: colors.line),
                      itemBuilder: (context, index) {
                        final player = playerProvider.players[index];
                        return InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerStatsPage(player: player)));
                          },
                          child: Container(
                            color: colors.bg,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(player.name, style: WhistlyText.rowTitle(colors.ink), overflow: TextOverflow.ellipsis),
                                      ),
                                      SoloSlimCrown(playerId: player.id),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    player.isFavorite ? Icons.star : Icons.star_border,
                                    color: player.isFavorite ? colors.ink : colors.muted,
                                  ),
                                  onPressed: () => context.read<PlayerProvider>().toggleFavorite(player),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Reserves its own height and collapses entirely once ads
            // are removed — never adjacent to a tappable control here.
            const AdaptiveBannerAd(),
          ],
        ),
      ),
    );
  }
}
