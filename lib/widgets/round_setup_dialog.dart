import 'package:flutter/material.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:whistly/theme/whistly_components.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/game_player_ref.dart';
import 'package:whistly/providers/game_provider.dart';
import 'package:whistly/providers/localization_provider.dart';
import 'package:whistly/scoring_settings.dart';

// Helper to get localized contract name
String getContractName(LocalizationProvider loc, String key) {
  switch (key) {
    case 'Ask & Join': return loc.translate('bid_ask_join');
    case 'Trull': return loc.translate('bid_trull');
    case 'Solo': return loc.translate('bid_alone');
    case 'Abondance': return loc.translate('bid_abundance');
    case 'Miserie': return loc.translate('bid_misere');
    case 'Open Miserie': return loc.translate('bid_open_misere');
    case 'Solo Slim': return loc.translate('bid_solo_slim');
    case 'Pass': return loc.translate('bid_pass');
    default: return key;
  }
}

// All contract types in Belgian Whist / Wiezen
const List<Map<String, dynamic>> kContracts = [
  {'key': 'Ask & Join', 'icon': Icons.people, 'needsPartner': true, 'hasTricks': true, 'required': 8},
  {'key': 'Trull', 'icon': Icons.style, 'needsPartner': true, 'hasTricks': true, 'required': 9},
  {'key': 'Solo', 'icon': Icons.person, 'needsPartner': false, 'hasTricks': true, 'required': 5},
  {'key': 'Abondance', 'icon': Icons.trending_up, 'needsPartner': false, 'hasTricks': true, 'required': 9},
  {'key': 'Miserie', 'icon': Icons.block, 'needsPartner': false, 'hasTricks': false, 'required': 0},
  {'key': 'Open Miserie', 'icon': Icons.visibility, 'needsPartner': false, 'hasTricks': false, 'required': 0},
  {'key': 'Solo Slim', 'icon': Icons.star, 'needsPartner': false, 'hasTricks': true, 'required': 13},
  {'key': 'Pass', 'icon': Icons.skip_next, 'needsPartner': false, 'hasTricks': false, 'required': 0, 'isPass': true},
];

class RoundSetupDialog extends StatefulWidget {
  final List<GamePlayerRef> players;
  const RoundSetupDialog({super.key, required this.players});

  @override
  State<RoundSetupDialog> createState() => _RoundSetupDialogState();
}

class _RoundSetupDialogState extends State<RoundSetupDialog> {
  int _step = 0; // 0: contract type, 1: players, 2: trump, 3: result
  Map<String, dynamic>? _selectedContract;
  GamePlayerRef? _declarer;
  GamePlayerRef? _partner;
  String? _selectedTrump;
  int _tricksWon = 0;
  int _agreedTricks = 8;
  int _miseriePlayerCount = 1;
  bool _declarerMiserieSuccess = true;
  bool _partnerMiserieSuccess = true;

  bool get _needsPartner {
    final key = _selectedContract?['key'];
    if (key == 'Miserie' || key == 'Open Miserie') {
      return _miseriePlayerCount == 2;
    }
    return _selectedContract?['needsPartner'] == true;
  }

  void _nextStep() {
    // Skip trump selection for Misery
    if (_step == 1 && _selectedContract?['hasTricks'] == false) {
      _selectedTrump = null;
      setState(() => _step = 3);
    } else {
      setState(() => _step++);
    }
  }

  void _prevStep() {
    if (_step == 3 && _selectedContract?['hasTricks'] == false) {
      setState(() => _step = 1);
    } else {
      setState(() => _step--);
    }
  }

  void _submit() {
    if (_selectedContract == null || _declarer == null) return;
    final gameProvider = context.read<GameProvider>();
    final settings = context.read<ScoringSettings>();

    gameProvider.addRound(
      contractType: _selectedContract!['key'],
      declarerId: _declarer!.id,
      partnerId: _partner?.id,
      tricksWon: _tricksWon,
      agreedTricks: _agreedTricks,
      miserieSuccess: _declarerMiserieSuccess,
      partnerMiserieSuccess: _partnerMiserieSuccess,
      settings: settings,
      trump: _selectedTrump,
    );
    Navigator.pop(context);
  }

