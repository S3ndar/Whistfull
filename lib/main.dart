import 'package:flutter/material.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:whistly/models/player.dart';
import 'package:whistly/models/game.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/models/round.dart';
import 'package:whistly/providers/player_provider.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/providers/theme_provider.dart';
import 'package:whistly/scoring_settings.dart';
import 'package:whistly/ads/ads_provider.dart';
import 'package:whistly/billing/purchase_provider.dart';
import 'package:whistly/settings_page.dart';
import 'package:whistly/rules_page.dart';
import 'package:whistly/screens/active_game_page.dart';
import 'package:whistly/screens/players_page.dart';
import 'package:whistly/screens/history_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  Hive.registerAdapter(PlayerAdapter());
  Hive.registerAdapter(GameAdapter());
  Hive.registerAdapter(RoundAdapter());
  Hive.registerAdapter(GamePlayerRefAdapter());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()..init()),
        ChangeNotifierProvider(create: (_) => ScoringSettings()..init()),
        ChangeNotifierProvider(create: (_) => GameProvider()..init()),
        ChangeNotifierProvider(create: (_) => LocalizationProvider()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        // AdsProvider must be created before PurchaseProvider: the latter
        // reads it via context.read below to push entitlement changes
        // into it (see the doc comment on PurchaseProvider for why this
        // simple "shared Hive key + setter" wiring was chosen over
        // ChangeNotifierProxyProvider).
        ChangeNotifierProvider(create: (_) => AdsProvider()..init()),
        ChangeNotifierProvider(
          create: (context) => PurchaseProvider(adsProvider: context.read<AdsProvider>())..init(),
        ),
      ],
      child: const WhistlyApp(),
    ),
  );
}

class WhistlyApp extends StatelessWidget {
  const WhistlyApp({super.key});

