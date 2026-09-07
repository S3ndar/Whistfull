import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:whistly/models/player.dart';
import 'package:whistly/models/game.dart';
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

  // ─── Dark Theme (original) ───────────────────────────────────────────
  static ThemeData get _darkTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
      onPrimary: AppColors.white,
      onSecondary: AppColors.black,
      onSurface: AppColors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.white12),
      ),
    ),
    extensions: const <ThemeExtension<dynamic>>[AppSemanticColors.dark],
  );

  // ─── Light Theme (premium warm parchment) ────────────────────────────
  static ThemeData get _lightTheme => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.lightBackground,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.lightSurface,
      onPrimary: AppColors.white,
      onSecondary: AppColors.white,
      onSurface: AppColors.lightText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
    ),
    dividerColor: AppColors.lightBorder,
    iconTheme: const IconThemeData(color: AppColors.lightIcon),
    extensions: const <ThemeExtension<dynamic>>[AppSemanticColors.light],
  );

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: loc.translate('app_title'),
      debugShowCheckedModeBanner: false,
      theme: _lightTheme,
      darkTheme: _darkTheme,
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
    final appColors = AppTheme.of(context);
    
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _setTabIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: appColors.surface,
        selectedItemColor: Theme.of(context).colorScheme.secondary,
        unselectedItemColor: appColors.textFaint,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.play_circle_outline),
            activeIcon: const Icon(Icons.play_circle_filled),
            label: loc.translate('start_game'),
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: context.watch<PlayerProvider>().players.length < 4,
              label: const Text('!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.people_outline),
            ),
            activeIcon: Badge(
              isLabelVisible: context.watch<PlayerProvider>().players.length < 4,
              label: const Text('!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.people),
            ),
            label: loc.translate('players'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.history_toggle_off),
            activeIcon: const Icon(Icons.history),
            label: loc.translate('history'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_outlined),
            activeIcon: const Icon(Icons.menu_book),
            label: loc.translate('rules'),
          ),
        ],
      ),
    );
  }
}

class _HomePlayTab extends StatelessWidget {
  final VoidCallback onNavigateToPlayers;
  const _HomePlayTab({required this.onNavigateToPlayers});

  @override
  Widget build(BuildContext context) {
    final playerProvider = context.watch<PlayerProvider>();
    final gameProvider = context.watch<GameProvider>();
    final hasActiveGame = gameProvider.activeGame != null;
    final loc = context.watch<LocalizationProvider>();
    final hasEnoughPlayers = playerProvider.players.length >= 4;
    final appColors = AppTheme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('app_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: loc.translate('settings'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Hero(
                tag: 'logo',
                child: Image.asset(
                  'assets/whistly_logo.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) => 
                      Icon(Icons.style, size: 80, color: Theme.of(context).colorScheme.secondary),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'WHISTLY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: appColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                loc.translate('home_hero_subtitle'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12, 
                  color: appColors.textFaint, 
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 48),
              
              if (!hasEnoughPlayers)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: appColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: appColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.group_add, color: Theme.of(context).colorScheme.secondary, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        loc.translate('home_add_players_needed'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: appColors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => context.read<PlayerProvider>().populateDefaults(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                loc.translate('home_quick_start'),
                                style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontSize: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: onNavigateToPlayers,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.secondary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                loc.translate('home_add_players_cta'),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
              
              if (hasActiveGame) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ActiveGamePage()),
                    );
                  },
                  icon: const Icon(Icons.play_circle_filled),
                  label: Text(loc.translate('continue_game'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    minimumSize: const Size(double.infinity, 64),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                _buildActiveScores(context, gameProvider.activeGame!),
                const SizedBox(height: 24),
              ],

              ElevatedButton.icon(
                onPressed: hasEnoughPlayers
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GameSetupPage()),
                        );
                      }
                    : null,
                icon: const Icon(Icons.add_circle),
                label: Text(loc.translate('new_game'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 64),
                  disabledBackgroundColor: appColors.border,
                  disabledForegroundColor: appColors.textDisabled,
                ),
              ),
              
              const Spacer(),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final v = snapshot.hasData ? 'v${snapshot.data!.version}' : '';
                  return Text(
                    'Whistly $v',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: appColors.textDisabled, fontSize: 12),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveScores(BuildContext context, Game game) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border.all(color: AppTheme.of(context).border),
      ),
      child: Row(
        children: game.players.map((p) {
          final score = game.totalScores[p.id] ?? 0;
          return Expanded(
            child: Column(
              children: [
                Text(
                  p.name.split(' ').first,
                  style: TextStyle(fontSize: 12, color: AppTheme.of(context).textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  score >= 0 ? '+$score' : '$score',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: score >= 0 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                  ),
                ),
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
    final appColors = AppTheme.of(context);
    
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
              padding: const EdgeInsets.all(16),
              color: appColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    loc.translate('setup_instruction'),
                    style: TextStyle(color: appColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(4, (index) {
                    final p = _selectedPlayers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 120,
                            child: Text(
                              seatNames[index],
                              style: TextStyle(
                                color: p != null ? Theme.of(context).colorScheme.secondary : appColors.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: p != null ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1) : appColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: p != null ? Theme.of(context).colorScheme.secondary : appColors.border,
                                ),
                              ),
                              child: Text(
                                p?.name ?? loc.translate('setup_tap_player'),
                                style: TextStyle(
                                  color: p != null ? Theme.of(context).colorScheme.secondary : appColors.textMuted,
                                  fontWeight: p != null ? FontWeight.bold : FontWeight.normal,
                                ),
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
            Divider(height: 1, color: appColors.border),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isSelected = _selectedPlayers.contains(player);
                  int seatIndex = _selectedPlayers.indexOf(player);

                  return Card(
                    color: isSelected ? Theme.of(context).colorScheme.secondary : appColors.surface,
                    child: ListTile(
                      onTap: () => _togglePlayerSelection(player),
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? appColors.textPrimary : Theme.of(context).colorScheme.secondary,
                        child: Text(
                          player.name[0].toUpperCase(),
                          style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.secondary : appColors.textPrimary),
                        ),
                      ),
                      title: Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: isSelected 
                          ? CircleAvatar(
                              radius: 12,
                              backgroundColor: Theme.of(context).colorScheme.secondary,
                              child: Text('${seatIndex + 1}', style: TextStyle(fontSize: 12, color: appColors.textPrimary)),
                            )
                          : Icon(Icons.add_circle_outline, color: appColors.textMuted),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: appColors.border,
                    disabledForegroundColor: appColors.textFaint,
                  ),
                  child: Text(loc.translate('start_game')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
