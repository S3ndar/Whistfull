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
import 'package:whistly/widgets/player_grid_picker.dart';

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
/// a 2px bottom rule; flex spacer; primary button; tab bar.
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

    // ALTERATIONS.md B4: the grid only ever renders the CURRENT game's
    // table now — showing the roster's first four players here (the old
    // behaviour, when no game was active) implied a table that doesn't
    // exist. See the "At the table" section below for the no-active-game
    // replacement.
    final gridPlayers = hasActiveGame
        ? activeGame.players.map((p) => PlayerGridEntry(id: p.id, name: p.name)).toList()
        : const <PlayerGridEntry>[];

    return Scaffold(
      // A fixed-height column with a Spacer pushing the suit strip + primary
      // button to the bottom. On a short viewport (landscape phone, small
      // desktop window) that column can exceed the screen, so it scrolls
      // instead of overflowing. ConstrainedBox + IntrinsicHeight keep the
      // Spacer behaving normally whenever there IS room.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
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
            // ALTERATIONS.md B4: this whole section — eyebrow, grid, dealer
            // text, bottom rule — only exists while a game is actually in
            // progress. With no active game there is no table to show, so
            // the section disappears entirely rather than falling back to
            // a preview of the roster's first four players (which looked
            // like a table that didn't exist). "+ Add player" stays
            // reachable via the empty-state replacement below.
            if (hasActiveGame)
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
                        Text(
                          '${loc.translate('dealer')} · ${gameProvider.currentDealer?.name ?? ''}',
                          style: WhistlyText.eyebrow(colors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    PlayerGridPicker(players: gridPlayers, activeGame: activeGame),
                    const SizedBox(height: 12),
                    WhistlyTextAction(
                      icon: Icons.add,
                      label: loc.translate('home_add_player_action'),
                      onPressed: onNavigateToPlayers,
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!hasEnoughPlayers) ...[
                      Text(
                        loc.translate('home_add_players_needed'),
                        style: WhistlyText.body(colors.muted, size: 13),
                      ),
                      const SizedBox(height: 12),
                    ],
                    // Wrap, not Row: on the narrowest phones (~320px wide)
                    // "Quick Start" + "+ Add player" don't both fit on one
                    // line — Wrap drops the second action to its own line
                    // there instead of overflowing (ALTERATIONS.md round 2,
                    // B5's test 5); at any normal width both still render
                    // side by side exactly as before.
                    Wrap(
                      spacing: 24,
                      runSpacing: 8,
                      children: [
                        if (!hasEnoughPlayers)
                          WhistlyTextAction(
                            label: loc.translate('home_quick_start'),
                            onPressed: () => context.read<PlayerProvider>().populateDefaults(),
                          ),
                        WhistlyTextAction(
                          icon: Icons.add,
                          label: loc.translate('home_add_player_action'),
                          onPressed: onNavigateToPlayers,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // ─── Primary button ─────────────────────────────────────────
            // ALTERATIONS.md round 2, B5: the decorative suit strip that
            // used to sit here carried no information — just four glyphs
            // showing a deck has four suits — and cost 56px + 12px on the
            // one screen that had already overflowed once. Real suit
            // information now lives in the stats panel's trump histogram
            // (C4.1).
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
            ),
          ),
        ),
      ),
    );
  }
}

// ALTERATIONS.md round 2, B5: `_SuitStrip` — a purely decorative row of
// four suit glyphs above the primary button — was deleted here, along
// with the Padding that hosted it. See the Spacer/primary-button comment
// above for why.

// ALTERATIONS.md B3: the player grid used to live here as a private
// `_PlayerGrid`/`_PlayerGridEntry` pair. It's now `PlayerGridPicker`/
// `PlayerGridEntry` in `lib/widgets/player_grid_picker.dart`, shared with
// `RoundSetupDialog`'s declarer/partner picker.

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
