import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

enum AppLanguage { en, nl }

class LocalizationProvider extends ChangeNotifier {
  static const String _boxName = 'settings_box';
  AppLanguage _currentLanguage = AppLanguage.en;

  AppLanguage get currentLanguage => _currentLanguage;

  Future<void> init() async {
    final box = await Hive.openBox(_boxName);
    final savedLang = box.get('language_index', defaultValue: 0);
    _currentLanguage = AppLanguage.values[savedLang];
    notifyListeners();
  }

  void setLanguage(AppLanguage language) async {
    _currentLanguage = language;
    notifyListeners();
    
    final box = await Hive.openBox(_boxName);
    await box.put('language_index', language.index);
  }

  String translate(String key) {
    if (_currentLanguage == AppLanguage.nl) {
      return _dutch[key] ?? _english[key] ?? key;
    }
    return _english[key] ?? key;
  }

  static const Map<String, String> _english = {
    // Common
    'app_title': 'Whistly',
    'cancel': 'CANCEL',
    'add': 'ADD',
    'save': 'SAVE',
    'dealer': 'Dealer',
    'round': 'Round',
    'lead': 'Lead',
    'ok': 'OK',
    'back': 'Back',
    'next': 'NEXT',
    'edit': 'Edit',
    'delete': 'Delete',
    'confirm': 'Confirm',
    'start_game': 'START GAME',
    'end_game': 'END GAME',
    'continue_game': 'CONTINUE GAME',
    'new_game': 'NEW GAME',
    'players': 'PLAYERS',
    'history': 'HISTORY',
    'game_over': 'Game Over!',
    'back_home': 'BACK TO HOME',
    'score': 'Score',
    'stats_winner': 'WINNER',
    'stats_winners': 'WINNERS',
    'won': 'ACHIEVED',
    'lost': 'FAILED',
    'confirm_win': 'CONFIRM ACHIEVEMENT',
    'confirm_loss': 'CONFIRM FAILURE',
    'rules': 'GAME RULES',
    'settings': 'Settings',
    'declarer': 'Declarer',
    'partner': 'Partner',

    // Home
    'home_hero_subtitle': 'The Traditional Belgian Whist',
    'home_add_players_error': 'Add at least 4 players to start a game.',
    'home_add_players_needed': 'Add at least 4 players to start playing Whist.',
    'home_quick_start': 'Quick Start',
    'home_add_players_cta': 'MANAGE PLAYERS',
    'home_at_table': 'At the table',
    'home_add_player_action': 'Add player',
    'score_progression': 'Score progression',

    // Game Setup
    'setup_title': 'Setup Table',
    'setup_instruction':
        'Select 4 players in clockwise order starting from the Dealer.',
    'setup_seat_dealer': 'Dealer',
    'setup_seat_left': 'Left of Dealer',
    'setup_seat_across': 'Across Dealer',
    'setup_seat_right': 'Right of Dealer',
    'setup_tap_player': 'Tap a player below',

    // Active Game
    'active_game_title': 'Active Game',
    'active_game_end_title': 'End Game?',
    'active_game_end_desc':
        'This will finalize the scores and clear the active game session.',
    'active_game_abandon': 'ABANDON',
    'active_game_abandon_desc':
        'End without recording a winner. The game stays in your history, marked as abandoned.',
    'active_game_no_active': 'No active game.',
    'active_game_no_rounds': 'No rounds yet.\nTap + to add the first round!',
    'active_game_add_round': 'ADD ROUND',
    'active_game_round_n': 'Round {}',
    'active_game_tricks': '{} tricks',
    'active_game_next_round': 'next round',
    'undo_round_title': 'Undo last round?',
    'undo_round_desc': 'The most recent round will be removed and all scores recalculated.',
    'undo': 'UNDO',
    'delete_round_title': 'Delete this round?',
    'delete_round_desc': 'This round will be removed and all scores recalculated. Only the last round can be deleted — delete it first to reach an earlier one.',

    // Round Dialog
    'setup_contract_step': 'Select Contract',
    'setup_players_step': 'Select Players',
    'setup_trump_step': 'Select Trump',
    'setup_result_step': 'Enter Result',
    'setup_negotiated': 'Negotiated Tricks',
    'setup_tricks_won': 'Tricks Won',
    'setup_result': 'Result',
    'setup_succeeded': 'Succeeded',
    'setup_failed': 'Failed',
    'setup_confirm': 'CONFIRM ROUND',
    'setup_status_made': 'Contract Made!',
    'setup_status_failed': 'Contract Failed!',

    // Players
    'players_title': 'Manage Players',
    'players_add_new': 'Add New Player',
    'players_name_label': 'Player Name',
    'players_empty': 'No players added yet.\nTap the + icon to add some!',
    'players_desc': 'Add players to start a game or manage your favorites.',
    'players_games_played': 'Games Played: {}',
    'players_favorite': 'Favorite Player',

    // Stats
    'stats_title': "{}'s Stats",
    'stats_games': 'Games',
    'stats_wins': 'Wins',
    'stats_win_rate': 'Win Rate',
    'stats_best_game': 'Best Game',
    'stats_avg_points': 'Avg Points',
    'stats_past_games': 'Past Games',
    'stats_no_games': 'No games played yet.',

    // History
    'history_title': 'Game History',
    'history_empty': 'No completed games yet.',
    'history_winner': 'Winner: {} ({} pts)',
    'history_rounds_played': '{} rounds played',
    'history_abandoned': 'Abandoned',
    'game_recap': 'Game Recap',
    'final_scores': 'FINAL SCORES',

    // Settings
    'settings_title': 'Scoring Settings',
    'settings_adjust': 'Point System',
    'settings_auto_save': 'Changes are saved automatically after each game.',
    'settings_decrease': 'Decrease {}',
    'settings_increase': 'Increase {}',
    'settings_partnership': 'Partnership Contracts',
    'settings_solo': 'Solo Contracts',
    'settings_negative': 'Special & Negative',
    'settings_danger_zone': 'Danger Zone',
    'settings_language': 'Language',
    'settings_delete_all': 'Delete All Data',
    'settings_lang_en': 'English',
    'settings_lang_nl': 'Dutch',
    'settings_theme': 'Appearance',
    'settings_theme_dark': 'Dark',
    'settings_theme_light': 'Light',
    'settings_theme_system': 'System',
    'settings_slim_bonus': 'All-13 Bonus',
    'settings_slim_bonus_desc': 'Taking all 13 tricks doubles that round\'s points (not Solo Slim, which is already the all-13 bid).',
    'settings_on': 'ON',
    'settings_off': 'OFF',

    // Stats panel (ALTERATIONS.md round 2, Part C) & Solo Slim crown (Part D)
    'close': 'Close',
    'crown_solo_slim': 'Solo Slim',
    'crown_solo_slim_desc':
        'Played completely alone and took all 13 tricks — the rarest result in the game.',
    'crown_round': 'Round {}',
    'crown_in_progress': 'Current game',
    'crown_times': '{}x',
    'stats_section_title': 'Stats',
    'stats_title_charts': 'Charts',
    'stats_chart_progression': 'Score progression',
    'stats_chart_trumps': 'Trump suits chosen',
    'stats_chart_contract_success': 'Success rate by contract',
    'stats_chart_accuracy': 'Bidding accuracy',
    'stats_chart_risk': 'Risk factor',
    'stats_table_average': 'Table average',
    'stats_no_data': 'Not enough rounds yet',
    'stats_untracked_trump': '{} rounds without a recorded trump',
    'stats_miserie_note': 'A Miserie played by two counts as held only if both succeed.',
    'stats_risk_help': 'How often this player was one of the contracting players.',

    // Settings — Support (ads / purchases)
    'settings_support': 'Support Whistly',
    'settings_remove_ads': 'Remove ads',
    'settings_remove_ads_desc':
        'Enjoying Whistly? Remove all ads with a one-time purchase.',
    'settings_restore': 'Restore purchases',
    'settings_purchased': 'Purchased ✓',
    'purchase_failed': 'Purchase failed. Please try again.',
    'purchase_restored': 'Your purchase has been restored.',
    'purchase_unavailable': 'The store is unavailable right now. Please try again later.',

    // Bids (English)
    'bid_ask_join': 'Ask & Join',
    'bid_trull': 'Trull',
    'bid_alone': 'Alone',
    'bid_misere': 'Misery',
    'bid_open_misere': 'Open Misery',
    'bid_abundance': 'Abundance',
    'bid_solo_slim': 'Solo Slim',
    'bid_pass': 'Round Pass',
    'bid_base_points': 'Base Points',
    'bid_bonus_trick': 'Bonus per Extra Trick',
    'bid_tricks_n': '{} tricks',
    'setup_tricks_n': 'Ask & Join ({})',

    // Rules
    'rules_title': 'Game Rules (Kleurenwiezen)',
    'rules_hero': 'The Traditional Belgian Whist',
    
    // Section 1
    'rules_section1_title': '1. Introduction & The Deal',
    'rules_sec1_obj_title': 'The Objective',
    'rules_sec1_obj_desc': 'Win tricks to meet your contract and score points. You can play together with a partner or alone.',
    'rules_sec1_cards_title': 'Card Ranking',
    'rules_sec1_cards_desc': 'A (Highest) - K - Q - J - 10 - 9 - 8 - 7 - 6 - 5 - 4 - 3 - 2 (Lowest).',
    'rules_sec1_trump_title': 'What is a "Trump"?',
    'rules_sec1_trump_desc': 'The trump suit is a designated suit that outranks all other suits for that round. If you cannot follow the lead suit, you can play a trump card to win the trick against regular suits.',
    'rules_sec1_deal_title': 'The Deal',
    'rules_sec1_deal_desc': 'Played with a standard 52-card deck. Each player receives 13 cards (usually dealt in groups of 4-4-5). The dealer rotates clockwise each round.',

    // Section 2
    'rules_section2_title': '2. The Bidding Process',
    'rules_sec2_stage1_title': 'Stage 1: Announcing Trull',
    'rules_sec2_stage1_desc': 'Before the normal auction, players must check for Trull (3 or 4 Aces). If you hold 3 Aces, the 4th Ace says "with me". If you hold all 4 Aces, name the highest missing Heart, and that holder says "with me". Higher bids like Misery can outbid Trull.',
    'rules_sec2_stage2_title': 'Stage 2: Forming Partnerships',
    'rules_sec2_stage2_desc': 'If no Trull, bidding begins. You can "Propose" a suit (lasts until your next turn; can be renewed once), "Pass", or "Wait" (only for the 1st player). You can also directly ask for a special contract like Misery or Abundance instead of proposing a suit. A "Wait" reserves the right to accept others later, but you can no longer propose yourself. If all players pass, the same player deals again.',
    'rules_sec2_stage3_title': 'Stage 3: Bidding Wars & Priority',
    'rules_sec2_stage3_desc': 'If multiple teams or solo bids compete, Suit Priority applies: Hearts (♥) > Diamonds (♦) > Clubs (♣) > Spades (♠). The contract with the lower suit must bid one trick more to stay in the auction.',

    // Section 3
    'rules_section3_title': '3. Special Contracts',
    'rules_sec3_intro_desc': 'Instead of standard Ask & Join, players can make special bids that overrule lower bids.',
    'rules_sec3_trull_title': 'Trull',
    'rules_sec3_trull_desc': 'Mandatory if you hold 3 or 4 Aces, announced before normal bidding starts. Your partner is the 4th Ace (or highest Heart you don\'t hold). The default trump suit belongs to your partner\'s card, aiming for 9 tricks.',
    'rules_sec3_alone_title': 'Alone (Solo)',
    'rules_sec3_alone_desc': 'Play alone to win 5 to 8 tricks. You can ONLY bid this if a partnership failed (e.g., no one accepted your proposal, or your partner passed). There is no reward for winning over 8 tricks here; if you want 9+, you must bid Abundance instead.',
    'rules_sec3_misery_title': 'Misery (Miserie)',
    'rules_sec3_misery_desc': 'Playing alone to win exactly 0 tricks. There is no trump suit in this contract.',
    'rules_sec3_abundance_title': 'Abundance (Abondance)',
    'rules_sec3_abundance_desc': 'Play alone to win 9 to 12 tricks with a trump suit of your choosing. You MUST bid this on your very first turn to speak—you cannot start with a normal proposal and switch to Abundance later.',
    'rules_sec3_soloslim_title': 'Solo Slim',
    'rules_sec3_soloslim_desc': 'Playing completely alone to win all 13 tricks.',

    // Section 4
    'rules_section4_title': '4. Gameplay',
    'rules_sec4_lead_title': 'Leading the Trick',
    'rules_sec4_lead_desc': 'In most contracts (and Misery), the player to the left of the dealer leads. However, in Abundance or Solo Slim, the winner of the bid leads. In a Trull, specific leading rules apply depending on whether the partner changed the trump suit.',
    'rules_sec4_follow_title': 'Following Suit & Buying',
    'rules_sec4_follow_desc': 'You MUST follow the suit that was led. If you cannot follow suit, you may play a trump card ("buying"), but you are NEVER obligated to do so. You can simply discard any other card, or even play a lower trump than one already played ("under-buying"). Furthermore, there is no rule forcing you to try and win the trick or go higher.',
    'rules_sec4_win_title': 'Winning the Trick',
    'rules_sec4_win_desc': 'The highest card of the lead suit wins, unless a trump card is played. If multiple trumps are played, the highest trump wins.',

    // Section 5
    'rules_section5_title': '5. Scoring & Bonuses',
    'rules_sec5_success_title': 'Winning a Contract',
    'rules_sec5_success_desc': 'In partnership games (Ask & Join, Trull), both winners gain points. If playing ALONE (Solo, Abundance, Misery), you win points from EACH of the 3 opponents (effectively 3x total).',
    'rules_sec5_bonus_title': 'Overtricks (Bonuses)',
    'rules_sec5_bonus_desc': 'For partnership games, every trick ABOVE your target adds +1 bonus point. Note: In Solo (max 8) and Abundance, overtricks may not grant extra points depending on the contract level.',
    'rules_sec5_fail_title': 'Failing a Contract',
    'rules_sec5_fail_desc': 'If you miss your target, you lose the base points of the contract. If playing alone, you pay these base points to EACH opponent.',
    'rules_sec5_hierarchy_cta': 'Check the full point values in the Bidding Hierarchy table below.',

    'rules_table_type': 'Bid Type',
    'rules_table_priority': 'Priority',
    'rules_table_tricks': 'Tricks',
    'rules_table_base': 'Base Pts',
    'rules_suit_hearts': 'Hearts',
    'rules_suit_diamonds': 'Diamonds',
    'rules_suit_clubs': 'Clubs',
    'rules_suit_spades': 'Spades',
    'rules_view_hierarchy': 'View Bidding Hierarchy',
    'hierarchy_title': 'Bidding Hierarchy',
    'rules_footer_note': '* Base points. Overtricks grant +1 bonus point per extra trick (subject to settings/level).',

    'delete_confirm_title': 'Are you absolutely sure?',
    'delete_confirm_desc':
        'This will permanently delete all players, game history, and active sessions. This cannot be undone.',
    'delete_confirm_btn': 'DELETE EVERYTHING',
  };

