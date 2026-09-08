import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/player.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/widgets/round_setup_dialog.dart';
import 'package:whistly/screens/hierarchy_page.dart';
import 'package:confetti/confetti.dart';
import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/ads/banner_ad_widget.dart';

class ActiveGamePage extends StatefulWidget {
  const ActiveGamePage({super.key});

  @override
  State<ActiveGamePage> createState() => _ActiveGamePageState();
}

class _ActiveGamePageState extends State<ActiveGamePage> {
  late ConfettiController _confettiController;

  // Reserved height of the bottom banner ad (0 when removed/unsupported/
  // failed to load). The FloatingActionButton is padded by exactly this
  // much so it always floats above the banner and never overlaps it —
  // see the `floatingActionButton` below.
  double _bannerHeight = 0;

  void _onBannerHeightChanged(double height) {
    if (!mounted) return;
    setState(() => _bannerHeight = height);
  }

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 5));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _showWinCelebration(Game game, LocalizationProvider loc) {
    // Find winners (highest score)
    final scores = game.players.map((p) => game.totalScores[p.id] ?? 0);
    final maxScore = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);

    final winners = game.players.where((p) => (game.totalScores[p.id] ?? 0) == maxScore).toList();
    final appColors = AppTheme.of(context);
    
    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false, // Must use the button to exit
      builder: (_) => Stack(
        alignment: Alignment.center,
        children: [
          AlertDialog(
            backgroundColor: appColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events, color: AppColors.secondary, size: 80),
                const SizedBox(height: 16),
                Text(
                  loc.translate('game_over'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  winners.length > 1 ? loc.translate('stats_winners') : loc.translate('stats_winner'),
                  style: TextStyle(color: appColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ...winners.map((w) => Text(
                  w.name,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                )),
                const SizedBox(height: 12),
                Text(
                  '${loc.translate('score')}: $maxScore',
                  style: TextStyle(fontSize: 18, color: appColors.textMuted),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    // Grab the provider reference before popping — after
                    // both pops below this page's context may no longer
                    // be mounted, but the ChangeNotifier instance itself
                    // stays perfectly usable.
                    final adsProvider = context.read<AdsProvider>();
                    final gameId = game.id;
                    context.read<PlayerProvider>().incrementGamesPlayed(game.players);
                    context.read<GameProvider>().endGame();
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Return home
                    // Show the interstitial only after leaving the game
                    // screen — end the game and pop first, so a failed or
                    // slow ad can never trap the user in this dialog.
                    // Never shown during round entry, only here.
                    adsProvider.maybeShowInterstitial(gameId: gameId);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: appColors.success,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(loc.translate('back_home')),
                ),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: AppColors.confetti,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameProvider = context.watch<GameProvider>();
    final loc = context.watch<LocalizationProvider>();
    final game = gameProvider.activeGame;

    if (game == null) {
      return Scaffold(body: Center(child: Text(loc.translate('active_game_no_active'))));
    }

    final appColors = AppTheme.of(context);
    final players = game.players;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('active_game_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.home),
          tooltip: loc.translate('back'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: loc.translate('undo'),
            onPressed: game.rounds.isEmpty
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: appColors.surface,
                        title: Text(loc.translate('undo_round_title')),
                        content: Text(loc.translate('undo_round_desc')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(loc.translate('cancel'), style: TextStyle(color: appColors.textSecondary)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              context.read<GameProvider>().undoLastRound();
                              Navigator.pop(context);
                            },
                            child: Text(loc.translate('undo')),
                          ),
                        ],
                      ),
                    );
                  },
          ),
          // Icon-only (with a tooltip for the label) rather than a labeled
          // button: with Undo + this + End Game all sharing the AppBar,
          // labeled buttons left so little room for the title that it
          // truncated to "Ac..." on a phone-width screen.
          IconButton(
            icon: Icon(Icons.table_chart, color: appColors.textPrimary),
            tooltip: loc.translate('hierarchy_title'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HierarchyPage()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: IconButton(
              icon: Icon(Icons.stop_circle, color: appColors.textPrimary),
              tooltip: loc.translate('end_game'),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: appColors.surface,
                    title: Text(loc.translate('active_game_end_title')),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(loc.translate('active_game_end_desc')),
                        const SizedBox(height: 12),
                        Text(
                          loc.translate('active_game_abandon_desc'),
                          style: TextStyle(fontSize: 12, color: appColors.textFaint),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc.translate('cancel'), style: TextStyle(color: appColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: () {
                          // No celebration, no interstitial — just close the
                          // confirm dialog and return home.
                          context.read<GameProvider>().abandonGame();
                          Navigator.pop(context); // close confirm dialog
                          Navigator.pop(context); // return home
                        },
                        child: Text(loc.translate('active_game_abandon'), style: TextStyle(color: appColors.error)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // close confirm dialog
                          _showWinCelebration(game, loc);
                        },
                        child: Text(loc.translate('end_game')),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scoreboard
          Container(
            color: appColors.surface,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Player Score Cards
                Row(
                  children: players.map((player) {
                    final score = game.totalScores[player.id] ?? 0;
                    final isDealer = gameProvider.currentDealer?.id == player.id;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        decoration: BoxDecoration(
                          color: isDealer
                              ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)
                              : appColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDealer ? Theme.of(context).colorScheme.secondary : appColors.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              child: Text(player.name[0].toUpperCase(),
                                  style: TextStyle(fontWeight: FontWeight.bold, color: appColors.textPrimary)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              player.name.split(' ').first,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              score >= 0 ? '+$score' : '$score',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: score >= 0 ? appColors.success : appColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: appColors.border),
          // Rondpas multiplier banner
          if (gameProvider.pointMultiplier > 1)
            Container(
              color: appColors.panel,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.double_arrow, color: appColors.accentGold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${loc.translate('bid_pass')} — ${loc.translate('active_game_next_round')} ×${gameProvider.pointMultiplier}',
                    style: TextStyle(
                      color: appColors.accentGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),

          // Round History
          Expanded(
            child: game.rounds.isEmpty
                ? Center(
                    child: Text(
                      loc.translate('active_game_no_rounds'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: appColors.textFaint, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: game.rounds.length,
                    itemBuilder: (context, index) {
                      final roundNumber = game.rounds.length - index;
                      final round = game.rounds[game.rounds.length - 1 - index];
                      return _RoundHistoryCard(
                        round: round,
                        roundNumber: roundNumber,
                        players: players,
                      );
                    },
                  ),
          ),
          // Below the round list, above the FAB area. Full-width, its own
          // reserved height, and NOT tappable itself in a way that
          // overlaps the FAB — see the floatingActionButton padding below,
          // which is pushed up by exactly this banner's height so the two
          // never sit on top of each other.
          SafeArea(
            top: false,
            child: AdaptiveBannerAd(onHeightChanged: _onBannerHeightChanged),
          ),
        ],
      ),
      floatingActionButton: Padding(
        // Reserve the banner's height so the FAB always floats clear of
        // it — accidental taps on/near an ad are the most common cause of
        // AdMob invalid-traffic account suspensions for small publishers,
        // so this offset is a safety measure, not a cosmetic one.
        padding: EdgeInsets.only(bottom: _bannerHeight),
        child: FloatingActionButton.extended(
          onPressed: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.transparent,
              builder: (_) => RoundSetupDialog(players: game.players),
            );
          },
          backgroundColor: Theme.of(context).colorScheme.secondary,
          icon: const Icon(Icons.add),
          label: Text(loc.translate('active_game_add_round')),
        ),
      ),
    );
  }
}

class _RoundHistoryCard extends StatelessWidget {
  final Round round;
  final int roundNumber;
  final List<Player> players;

  const _RoundHistoryCard({
    required this.round,
    required this.roundNumber,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final appColors = AppTheme.of(context);

    // Special compact card for Round Pass rounds
    if (round.contractType == 'Pass') {
      final dealer = players.firstWhere(
        (p) => p.id == round.dealerId,
        orElse: () => players.first,
      );
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: appColors.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: appColors.accentGold.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.skip_next, color: appColors.accentGold, size: 18),
            const SizedBox(width: 8),
            Text(
              loc.translate('bid_pass'),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: appColors.accentGold),
            ),
            const Spacer(),
            Text(
              '${loc.translate('dealer')}: ${dealer.name}',
              style: TextStyle(color: appColors.textFaint, fontSize: 10),
            ),
          ],
        ),
      );
    }

    final declarer = players.firstWhere(
      (p) => p.id == round.declarerId,
      orElse: () => players.first,
    );
    final partner = round.partnerId != null
        ? players.firstWhere(
            (p) => p.id == round.partnerId,
            orElse: () => players.first,
          )
        : null;

    final isMiserie = round.contractType == 'Miserie' || round.contractType == 'Open Miserie';
    final declarerWon = (round.scoreDeltas[round.declarerId] ?? 0) > 0;
    final partnerWon = partner != null && (round.scoreDeltas[round.partnerId] ?? 0) > 0;

    final trumpIcon = round.trump == 'Hearts' ? '♥' 
                   : round.trump == 'Diamonds' ? '♦'
                   : round.trump == 'Clubs' ? '♣'
                   : round.trump == 'Spades' ? '♠' : '';
    
    final trumpColor = (round.trump == 'Hearts' || round.trump == 'Diamonds') ? AppColors.suitRed
                    : (round.trump == 'Clubs' || round.trump == 'Spades') ? AppColors.suitBlack
                    : appColors.textSecondary;

    final hasMultiplier = (round.multiplier) > 1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: appColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appColors.scrim),
      ),
      child: Column(
        children: [
          // Main Info Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Status Badge
                    if (isMiserie && partner != null) ...[
                      _miserieStatusBadge(context, loc, declarer.name, declarerWon),
                      const SizedBox(width: 6),
                      _miserieStatusBadge(context, loc, partner.name, partnerWon),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (round.success ? appColors.success : Theme.of(context).colorScheme.secondary).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (round.success ? appColors.success : Theme.of(context).colorScheme.secondary).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          loc.translate(round.success ? 'won' : 'lost').toUpperCase(),
                          style: TextStyle(
                            color: round.success ? appColors.success : Theme.of(context).colorScheme.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                    const SizedBox(width: 8),
                    // Names
                    Expanded(
                      child: Text(
                        '${declarer.name}${partner != null ? " & ${partner.name}" : ""}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: appColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Multiplier
                    if (hasMultiplier)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: appColors.accentGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: appColors.accentGold.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '×${round.multiplier}',
                          style: TextStyle(
                            color: appColors.accentGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Contract Details Row
                Row(
                  children: [
                    Text(
                      getContractName(loc, round.contractType).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: appColors.textFaint,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (trumpIcon.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text('•', style: TextStyle(color: appColors.border)),
                      ),
                      Text(trumpIcon, style: TextStyle(fontSize: 16, color: trumpColor)),
                    ],
                    const Spacer(),
                    Text(
                      '#$roundNumber',
                      style: TextStyle(color: appColors.textFaint, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Scores Bottom Line
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: appColors.scrim,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              children: players.map((p) {
                final delta = round.scoreDeltas[p.id] ?? 0;
                return Expanded(
                  child: Column(
                    children: [
                      Text(
                        p.name.split(' ').first,
                        style: TextStyle(fontSize: 10, color: appColors.textFaint),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        delta >= 0 ? '+$delta' : '$delta',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: delta > 0
                              ? appColors.success
                              : delta < 0
                                  ? appColors.error
                                  : appColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miserieStatusBadge(BuildContext context, LocalizationProvider loc, String name, bool won) {
    final color = won ? AppTheme.of(context).success : Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        '${name.split(" ").first}: ${loc.translate(won ? 'won' : 'lost').toUpperCase()}',
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