  void _submitPass() {
    context.read<GameProvider>().addPassRound();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocalizationProvider>();
    final colors = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        border: Border(top: BorderSide(color: colors.line, width: 2)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 22,
        right: 22,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — flush left, per spec (no centered headings).
          Row(
            children: [
              if (_step > 0)
                IconButton(
                  icon: Icon(Icons.arrow_back, color: colors.ink),
                  onPressed: _prevStep,
                ),
              Expanded(
                child: Text(_stepTitle(loc), style: WhistlyText.sectionHead(colors.ink)),
              ),
            ],
          ),
          // Step indicator — radius 0, per spec §3.
          Row(
            children: List.generate(4, (i) {
              // Hide step 2 dot if misere
              if (i == 2 && _selectedContract?['hasTricks'] == false) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(right: 4, top: 12, bottom: 12),
                child: Container(
                  width: i == _step ? 20 : 8,
                  height: 4,
                  color: i == _step ? colors.accent : colors.line,
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          // Step content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildStep(loc),
          ),
        ],
      ),
    );
  }

  String _stepTitle(LocalizationProvider loc) {
    switch (_step) {
      case 0: return loc.translate('setup_contract_step');
      case 1: return loc.translate('setup_players_step');
      case 2: return loc.translate('setup_trump_step');
      case 3: return loc.translate('setup_result_step');
      default: return '';
    }
  }

  Widget _buildStep(LocalizationProvider loc) {
    switch (_step) {
      case 0: return _buildContractStep(loc);
      case 1: return _buildPlayersStep(loc);
      case 2: return _buildTrumpStep(loc);
      case 3: return _buildResultStep(loc);
      default: return const SizedBox();
    }
  }

  Widget _buildContractStep(LocalizationProvider loc) {
    final colors = AppTheme.of(context);
    return Column(
      key: const ValueKey(0),
      mainAxisSize: MainAxisSize.min,
      children: kContracts.map((contract) {
        final selected = _selectedContract?['key'] == contract['key'];
        final displayName = getContractName(loc, contract['key']);
        final isPass = contract['isPass'] == true;
        return InkWell(
          onTap: () {
            if (isPass) {
              _submitPass();
              return;
            }
            setState(() {
              _selectedContract = contract;
              _partner = null;
              _miseriePlayerCount = 1;
              final req = (contract['required'] as int);
              _agreedTricks = req;
              _tricksWon = req;
              _declarerMiserieSuccess = true;
              _partnerMiserieSuccess = true;
            });
            // Auto-advance to next step
            Future.delayed(const Duration(milliseconds: 150), _nextStep);
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colors.line, width: 1),
                left: BorderSide(color: selected ? colors.ink : Colors.transparent, width: 2),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Icon(contract['icon'] as IconData, size: 18, color: isPass ? colors.accent : colors.ink),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(displayName, style: WhistlyText.rowTitle(colors.ink)),
                ),
                if (isPass)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: colors.accent,
                    child: Text('x2', style: WhistlyText.badge(colors.onAccent)),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlayersStep(LocalizationProvider loc) {
    final needsPartner = _needsPartner;
    final isMiserie = _selectedContract?['hasTricks'] == false && _selectedContract?['isPass'] != true;

    return Column(
      key: const ValueKey(1),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMiserie) ...[
          WhistlyToggleRow<int>(
            options: [
              (1, loc.currentLanguage == AppLanguage.nl ? '1 Speler' : '1 Player'),
              (2, loc.currentLanguage == AppLanguage.nl ? '2 Spelers' : '2 Players'),
            ],
            selected: _miseriePlayerCount,
            onChanged: (val) {
              setState(() {
                _miseriePlayerCount = val;
                _declarer = null;
                _partner = null;
              });
            },
          ),
          const SizedBox(height: 16),
        ],
        _playerSelector(
          loc: loc,
          label: isMiserie
              ? (needsPartner
                  ? (loc.currentLanguage == AppLanguage.nl ? 'Speler 1' : 'Player 1')
                  : (loc.currentLanguage == AppLanguage.nl ? 'Miserie Speler' : 'Misery Player'))
              : loc.translate('declarer'),
          selected: _declarer,
          onSelect: (p) {
            setState(() {
              _declarer = p;
              if (_partner == p) _partner = null;
            });
            if (!needsPartner || _partner != null) {
              Future.delayed(const Duration(milliseconds: 300), _nextStep);
            }
          },
          disabledPlayer: null,
        ),
        if (needsPartner) ...[
          const SizedBox(height: 8),
          _playerSelector(
            loc: loc,
            label: isMiserie
                ? (loc.currentLanguage == AppLanguage.nl ? 'Speler 2' : 'Player 2')
                : loc.translate('partner'),
            selected: _partner,
            onSelect: (p) {
              setState(() {
                _partner = p;
                if (_declarer == p) _declarer = null;
              });
              if (_declarer != null) {
                Future.delayed(const Duration(milliseconds: 300), _nextStep);
              }
            },
            disabledPlayer: _declarer,
          ),
        ],
      ],
    );
  }

  Widget _playerSelector({
    required LocalizationProvider loc,
    required String label,
    required GamePlayerRef? selected,
    required void Function(GamePlayerRef) onSelect,
    GamePlayerRef? disabledPlayer,
  }) {
    final colors = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
        const SizedBox(height: 8),
        Column(
          children: widget.players.map((player) {
            final isSelected = selected?.id == player.id;
            final isDisabled = disabledPlayer?.id == player.id;
            return Opacity(
              opacity: isDisabled ? 0.35 : 1.0,
              child: InkWell(
                onTap: isDisabled ? null : () => onSelect(player),
                child: Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colors.line, width: 1))),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(player.name, style: WhistlyText.rowTitle(colors.ink))),
                      if (isSelected) Icon(Icons.check, size: 18, color: colors.accent),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTrumpStep(LocalizationProvider loc) {
    final colors = AppTheme.of(context);
    final suits = [
      ('Hearts', '♥', true),
      ('Diamonds', '♦', true),
      ('Clubs', '♣', false),
      ('Spades', '♠', false),
    ];

    return Column(
      key: const ValueKey(1.5),
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(loc.translate('setup_trump_step').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
        ),
        const SizedBox(height: 12),
        Container(
          color: colors.line,
          child: Row(
            children: List.generate(suits.length, (i) {
              final (key, glyph, isRed) = suits[i];
              final isSelected = _selectedTrump == key;
              return Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedTrump = key);
                    Future.delayed(const Duration(milliseconds: 300), _nextStep);
                  },
                  child: Container(
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 2),
                    height: 72,
                    color: colors.bg,
                    alignment: Alignment.center,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: isSelected ? colors.ink : Colors.transparent, width: 2),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        glyph,
                        style: TextStyle(fontSize: 28, color: isRed ? colors.suitRed : colors.suitInk),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildResultStep(LocalizationProvider loc) {
    final contract = _selectedContract!;
    final name = contract['key'] as String;
    final hasTricks = contract['hasTricks'] == true;
    final isNegotiable = name == 'Ask & Join' || name == 'Solo' || name == 'Abondance';
    final isMiserie = !hasTricks;

    bool success;
    if (isMiserie) {
      if (_partner != null) {
        success = _declarerMiserieSuccess || _partnerMiserieSuccess;
      } else {
        success = _declarerMiserieSuccess;
      }
    } else {
      success = _tricksWon >= _agreedTricks;
    }

    final colors = AppTheme.of(context);
    return Column(
      key: const ValueKey(2),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isNegotiable) ...[
          _counterField(
            label: loc.translate('setup_negotiated'),
            value: _agreedTricks,
            min: contract['required'],
            max: 13,
            onChanged: (val) => setState(() {
              _agreedTricks = val;
              if (_tricksWon < _agreedTricks) _tricksWon = _agreedTricks;
            }),
          ),
          const SizedBox(height: 16),
        ],
        if (hasTricks) ...[
          _counterField(
            label: loc.translate('setup_tricks_won'),
            value: _tricksWon,
            min: 0,
            max: 13,
            onChanged: (val) => setState(() => _tricksWon = val),
          ),
          const SizedBox(height: 12),
        ],
        if (isMiserie) ...[
          if (_partner != null) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_declarer!.name.toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
            ),
            const SizedBox(height: 6),
            WhistlyToggleRow<bool>(
              options: [
                (true, loc.translate('setup_succeeded')),
                (false, loc.translate('setup_failed')),
              ],
              selected: _declarerMiserieSuccess,
              onChanged: (val) => setState(() => _declarerMiserieSuccess = val),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_partner!.name.toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
            ),
            const SizedBox(height: 6),
            WhistlyToggleRow<bool>(
              options: [
                (true, loc.translate('setup_succeeded')),
                (false, loc.translate('setup_failed')),
              ],
              selected: _partnerMiserieSuccess,
              onChanged: (val) => setState(() => _partnerMiserieSuccess = val),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(loc.translate('setup_result').toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
            ),
            const SizedBox(height: 8),
            WhistlyToggleRow<bool>(
              options: [
                (true, loc.translate('setup_succeeded')),
                (false, loc.translate('setup_failed')),
              ],
              selected: _declarerMiserieSuccess,
              onChanged: (val) => setState(() => _declarerMiserieSuccess = val),
            ),
            const SizedBox(height: 16),
          ],
        ],
        // One accent element per screen region (spec §1.3): this primary
        // button stays accent-filled regardless of win/lose/mixed outcome
        // — that feedback belongs to the result badge on the round row
        // and standings list once submitted, not a second accent color
        // here.
        WhistlyPrimaryButton(
          label: _confirmButtonLabel(loc, success, isMiserie),
          showChevron: false,
          onPressed: _submit,
        ),
      ],
    );
  }

  // Helper: pick confirm button label based on context
  String _confirmButtonLabel(LocalizationProvider loc, bool success, bool isMiserie) {
    if (isMiserie && _partner != null) {
      if (_declarerMiserieSuccess == _partnerMiserieSuccess) {
        return loc.translate(_declarerMiserieSuccess ? 'confirm_win' : 'confirm_loss');
      }
      return loc.translate('setup_confirm'); // neutral "CONFIRM ROUND"
    }
    return loc.translate(success ? 'confirm_win' : 'confirm_loss');
  }

  Widget _counterField({
    required String label,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    final colors = AppTheme.of(context);
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(label.toUpperCase(), style: WhistlyText.eyebrow(colors.muted)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _stepperButton(Icons.remove, value > min ? () => onChanged(value - 1) : null),
            const SizedBox(width: 24),
            Text('$value', style: WhistlyText.screenNumeral(colors.ink, size: 32)),
            const SizedBox(width: 24),
            _stepperButton(Icons.add, value < max ? () => onChanged(value + 1) : null),
          ],
        ),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback? onPressed) {
    final colors = AppTheme.of(context);
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(border: Border.all(color: enabled ? colors.ink : colors.line, width: 2)),
        child: Icon(icon, size: 20, color: enabled ? colors.ink : colors.muted),
      ),
    );
  }
}