  // Theme spec (iteration 6): radius 0 everywhere, no shadows/gradients/
  // blur, no surface fills. Archivo throughout; numerals use the platform
  // monospace (see WhistlyText in theme/whistly_components.dart).
  static ThemeData _themeFor(AppSemanticColors colors, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.bg,
      fontFamily: 'Archivo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
        primary: colors.accent,
        onPrimary: colors.onAccent,
        secondary: colors.accent,
        onSecondary: colors.onAccent,
        surface: colors.bg,
        onSurface: colors.ink,
        error: colors.accent,
        onError: colors.onAccent,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.bg,
        foregroundColor: colors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: WhistlyText.sectionHead(colors.ink),
        shape: Border(bottom: BorderSide(color: colors.line, width: 2)),
      ),
      dividerColor: colors.line,
      dividerTheme: DividerThemeData(color: colors.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: colors.ink),
      textTheme: TextTheme(
        bodyMedium: WhistlyText.body(colors.ink),
        bodySmall: WhistlyText.body(colors.muted, size: 11),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          disabledBackgroundColor: colors.line.withValues(alpha: 0.15),
          disabledForegroundColor: colors.muted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: WhistlyText.buttonLabel(colors.onAccent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.ink,
          side: BorderSide(color: colors.line, width: 2),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          textStyle: WhistlyText.buttonLabel(colors.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.ink,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.bg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: colors.line, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: colors.line, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      splashFactory: NoSplash.splashFactory,
      extensions: <ThemeExtension<dynamic>>[colors],
    );
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: loc.translate('app_title'),
      debugShowCheckedModeBanner: false,
      theme: _themeFor(AppSemanticColors.light, Brightness.light),
      darkTheme: _themeFor(AppSemanticColors.dark, Brightness.dark),
      themeMode: themeProvider.themeMode,
      home: const MainNavigationWrapper(),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  void _setTabIndex(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();

    final List<Widget> tabs = [
      _HomePlayTab(onNavigateToPlayers: () => _setTabIndex(1)),
      const PlayersPage(),
      const HistoryPage(),
      const RulesPage(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: tabs,
      ),
      bottomNavigationBar: WhistlyTabBar(
        currentIndex: _currentIndex,
        onTap: _setTabIndex,
        items: [
          WhistlyTabItem(icon: Icons.play_circle_outline, label: loc.translate('start_game')),
          WhistlyTabItem(
            icon: Icons.people_outline,
            label: loc.translate('players'),
            showDot: context.watch<PlayerProvider>().players.length < 4,
          ),
          WhistlyTabItem(icon: Icons.history_toggle_off, label: loc.translate('history')),
          WhistlyTabItem(icon: Icons.menu_book_outlined, label: loc.translate('rules')),
        ],
      ),
    );
  }
}

/// Home — per spec §6: brand block (logo mark, wordmark, tagline eyebrow)
/// with a 2px bottom rule; "At the table" section (eyebrow left, dealer
/// name right when a game is active; 2x2 player grid; + Add player) with
/// a 2px bottom rule; flex spacer; suit strip + primary button; tab bar.
class _HomePlayTab extends StatelessWidget {
  final VoidCallback onNavigateToPlayers;
  const _HomePlayTab({required this.onNavigateToPlayers});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final gameProvider = context.watch<GameProvider>();
    final activeGame = gameProvider.activeGame;
    final hasActiveGame = activeGame != null;
    final loc = context.watch<LocalizationProvider>();
    final hasEnoughPlayers = playerProvider.players.length >= 4;
    final colors = AppTheme.of(context);

    // The 2x2 grid shows the active game's table when one is in progress,
    // otherwise the top 4 players by the roster's own favourites-first
    // sort (PlayerProvider._loadPlayers) — a reasonable "at the table"
    // default when no game has been started yet. The two sources are
    // different types (a game's roster is `GamePlayerRef` — id+name only,
    // PLAN.md B4 — while the idle-state roster is a live `Player`), so both
    // are narrowed to `_PlayerGridEntry` here rather than typing
    // `_PlayerGrid` around either one specifically.
    final gridPlayers = hasActiveGame
        ? activeGame.players.map((p) => _PlayerGridEntry(id: p.id, name: p.name)).toList()
        : playerProvider.players
            .take(4)
            .map((p) => _PlayerGridEntry(id: p.id, name: p.name, gamesPlayed: p.gamesPlayed))
            .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Brand block ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        WhistlyLogoLockup(markSize: 60),
                        const SizedBox(height: 6),
                        Text(
                          loc.translate('home_hero_subtitle').toUpperCase(),
                          style: WhistlyText.eyebrow(colors.muted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.settings, color: colors.ink),
                    tooltip: loc.translate('settings'),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
                    },
                  ),
                ],
              ),
            ),

            // ─── At the table ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(loc.translate('home_at_table').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
                      ),
                      if (hasActiveGame)
                        Text(
                          '${loc.translate('dealer')} · ${gameProvider.currentDealer?.name ?? ''}',
                          style: WhistlyText.eyebrow(colors.muted),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (!hasEnoughPlayers) ...[
                    Text(
                      loc.translate('home_add_players_needed'),
                      style: WhistlyText.body(colors.muted, size: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        WhistlyTextAction(
                          label: loc.translate('home_quick_start'),
                          onPressed: () => context.read<PlayerProvider>().populateDefaults(),
                        ),
                        const SizedBox(width: 24),
                        WhistlyTextAction(
                          icon: Icons.add,
                          label: loc.translate('home_add_player_action'),
                          onPressed: onNavigateToPlayers,
                        ),
                      ],
                    ),
                  ] else ...[
                    _PlayerGrid(players: gridPlayers, activeGame: activeGame),
                    const SizedBox(height: 12),
                    WhistlyTextAction(
                      icon: Icons.add,
                      label: loc.translate('home_add_player_action'),
                      onPressed: onNavigateToPlayers,
                    ),
                  ],
                ],
              ),
            ),

            const Spacer(),

            // ─── Suit strip + primary button ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
              child: const _SuitStrip(),
            ),
            const SizedBox(height: 12),
            if (hasActiveGame)
              WhistlyPrimaryButton(
                label: loc.translate('continue_game'),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ActiveGamePage()));
                },
              )
            else
              WhistlyPrimaryButton(
                label: loc.translate('new_game'),
                onPressed: hasEnoughPlayers
                    ? () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const GameSetupPage()));
                      }
                    : null,
              ),
            const SizedBox(height: 8),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final v = snapshot.hasData ? 'v${snapshot.data!.version}' : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Whistly $v', style: WhistlyText.body(colors.muted, size: 11)),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Suit strip — four equal cells, `line`-colored 2px-gap grid, each `bg`