  static const Map<String, String> _dutch = {
    // Common
    'app_title': 'Whistly',
    'cancel': 'ANNULEER',
    'add': 'VOEG TOE',
    'save': 'OPSLAAN',
    'dealer': 'Deler',
    'round': 'Ronde',
    'lead': 'Leidt',
    'ok': 'OK',
    'back': 'Terug',
    'next': 'VOLGENDE',
    'edit': 'Bewerk',
    'delete': 'Verwijder',
    'confirm': 'Bevestig',
    'start_game': 'START SPEL',
    'end_game': 'STOP SPEL',
    'continue_game': 'VERDERGAAN',
    'new_game': 'NIEUW SPEL',
    'players': 'SPELERS',
    'history': 'GESCHIEDENIS',
    'rules': 'SPELREGELS',
    'settings': 'Instellingen',
    'game_over': 'Spel Gedaan!',
    'back_home': 'TERUG NAAR START',
    'score': 'Punten',
    'stats_winner': 'WINNAAR',
    'stats_winners': 'WINNAARS',
    'won': 'GEHAALD',
    'lost': 'GEMIST',
    'confirm_win': 'GEHAALD BEVESTIGEN',
    'confirm_loss': 'GEMIST BEVESTIGEN',
    'declarer': 'Spreker',
    'partner': 'Maat',

    // Home
    'home_hero_subtitle': 'De Traditionele Belgische Wiezen',
    'home_add_players_error':
        'Voeg minstens 4 spelers toe om een spel te starten.',
    'home_add_players_needed': 'Voeg minstens 4 spelers toe om te starten.',
    'home_quick_start': 'Snelstart',
    'home_add_players_cta': 'SPELERS BEHEREN',
    'home_at_table': 'Aan tafel',
    'home_add_player_action': 'Speler toevoegen',
    'score_progression': 'Scoreverloop',

    // Game Setup
    'setup_title': 'Tafel Opstellen',
    'setup_instruction':
        'Selecteer 4 spelers in klokwijzerzin, beginnend bij de Deler.',
    'setup_seat_dealer': 'Deler',
    'setup_seat_left': 'Links van Deler',
    'setup_seat_across': 'Overkant Deler',
    'setup_seat_right': 'Rechts van Deler',
    'setup_tap_player': 'Tik op een speler hieronder',

    // Active Game
    'active_game_title': 'Actief Spel',
    'active_game_end_title': 'Spel Beëindigen?',
    'active_game_end_desc':
        'Dit zal de scores finaliseren en de actieve sessie wissen.',
    'active_game_abandon': 'AFBREKEN',
    'active_game_abandon_desc':
        'Beëindigen zonder winnaar. De partij blijft in je geschiedenis staan, gemarkeerd als afgebroken.',
    'active_game_no_active': 'Geen actief spel.',
    'active_game_no_rounds':
        'Nog geen rondes.\nTik op + om de eerste ronde toe te voegen!',
    'active_game_add_round': 'RONDE TOEVOEGEN',
    'active_game_round_n': 'Ronde {}',
    'active_game_tricks': '{} slagen',
    'active_game_next_round': 'volgende ronde',
    'undo_round_title': 'Laatste ronde ongedaan maken?',
    'undo_round_desc': 'De laatste ronde wordt verwijderd en alle scores worden herberekend.',
    'undo': 'ONGEDAAN',
    'delete_round_title': 'Deze ronde verwijderen?',
    'delete_round_desc': 'Deze ronde wordt verwijderd en alle scores worden herberekend. Alleen de laatste ronde kan verwijderd worden — verwijder die eerst om een vorige te bereiken.',

    // Round Dialog
    'setup_contract_step': 'Kies Bod',
    'setup_players_step': 'Kies Spelers',
    'setup_trump_step': 'Kies Troef',
    'setup_result_step': 'Resultaat',
    'setup_negotiated': 'Gespeeld voor',
    'setup_tricks_won': 'Slagen Gehaald',
    'setup_result': 'Resultaat',
    'setup_succeeded': 'Gehaald',
    'setup_failed': 'Niet Gehaald',
    'setup_confirm': 'RONDE BEVESTIGEN',
    'setup_status_made': 'Bod Gehaald!',
    'setup_status_failed': 'Bod Niet Gehaald!',

    // Players
    'players_title': 'Spelers Beheren',
    'players_add_new': 'Nieuwe Speler',
    'players_name_label': 'Naam Speler',
    'players_empty':
        'Nog geen spelers toegevoegd.\nTik op het + icoon om er toe te voegen!',
    'players_desc':
        'Voeg spelers toe om een spel te starten of beheer je favorieten.',
    'players_games_played': 'Spellen Gespeeld: {}',
    'players_favorite': 'Favoriete Speler',

    // Stats
    'stats_title': 'Stats van {}',
    'stats_games': 'Spellen',
    'stats_wins': 'Gewonnen',
    'stats_win_rate': 'Win %',
    'stats_best_game': 'Beste Score',
    'stats_avg_points': 'Gem. Punten',
    'stats_past_games': 'Vorige Spellen',
    'stats_no_games': 'Nog geen spellen gespeeld.',

    // History
    'history_title': 'Spelgeschiedenis',
    'history_empty': 'Nog geen voltooide spellen.',
    'history_winner': 'Winnaar: {} ({} ptn)',
    'history_rounds_played': '{} rondes gespeeld',
    'history_abandoned': 'Afgebroken',
    'game_recap': 'Speloverzicht',
    'final_scores': 'EINDSCORE',

    // Settings
    'settings_title': 'Punteninstellingen',
    'settings_adjust': 'Puntensysteem',
    'settings_auto_save': 'Wijzigingen worden automatisch opgeslagen na elk spel.',
    'settings_decrease': 'Verlaag {}',
    'settings_increase': 'Verhoog {}',
    'settings_partnership': 'Duo Contracten',
    'settings_solo': 'Solo Contracten',
    'settings_negative': 'Speciale Contracten',
    'settings_danger_zone': 'Gevarenzone',
    'settings_language': 'Taal',
    'settings_lang_en': 'Engels',
    'settings_lang_nl': 'Nederlands',
    'settings_theme': 'Weergave',
    'settings_theme_dark': 'Donker',
    'settings_theme_light': 'Licht',
    'settings_theme_system': 'Systeem',
    'settings_slim_bonus': 'Bonus voor Alle 13',
    'settings_slim_bonus_desc': 'Alle 13 slagen verdubbelt de punten van die ronde (niet Solo Slim, dat al het bod voor alle 13 is).',
    'settings_on': 'AAN',
    'settings_off': 'UIT',

    // Statistiekenpaneel (ALTERATIONS.md ronde 2, Deel C) & Solo Slim kroon (Deel D)
    'close': 'Sluiten',
    'crown_solo_slim': 'Solo Slim',
    'crown_solo_slim_desc':
        'Helemaal alleen gespeeld en alle 13 slagen gehaald — het zeldzaamste resultaat in het spel.',
    'crown_round': 'Ronde {}',
    'crown_in_progress': 'Huidig spel',
    'crown_times': '{}x',
    'stats_section_title': 'Statistieken',
    'stats_title_charts': 'Grafieken',
    'stats_chart_progression': 'Scoreverloop',
    'stats_chart_trumps': 'Gekozen troefkleuren',
    'stats_chart_contract_success': 'Slaagkans per contract',
    'stats_chart_accuracy': 'Biednauwkeurigheid',
    'stats_chart_risk': 'Risicofactor',
    'stats_table_average': 'Tafelgemiddelde',
    'stats_no_data': 'Nog niet genoeg rondes',
    'stats_untracked_trump': '{} rondes zonder geregistreerde troef',
    'stats_miserie_note': 'Een Miserie met twee telt alleen als geslaagd wanneer beiden slagen.',
    'stats_risk_help': 'Hoe vaak deze speler mee in het contract zat.',

    // Settings — Support (advertenties / aankopen)
    'settings_support': 'Steun Whistly',
    'settings_remove_ads': 'Advertenties verwijderen',
    'settings_remove_ads_desc':
        'Geniet je van Whistly? Verwijder alle advertenties met een eenmalige aankoop.',
    'settings_restore': 'Aankopen herstellen',
    'settings_purchased': 'Aangeschaft ✓',
    'purchase_failed': 'Aankoop mislukt. Probeer het opnieuw.',
    'purchase_restored': 'Je aankoop is hersteld.',
    'purchase_unavailable': 'De winkel is momenteel niet beschikbaar. Probeer het later opnieuw.',

    // Bids (Dutch)
    'bid_ask_join': 'Vraag & Mee',
    'bid_trull': 'Troel',
    'bid_alone': 'Alleen',
    'bid_misere': 'Miserie',
    'bid_open_misere': 'Open Miserie',
    'bid_abundance': 'Abondance',
    'bid_solo_slim': 'Solo Slim',
    'bid_pass': 'Rondpas',
    'bid_base_points': 'Basis Punten',
    'bid_bonus_trick': 'Bonus per Extra Slag',
    'bid_tricks_n': '{} slagen',
    'setup_tricks_n': 'Vraag & Mee ({})',

    // Rules
    'rules_title': 'Spelregels (Kleurenwiezen)',
    'rules_hero': 'De Traditionele Belgische Wiezen',

    // Section 1
    'rules_section1_title': '1. Introductie & De Deling',
    'rules_sec1_obj_title': 'Het Doel',
    'rules_sec1_obj_desc': 'Win slagen om aan je bieding te voldoen en scoor punten. Je speelt samen met een partner, of helemaal alleen.',
    'rules_sec1_cards_title': 'Kaartwaarde',
    'rules_sec1_cards_desc': 'A (Hoogste) - K - Q - J - 10 - 9 - 8 - 7 - 6 - 5 - 4 - 3 - 2 (Laagste).',
    'rules_sec1_trump_title': 'Wat is "Troef"?',
    'rules_sec1_trump_desc': 'De troefkleur is de overheersende kleur in een ronde en overtreft alle andere kleuren. Heb je de gevraagde kleur niet, dan kun je een troefkaart spelen ("kopen") om de slag te winnen van normale kleuren.',
    'rules_sec1_deal_title': 'De Deling',
    'rules_sec1_deal_desc': 'Er wordt gespeeld met 52 kaarten. Elke speler krijgt 13 kaarten (meestal 4-4-5 gedeeld). De deler wisselt per ronde, met de klok mee.',

    // Section 2
    'rules_section2_title': '2. Het Biedverloop',
    'rules_sec2_stage1_title': 'Fase 1: Troel Aankondigen',
    'rules_sec2_stage1_desc': 'Voorafgaand aan het bieden checkt iedereen op Troel (3 of 4 Azen). Bij 3 Azen zegt de 4e Aas "met mij". Bij 4 Azen roep je de hoogste Harten die je niét hebt, en die speler zegt "met mij". Enkel hogere contracten zoals Miserie kunnen Troel nog overbieden.',
    'rules_sec2_stage2_title': 'Fase 2: Duo\'s Vormen',
    'rules_sec2_stage2_desc': 'Zonder Troel start het bieden. Je kan een kleur "Vragen" (geldig tot je volgende beurt; één keer hernieuwbaar), "Passen", of "Wachten" (enkel 1e speler). Je kan ook direct een speciaal contract zoals Miserie of Abondance aankondigen in plaats van te vragen. "Wachten" houdt de optie open om later mee te gaan, maar je kan zelf niets meer vragen. Als iedereen past, deelt dezelfde deler opnieuw.',
    'rules_sec2_stage3_title': 'Fase 3: Biedstrijd & Prioriteit',
    'rules_sec2_stage3_desc': 'Als er verschillende teams of solo-bieders zijn, geldt de Kleur-Prioriteit: Harten (♥) > Koeken (♦) > Klaveren (♣) > Schoppen (♠). Het bod met de lagere kleur moet een slag méér bieden om in het spel te blijven.',


    // Section 3
    'rules_section3_title': '3. Speciale Contracten',
    'rules_sec3_intro_desc': 'Spelers kunnen ook speciale biedingen doen in plaats van "Vraag & Mee". Deze overtreffen normale biedingen.',
    'rules_sec3_trull_title': 'Troel',
    'rules_sec3_trull_desc': 'Verplicht te roepen bij 3 of 4 Azen, vóór het normale bieden start. Je partner is de 4e Aas (of de hoogste Harten die je zelf niet hebt). Troef is de kleur van je partner, doel is 9 slagen.',
    'rules_sec3_alone_title': 'Alleen (Solo)',
    'rules_sec3_alone_desc': 'Speel alleen tegen de andere drie voor 5 t.e.m. 8 slagen. Je mag dit ENKEL bieden als een "Vraag & Mee" faalt (bv. niemand ging mee, of je partner past). Er is geen beloning voor méér dan 8 slagen; wil je er 9+, dan moet je direct Abondance bieden.',
    'rules_sec3_misery_title': 'Miserie',
    'rules_sec3_misery_desc': 'Speel helemaal alleen en probeer exact 0 slagen te halen. In dit contract is er géén troefkleur.',
    'rules_sec3_abundance_title': 'Abondance',
    'rules_sec3_abundance_desc': 'Speel alleen voor 9, 10, 11 of 12 slagen met een zelfgekozen troefkleur. Je MOET dit onmiddellijk doen de allereerste keer dat je aan de beurt bent—je mag niet eerst "Vragen" en later veranderen naar Abondance.',
    'rules_sec3_soloslim_title': 'Solo Slim',
    'rules_sec3_soloslim_desc': 'De ultieme uitdaging: helemaal alleen spelen en alle 13 slagen halen.',

    // Section 4
    'rules_section4_title': '4. Spelverloop',
    'rules_sec4_lead_title': 'Uitkomen',
    'rules_sec4_lead_desc': 'In de meeste contracten (en Miserie) komt de persoon links van de deler uit. Bij Abondance of Solo Slim komt de winnaar van de bieding echter zelf uit. Bij Troel gelden specifieke regels afhankelijk van wie de troef bepaalde.',
    'rules_sec4_follow_title': 'Kleur Bekennen & Kopen',
    'rules_sec4_follow_desc': 'Je MOET de uitgevraagde kleur altijd volgen. Kan je dat niet? Dan mag je een troefkaart spelen ("kopen"), maar dat is NOOIT verplicht. Je mag evengoed een andere kaart weggooien of "onder-kopen". Je bent in kleurenwiezen bovendien absoluut niet verplicht om een slag proberen te winnen of om hoger te gaan.',
    'rules_sec4_win_title': 'De Slag Winnen',
    'rules_sec4_win_desc': 'De hoogste kaart van de gevraagde kleur wint, behalve als er getroefd wordt. Liggen er meerdere troeven, dan wint de hoogste.',

    // Section 5
    'rules_section5_title': '5. Scores & Bonussen',
    'rules_sec5_success_title': 'Een Contract Winnen',
    'rules_sec5_success_desc': 'Bij duo-spellen (Vraag & Mee, Troel) winnen beide partners punten. Als je ALLEEN speelt (Solo, Abondance, Miserie), win je punten van ELK van de 3 tegenstanders (dus x3 in totaal).',
    'rules_sec5_bonus_title': 'Overslagen (Bonussen)',
    'rules_sec5_bonus_desc': 'Bij duo-spellen levert elke slag BOVEN het doel +1 bonuspunt op. Let op: bij Solo (max 8) en Abondance tellen overslagen vaak niet extra mee afhankelijk van het niveau.',
    'rules_sec5_fail_title': 'Een Contract Verliezen',
    'rules_sec5_fail_desc': 'Haal je je doel niet? Dan verlies je de basispunten van het contract. Speelde je alleen? Dan betaal je deze basispunten aan ELKE tegenstander.',
    'rules_sec5_hierarchy_cta': 'Bekijk de exacte basiswaarden in de Bied-Rangorde tabel hieronder.',

    'rules_table_type': 'Type Bod',
    'rules_table_priority': 'Prioriteit',
    'rules_table_tricks': 'Slagen',
    'rules_table_base': 'Basis Ptn',
    'rules_suit_hearts': 'Harten',
    'rules_suit_diamonds': 'Koeken',
    'rules_suit_clubs': 'Klaveren',
    'rules_suit_spades': 'Schoppen',
    'rules_view_hierarchy': 'Bekijk Bied-Rangorde',
    'hierarchy_title': 'Bied-Rangorde',
    'rules_footer_note': '* Basispunten. Overslagen leveren +1 bonuspunt per extra slag op (afhankelijk van instellingen/niveau).',

    'settings_delete_all': 'Verwijder Alle Gegevens',
    'delete_confirm_title': 'Weet je het heel zeker?',
    'delete_confirm_desc':
        'Dit zal permanent alle spelers, spelgeschiedenis en actieve sessies wissen. Dit kan niet ongedaan worden gemaakt.',
    'delete_confirm_btn': 'WIS ALLES',
  };
}
