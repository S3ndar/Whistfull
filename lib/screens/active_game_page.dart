import 'package:flutter/material.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/game_player_ref.dart';
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
    final scores = game.players.map((p) => game.totalScores[p.id] ?? 0);
    final maxScore = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
    final winners = game.players.where((p) => (game.totalScores[p.id] ?? 0) == maxScore).toList();
    final colors = AppTheme.of(context);

    _confettiController.play();

    showDialog(
      context: context,
      barrierDismissible: false, // Must use the button to exit
      builder: (_) => Stack(
        alignment: Alignment.center,
        children: [
          AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.emoji_events, color: colors.accent, size: 64),
                const SizedBox(height: 16),
                Text(loc.translate('game_over'), style: WhistlyText.sectionHead(colors.ink)),
                const SizedBox(height: 8),
                Text(
                  (winners.length > 1 ? loc.translate('stats_winners') : loc.translate('stats_winner')).toUpperCase(),
                  style: WhistlyText.eyebrow(colors.muted),
                ),
                const SizedBox(height: 12),
                ...winners.map((w) => Text(w.name, style: WhistlyText.sectionHead(colors.ink))),
                const SizedBox(height: 8),
                Text(
                  '${loc.translate('score')}: $maxScore',
                  style: WhistlyText.mono(colors.muted, size: 15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: WhistlyPrimaryButton(
                    label: loc.translate('back_home'),
                    showChevron: false,
                    onPressed: () {
                      // Grab the provider reference before popping — after
                      // both pops below this page's context may no longer
                      // be mounted, but the ChangeNotifier instance itself
                      // stays perfectly usable.
                      final adsProvider = context.read<AdsProvider>();
                      final gameId = game.id;
                      context.read<PlayerProvider>().incrementGamesPlayed(game.players.map((p) => p.id).toList());
                      context.read<GameProvider>().endGame();
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Return home
                      // Show the interstitial only after leaving the game
                      // screen — end the game and pop first, so a failed or
                      // slow ad can never trap the user in this dialog.
                      // Never shown during round entry, only here.
                      adsProvider.maybeShowInterstitial(gameId: gameId);
                    },
                  ),
                ),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Color(0xFFFF2D4F), Color(0xFF0E0E0E), Color(0xFFF5F1EA)],
          ),
        ],
      ),
    );
  }

  void _confirmUndo(BuildContext context, LocalizationProvider loc, AppSemanticColors colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.translate('undo_round_title'), style: WhistlyText.sectionHead(colors.ink)),
        content: Text(loc.translate('undo_round_desc'), style: WhistlyText.body(colors.muted, size: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.translate('cancel').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
          ),
          TextButton(
            onPressed: () {
              context.read<GameProvider>().undoLastRound();
              Navigator.pop(context);
            },
            child: Text(loc.translate('undo').toUpperCase(), style: WhistlyText.eyebrow(colors.ink)),
          ),
        ],
      ),
    );
  }

  // Per-row delete, reachable only from the LAST round row (see the
  // `isLast` check where _RoundRow is built) — deliberately not a general
  // "delete any round" action. [index] is always `game.rounds.length - 1`
  // at the point this is wired up. Deleting repeatedly walks backward one
  // round at a time, same as the header's undo icon; this just gives the
  // same action a second, in-context entry point directly on the row.
  void _confirmDeleteRound(BuildContext context, int index, LocalizationProvider loc, AppSemanticColors colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.translate('delete_round_title'), style: WhistlyText.sectionHead(colors.ink)),
        content: Text(loc.translate('delete_round_desc'), style: WhistlyText.body(colors.muted, size: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.translate('cancel').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
          ),
          TextButton(
            onPressed: () {
              context.read<GameProvider>().deleteRound(index);
              Navigator.pop(context);
            },
            child: Text(loc.translate('delete').toUpperCase(), style: WhistlyText.eyebrow(colors.accent)),
          ),
        ],
      ),
    );
  }

  void _confirmEndGame(BuildContext context, Game game, LocalizationProvider loc, AppSemanticColors colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.translate('active_game_end_title'), style: WhistlyText.sectionHead(colors.ink)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(loc.translate('active_game_end_desc'), style: WhistlyText.body(colors.muted, size: 13)),
            const SizedBox(height: 12),
            Text(loc.translate('active_game_abandon_desc'), style: WhistlyText.body(colors.muted, size: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.translate('cancel').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
          ),
          TextButton(
            onPressed: () {
              // No celebration, no interstitial — just close the confirm
              // dialog and return home.
              context.read<GameProvider>().abandonGame();
              Navigator.pop(context); // close confirm dialog
              Navigator.pop(context); // return home
            },
            child: Text(loc.translate('active_game_abandon').toUpperCase(), style: WhistlyText.eyebrow(colors.accent)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close confirm dialog
              _showWinCelebration(game, loc);
            },
            child: Text(loc.translate('end_game').toUpperCase(), style: WhistlyText.eyebrow(colors.ink)),
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

    final colors = AppTheme.of(context);
    final players = game.players;
    final upcomingRound = game.rounds.length + 1;

    return Scaffold(
      body: SafeArea(
        // The banner ad (last child below) handles its own bottom-safe-area
        // inset — see its own SafeArea wrapper — so the outer one doesn't
        // need to add it again after the ad.
        bottom: false,
        child: Column(
          children: [
            // ─── Header row ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: colors.ink),
                    tooltip: loc.translate('back'),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      '${loc.translate('round')} ${upcomingRound.toString().padLeft(2, '0')} · ${loc.translate('dealer')} ${gameProvider.currentDealer?.name ?? ''}',
                      style: WhistlyText.eyebrow(colors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.table_chart_outlined, color: colors.ink),
                    tooltip: loc.translate('hierarchy_title'),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HierarchyPage()));
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.undo, color: game.rounds.isEmpty ? colors.muted : colors.ink),
                    tooltip: loc.translate('undo'),
                    onPressed: game.rounds.isEmpty ? null : () => _confirmUndo(context, loc, colors),
                  ),
                ],
              ),
            ),

            // ─── Standings list ─────────────────────────────────────────
            _StandingsList(game: game, loc: loc, colors: colors),

            if (gameProvider.pointMultiplier > 1)
              Container(
                width: double.infinity,
                color: colors.accent,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                child: Text(
                  '${loc.translate('bid_pass')} — ${loc.translate('active_game_next_round')} ×${gameProvider.pointMultiplier}',
                  textAlign: TextAlign.center,
                  style: WhistlyText.eyebrow(colors.onAccent),
                ),
              ),

            // ─── Round history, newest first ────────────────────────────
            Expanded(
              child: game.rounds.isEmpty
                  ? Center(
                      child: Text(
                        loc.translate('active_game_no_rounds'),
                        textAlign: TextAlign.center,
                        style: WhistlyText.body(colors.muted, size: 14),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: game.rounds.length,
                      separatorBuilder: (context, index) => Divider(height: 1, color: colors.line),
                      itemBuilder: (context, index) {
                        final roundNumber = game.rounds.length - index;
                        final round = game.rounds[game.rounds.length - 1 - index];
                        // index 0 is the most recent round (see the
                        // reversed indexing above) — only it may be
                        // deleted, so the previous round becomes the last
                        // (and itself deletable) one delete at a time.
                        final isLast = index == 0;
                        return _RoundRow(
                          round: round,
                          roundNumber: roundNumber,
                          players: players,
                          onDelete: isLast ? () => _confirmDeleteRound(context, game.rounds.length - 1, loc, colors) : null,
                        );
                      },
                    ),
            ),

            // ─── Suit strip with trick counts ───────────────────────────
            _SuitStripWithCounts(game: game),

            // ─── Action row: + Round (flex, accent) and End (bg, 2px left border) ──
            Row(
              children: [
                Expanded(
                  child: WhistlyPrimaryButton(
                    label: loc.translate('active_game_add_round'),
                    showChevron: false,
                    onPressed: () async {
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => RoundSetupDialog(players: game.players),
                      );
                    },
                  ),
                ),
                WhistlySecondaryButton(
                  label: loc.translate('end_game'),
                  onPressed: () => _confirmEndGame(context, game, loc, colors),
                  border: Border(left: BorderSide(color: colors.line, width: 2)),
                ),
              ],
            ),

            // ─── Banner ad — the very bottom of the screen, below the
            // action row, not sandwiched in the middle of the layout. ───
            SafeArea(top: false, child: const AdaptiveBannerAd()),
          ],
        ),
      ),
    );
  }
}

