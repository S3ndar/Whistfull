import 'dart:math';
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
import 'package:whistly/widgets/player_columns.dart';
import 'package:whistly/screens/hierarchy_page.dart';
import 'package:confetti/confetti.dart';
import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/ads/banner_ad_widget.dart';
import 'package:whistly/stats/stats_panel.dart';
import 'package:whistly/stats/crown_badge.dart';

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
      builder: (_) => _WinCelebrationDialog(
        winners: winners,
        maxScore: maxScore,
        loc: loc,
        colors: colors,
        mainConfettiController: _confettiController,
        onBackHome: () {
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
            _StandingsList(game: game, loc: loc, colors: colors, dealerId: gameProvider.currentDealer?.id),

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

            // ─── Stats panel (ALTERATIONS.md round 2, C5); covers the
            // round list below whenever a chart is selected instead of
            // "Rounds" — see roundsView: on StatsPanel. ──────────────
            StatsPanel(
              scope: [game],
              roundsView: game.rounds.isEmpty
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
                        useSafeArea: true,
                        backgroundColor: Colors.transparent,
                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
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

/// ALTERATIONS.md (round 2) E2 — the header strip: one column per
/// player through `PlayerColumns`, in `game.players` (seating) order,
/// staying outside the scrolling round list below so it's always on
/// screen. Replaces the old vertical standings `Column`.
class _StandingsList extends StatelessWidget {
  final Game game;
  final LocalizationProvider loc;
  final AppSemanticColors colors;
  final String? dealerId;

  const _StandingsList({required this.game, required this.loc, required this.colors, this.dealerId});

  @override
  Widget build(BuildContext context) {
    // ALTERATIONS.md B2: fixed seating order (`game.players`, set once at
    // startGame()) — no more re-sorting by score every rebuild, which made
    // rows jump around as the game progressed. The leader is still found
    // by score, just without reordering anything to do it.
    final topScore = game.totalScores.values.isEmpty ? -1 << 31 : game.totalScores.values.reduce(max);
    // Only one player wears the Lead badge (spec: "One per screen") — a
    // multi-way tie at the top shows none, since none of them are
    // uniquely leading.
    final leaders = game.players.where((p) => (game.totalScores[p.id] ?? 0) == topScore);
    final soleLeaderId = leaders.length == 1 ? leaders.first.id : null;

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: PlayerColumns(
          cells: game.players.map((player) {
            final score = game.totalScores[player.id] ?? 0;
            final isDealer = dealerId != null && player.id == dealerId;
            final isLeader = player.id == soleLeaderId;
            return _HeaderCell(
              player: player,
              score: score,
              isDealer: isDealer,
              isLeader: isLeader,
              loc: loc,
              colors: colors,
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// One `PlayerColumns` cell: first name (13px/800, ellipsis, one line,
/// with the D3 crown suffix) · Dealer/Lead badges in a 4px-gap `Wrap`
/// (a player holding both must wrap rather than overflow a ~78dp
/// column) · the running total at `screenNumeral` size 22 (30 overflows
/// the column at three digits plus a sign).
class _HeaderCell extends StatelessWidget {
  final GamePlayerRef player;
  final int score;
  final bool isDealer;
  final bool isLeader;
  final LocalizationProvider loc;
  final AppSemanticColors colors;

  const _HeaderCell({
    required this.player,
    required this.score,
    required this.isDealer,
    required this.isLeader,
    required this.loc,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  player.name.split(' ').first,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: WhistlyText.rowTitle(colors.ink).copyWith(fontSize: 13),
                ),
              ),
              SoloSlimCrown(playerId: player.id),
            ],
          ),
          if (isDealer || isLeader) ...[
            const SizedBox(height: 4),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                if (isDealer) WhistlyDealerBadge(label: loc.translate('dealer')),
                if (isLeader) WhistlyLeadBadge(label: loc.translate('lead')),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            score >= 0 ? '+$score' : '$score',
            textAlign: TextAlign.center,
            style: WhistlyText.screenNumeral(score >= 0 ? colors.ink : colors.accent, size: 22),
          ),
        ],
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

/// ALTERATIONS.md (round 2) E3 — the round row as two stacked bands,
/// separated by nothing (the divider between round rows is the
/// existing 1px one from the surrounding `ListView.separated`): a meta
/// band (what was bid) then a delta band through `PlayerColumns` (what
/// it cost) — that order reads "here is what was bid" then "here is
/// what it cost," the order a player asks the questions in.
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

    // No horizontal padding here — StatsPanel already insets its whole
    // roundsView (this row's only caller) by 22px, so an extra 22px
    // here would double it and pull this row's columns out of
    // alignment with the header strip's (which has exactly one 22px
    // inset of its own).
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 0, 6),
          child: _buildMetaBand(loc, colors),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PlayerColumns(cells: _deltaCells(colors)),
        ),
      ],
    );
  }

  Widget _buildMetaBand(LocalizationProvider loc, AppSemanticColors colors) {
    // The Rondpas row keeps its own, simpler meta band — there's no
    // contract, no trump, no result to show, just who dealt.
    if (round.contractType == 'Pass') {
      final dealer = players.firstWhere((p) => p.id == round.dealerId, orElse: () => players.first);
      return Row(
        children: [
          SizedBox(width: 20, child: Text('$roundNumber', style: WhistlyText.mono(colors.muted, size: 11))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${loc.translate('bid_pass')} · ${loc.translate('dealer')}: ${dealer.name}',
              style: WhistlyText.mono(colors.muted, size: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onDelete != null) _deleteButton(colors),
        ],
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

    final contractingLine = partner != null ? '${declarer.name} & ${partner.name}' : declarer.name;

    return Row(
      children: [
        SizedBox(width: 20, child: Text('$roundNumber', style: WhistlyText.mono(colors.muted, size: 11))),
        const SizedBox(width: 8),
        SizedBox(
          width: 18,
          child: trumpGlyph.isEmpty ? null : Text(trumpGlyph, style: TextStyle(fontSize: 14, color: trumpColor)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            getContractName(loc, round.contractType),
            style: WhistlyText.rowTitle(colors.ink).copyWith(fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(contractingLine, style: WhistlyText.mono(colors.muted, size: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        WhistlyResultBadge(
          achieved: overallSuccess,
          achievedLabel: loc.translate('setup_succeeded'),
          failedLabel: loc.translate('setup_failed'),
        ),
        if (onDelete != null) _deleteButton(colors),
      ],
    );
  }

  // A Rondpas round has no declarer, so every player's delta is exactly
  // 0 — the same "0 renders as a dot" rule that applies to any zero
  // delta on a real contract row gives it four dots for free, rather
  // than needing a separate early-return that skips the columns
  // entirely (a row with no columns would break the grid — E3).
  List<Widget> _deltaCells(AppSemanticColors colors) {
    return players.map((p) {
      final delta = round.scoreDeltas[p.id] ?? 0;
      final text = delta == 0 ? '·' : (delta > 0 ? '+$delta' : '$delta');
      final color = delta == 0 ? colors.muted : (delta > 0 ? colors.ink : colors.accent);
      return Text(
        text,
        textAlign: TextAlign.center,
        style: WhistlyText.mono(color, size: 13, weight: FontWeight.w800),
      );
    }).toList();
  }

  Widget _deleteButton(AppSemanticColors colors) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          onTap: onDelete,
          child: Icon(Icons.delete_outline, size: 20, color: colors.muted),
        ),
      );
}

// One extra confetti burst at a tapped screen point — its own short-lived
// controller, disposed once its burst finishes, so tapping repeatedly
// doesn't leak controllers.
class _ConfettiBurst {
  _ConfettiBurst(this.position, this.controller);
  final Offset position;
  final ConfettiController controller;
}

class _WinCelebrationDialog extends StatefulWidget {
  const _WinCelebrationDialog({
    required this.winners,
    required this.maxScore,
    required this.loc,
    required this.colors,
    required this.mainConfettiController,
    required this.onBackHome,
  });

  final List<GamePlayerRef> winners;
  final int maxScore;
  final LocalizationProvider loc;
  final AppSemanticColors colors;
  final ConfettiController mainConfettiController;
  final VoidCallback onBackHome;

  @override
  State<_WinCelebrationDialog> createState() => _WinCelebrationDialogState();
}

class _WinCelebrationDialogState extends State<_WinCelebrationDialog> {
  final List<_ConfettiBurst> _extraBursts = [];

  void _addBurst(Offset position) {
    final controller = ConfettiController(duration: const Duration(milliseconds: 700));
    final burst = _ConfettiBurst(position, controller);
    setState(() => _extraBursts.add(burst));
    controller.play();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _extraBursts.remove(burst));
      controller.dispose();
    });
  }

  @override
  void dispose() {
    for (final burst in _extraBursts) {
      burst.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final colors = widget.colors;
    final winners = widget.winners;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) => _addBurst(details.localPosition),
      child: Stack(
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
                  '${loc.translate('score')}: ${widget.maxScore}',
                  style: WhistlyText.mono(colors.muted, size: 15, weight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: WhistlyPrimaryButton(
                    label: loc.translate('back_home'),
                    showChevron: false,
                    onPressed: widget.onBackHome,
                  ),
                ),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: widget.mainConfettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Color(0xFFFF2D4F), Color(0xFF0E0E0E), Color(0xFFF5F1EA)],
          ),
          for (final burst in _extraBursts)
            Positioned(
              left: burst.position.dx - 60,
              top: burst.position.dy - 60,
              child: IgnorePointer(
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: ConfettiWidget(
                    confettiController: burst.controller,
                    blastDirectionality: BlastDirectionality.explosive,
                    shouldLoop: false,
                    numberOfParticles: 12,
                    colors: const [Color(0xFFFF2D4F), Color(0xFF0E0E0E), Color(0xFFF5F1EA)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
