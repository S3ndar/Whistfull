import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/screens/player_stats_page.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/ads/banner_ad_widget.dart';

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
          backgroundColor: colors.surface,
          title: Text(loc.translate('players_add_new')),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: loc.translate('players_name_label'),
              border: const OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.translate('cancel'), style: TextStyle(color: colors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  context.read<PlayerProvider>().addPlayer(name);
                  Navigator.pop(context);
                }
              },
              child: Text(loc.translate('add')),
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
              label: const Text('!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              backgroundColor: colors.error,
              child: const Icon(Icons.person_add),
            ),
            onPressed: () => _showAddPlayerDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.translate('players'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                loc.translate('players_desc'),
                style: TextStyle(fontSize: 14, color: colors.textMuted),
              ),
              const SizedBox(height: 16),
              Divider(color: colors.border),
              Expanded(
                child: playerProvider.players.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              loc.translate('players_empty'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.textMuted, fontSize: 16),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showAddPlayerDialog(context),
                              icon: const Icon(Icons.person_add),
                              label: Text(loc.translate('players_add_new')),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: playerProvider.players.length,
                        itemBuilder: (context, index) {
                          final player = playerProvider.players[index];
                          return Card(
                            color: colors.surface,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PlayerStatsPage(player: player),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor: AppColors.selectedBg,
                                child: Text(player.name[0].toUpperCase(), style: const TextStyle(color: AppColors.white)),
                              ),
                              title: Text(player.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              trailing: IconButton(
                                icon: Icon(
                                  player.isFavorite ? Icons.star : Icons.star_border,
                                  color: player.isFavorite
                                      ? AppColors.favoriteGold
                                      : colors.textFaint,
                                ),
                                onPressed: () {
                                  context.read<PlayerProvider>().toggleFavorite(player);
                                },
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
      ),
    );
  }
}