/// filled with its suit glyph in suit color (spec §5). Decorative on Home.
class _SuitStrip extends StatelessWidget {
  const _SuitStrip();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    const suits = [
      ('♠', false),
      ('♥', true),
      ('♦', true),
      ('♣', false),
    ];
    return Container(
      color: colors.line,
      child: Row(
        children: List.generate(suits.length, (i) {
          final (glyph, isRed) = suits[i];
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
              color: colors.bg,
              height: 56,
              alignment: Alignment.center,
              child: Text(
                glyph,
                style: TextStyle(fontSize: 24, color: isRed ? colors.suitRed : colors.suitInk),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Minimal shape `_PlayerGrid` needs from either a live `Player` (idle
/// state) or a game's `GamePlayerRef` roster (active game) — see the
/// `gridPlayers` comment in `_HomePlayTab.build` for why these can't just
/// be typed as one or the other. `gamesPlayed` is only meaningful (and
/// only read) in the idle-state, no-active-game branch below.
class _PlayerGridEntry {
  final String id;
  final String name;
  final int gamesPlayed;
  const _PlayerGridEntry({required this.id, required this.name, this.gamesPlayed = 0});
}

/// Player grid — 2x2 of `bg` cells on a `line` grid, name over record
/// (spec §5).
class _PlayerGrid extends StatelessWidget {
  final List<_PlayerGridEntry> players;
  final Game? activeGame;
  const _PlayerGrid({required this.players, this.activeGame});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final loc = context.watch<LocalizationProvider>();
    final cells = List.generate(4, (i) => i < players.length ? players[i] : null);

    return Container(
      color: colors.line,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.4,
        children: cells.map((p) {
          if (p == null) return Container(color: colors.bg);
          final record = activeGame != null
              ? (activeGame!.totalScores[p.id] ?? 0)
              : p.gamesPlayed;
          final recordLabel = activeGame != null
              ? (record >= 0 ? '+$record' : '$record')
              : '$record ${loc.translate('stats_games').toUpperCase()}';
          return Container(
            color: colors.bg,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: WhistlyText.rowTitle(colors.ink), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(recordLabel, style: WhistlyText.mono(colors.muted)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class GameSetupPage extends StatefulWidget {
  const GameSetupPage({super.key});

  @override
  State<GameSetupPage> createState() => _GameSetupPageState();
}

class _GameSetupPageState extends State<GameSetupPage> {
  // Array representing the 4 seats: Dealer, Left, Partner, Right
  final List<Player?> _selectedPlayers = [null, null, null, null];

  void _togglePlayerSelection(Player player) {
    setState(() {
      int existingIndex = _selectedPlayers.indexOf(player);
      if (existingIndex != -1) {
        // Remove if already selected
        _selectedPlayers[existingIndex] = null;
      } else {
        // Add to first available abstract seat, clockwise.
        for (int i = 0; i < 4; i++) {
          if (_selectedPlayers[i] == null) {
            _selectedPlayers[i] = player;
            break;
          }
        }
      }
    });
  }

  bool _isReadyToStart() {
    return !_selectedPlayers.contains(null);
  }

  @override
  Widget build(BuildContext context) {
    final players = context.watch<PlayerProvider>().players;
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);

    final List<String> seatNames = [
      loc.translate('setup_seat_dealer'),
      loc.translate('setup_seat_left'),
      loc.translate('setup_seat_across'),
      loc.translate('setup_seat_right')
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('setup_title')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc.translate('setup_instruction'),
                    style: WhistlyText.body(colors.muted, size: 13),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(4, (index) {
                    final p = _selectedPlayers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              seatNames[index].toUpperCase(),
                              style: WhistlyText.eyebrow(p != null ? colors.ink : colors.muted),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                border: Border.all(color: p != null ? colors.ink : colors.line, width: p != null ? 2 : 1),
                              ),
                              child: Text(
                                p?.name ?? loc.translate('setup_tap_player'),
                                style: p != null ? WhistlyText.rowTitle(colors.ink) : WhistlyText.body(colors.muted),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: players.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: colors.line),
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isSelected = _selectedPlayers.contains(player);
                  int seatIndex = _selectedPlayers.indexOf(player);

                  return InkWell(
                    onTap: () => _togglePlayerSelection(player),
                    child: Container(
                      color: colors.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(player.name, style: WhistlyText.rowTitle(colors.ink)),
                          ),
                          if (isSelected)
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              color: colors.accent,
                              child: Text(
                                '${seatIndex + 1}',
                                style: WhistlyText.mono(colors.onAccent, size: 12, weight: FontWeight.w800),
                              ),
                            )
                          else
                            Icon(Icons.add, color: colors.muted),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            WhistlyPrimaryButton(
              label: loc.translate('start_game'),
              showChevron: false,
              onPressed: _isReadyToStart()
                  ? () {
                      final selectedList = _selectedPlayers.whereType<Player>().toList();
                      context.read<GameProvider>().startGame(
                            selectedList,
                            settings: context.read<ScoringSettings>(),
                          );
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const ActiveGamePage()),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