/// Standings row: rank (mono, 16px wide) · name (flex) · optional Lead
/// badge · score (mono 30px, right-aligned, min 56px). Score is `ink`
/// when >= 0, `accent` when negative (spec §5). Ranked, 1px `line`
/// between rows.
class _StandingsList extends StatelessWidget {
  final Game game;
  final LocalizationProvider loc;
  final AppSemanticColors colors;

  const _StandingsList({required this.game, required this.loc, required this.colors});

  @override
  Widget build(BuildContext context) {
    final ranked = [...game.players]
      ..sort((a, b) => (game.totalScores[b.id] ?? 0).compareTo(game.totalScores[a.id] ?? 0));
    final topScore = ranked.isEmpty ? 0 : (game.totalScores[ranked.first.id] ?? 0);
    // Only one player wears the Lead badge (spec: "One per screen") — a
    // multi-way tie at the top shows none, since none of them are
    // uniquely leading.
    final soleLeaderId = ranked.where((p) => (game.totalScores[p.id] ?? 0) == topScore).length == 1
        ? ranked.first.id
        : null;

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
      child: Column(
        children: List.generate(ranked.length, (i) {
          final player = ranked[i];
          final score = game.totalScores[player.id] ?? 0;
          return Container(
            decoration: BoxDecoration(
              border: i == 0 ? null : Border(top: BorderSide(color: colors.line, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  child: Text('${i + 1}', style: WhistlyText.mono(colors.muted, size: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(player.name, style: WhistlyText.rowTitle(colors.ink), overflow: TextOverflow.ellipsis),
                ),
                if (player.id == soleLeaderId) ...[
                  WhistlyLeadBadge(label: loc.translate('lead')),
                  const SizedBox(width: 8),
                ],
                ConstrainedBox(
                  // Spec's "56px" is a minimum, not a cap (§6) — a fixed
                  // `width: 56` here let a 3-digit total (e.g. "+13") wrap
                  // onto two lines instead of overflowing, since the
                  // 30px-mono glyphs for 3 characters don't fit 56px and
                  // `Text` wraps by default. `minWidth` keeps every row's
                  // number right-aligned to the same column for the common
                  // case, `softWrap: false` lets a wider number grow past
                  // it on one line instead of wrapping.
                  constraints: const BoxConstraints(minWidth: 56),
                  child: Text(
                    score >= 0 ? '+$score' : '$score',
                    textAlign: TextAlign.right,
                    softWrap: false,
                    style: WhistlyText.screenNumeral(score >= 0 ? colors.ink : colors.accent),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

/// Suit strip with trick counts (spec §5: "During a game each cell also
/// carries a mono trick count below the glyph"). This app doesn't track
/// tricks per suit — the closest real, available number is how many
/// rounds so far were played with that suit as trump.
class _SuitStripWithCounts extends StatelessWidget {
  final Game game;
  const _SuitStripWithCounts({required this.game});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    const suits = [
      ('♠', 'Spades', false),
      ('♥', 'Hearts', true),
      ('♦', 'Diamonds', true),
      ('♣', 'Clubs', false),
    ];
    return Container(
      color: colors.line,
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: List.generate(suits.length, (i) {
          final (glyph, key, isRed) = suits[i];
          final count = game.rounds.where((r) => r.trump == key).length;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
              color: colors.bg,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(glyph, style: TextStyle(fontSize: 22, color: isRed ? colors.suitRed : colors.suitInk)),
                  const SizedBox(height: 2),
                  Text('$count', style: WhistlyText.mono(colors.muted, size: 11)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Round row: index (mono 12px muted) · suit glyph (24px, suit color) ·
/// bid (15/800) over partners · deltas (mono 11px muted) · result badge
/// (spec §5).
class _RoundRow extends StatelessWidget {
  final Round round;
  final int roundNumber;
  final List<GamePlayerRef> players;
  // Non-null only for the most recent round — see the `isLast` check
  // where this is built. Renders a small delete affordance on this row
  // only; every earlier round's is null and shows nothing.
  final VoidCallback? onDelete;

  const _RoundRow({required this.round, required this.roundNumber, required this.players, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    if (round.contractType == 'Pass') {
      final dealer = players.firstWhere((p) => p.id == round.dealerId, orElse: () => players.first);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
        child: Row(
          children: [
            SizedBox(width: 24, child: Text('$roundNumber', style: WhistlyText.mono(colors.muted, size: 12))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(loc.translate('bid_pass'), style: WhistlyText.rowTitle(colors.muted)),
            ),
            Text(
              '${loc.translate('dealer')}: ${dealer.name}',
              style: WhistlyText.mono(colors.muted),
            ),
            if (onDelete != null) _deleteButton(colors),
          ],
        ),
      );
    }

    final declarer = players.firstWhere((p) => p.id == round.declarerId, orElse: () => players.first);
    final partner = round.partnerId != null
        ? players.firstWhere((p) => p.id == round.partnerId, orElse: () => players.first)
        : null;

    final isMiserie = round.contractType == 'Miserie' || round.contractType == 'Open Miserie';
    final overallSuccess = isMiserie && partner != null
        ? (round.scoreDeltas[round.declarerId] ?? 0) > 0 && (round.scoreDeltas[round.partnerId] ?? 0) > 0
        : round.success;

    final trumpGlyph = round.trump == 'Hearts'
        ? '♥'
        : round.trump == 'Diamonds'
            ? '♦'
            : round.trump == 'Clubs'
                ? '♣'
                : round.trump == 'Spades'
                    ? '♠'
                    : '';
    final trumpColor = (round.trump == 'Hearts' || round.trump == 'Diamonds')
        ? colors.suitRed
        : (round.trump == 'Clubs' || round.trump == 'Spades')
            ? colors.suitInk
            : colors.muted;

    final partnerLine = partner != null ? '${declarer.name} & ${partner.name}' : declarer.name;
    final deltasLine = players.map((p) {
      final d = round.scoreDeltas[p.id] ?? 0;
      return '${p.name.split(' ').first} ${d >= 0 ? '+$d' : '$d'}';
    }).join('  ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text('$roundNumber', style: WhistlyText.mono(colors.muted, size: 12))),
          const SizedBox(width: 12),
          SizedBox(
            width: 24,
            child: trumpGlyph.isEmpty ? null : Text(trumpGlyph, style: TextStyle(fontSize: 24, color: trumpColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  getContractName(loc, round.contractType),
                  style: WhistlyText.rowTitle(colors.ink),
                ),
                const SizedBox(height: 2),
                Text('$partnerLine · $deltasLine', style: WhistlyText.mono(colors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          WhistlyResultBadge(
            achieved: overallSuccess,
            achievedLabel: loc.translate('setup_succeeded'),
            failedLabel: loc.translate('setup_failed'),
          ),
          if (onDelete != null) _deleteButton(colors),
        ],
      ),
    );
  }

  Widget _deleteButton(AppSemanticColors colors) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          onTap: onDelete,
          child: Icon(Icons.delete_outline, size: 20, color: colors.muted),
        ),
      );
}
