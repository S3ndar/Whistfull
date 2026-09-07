import 'package:flutter/material.dart';
import 'package:whistly/app_colors.dart';
import 'package:whistly/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:whistly/models/player.dart';
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
  final List<Player> players;
  const RoundSetupDialog({super.key, required this.players});

  @override
  State<RoundSetupDialog> createState() => _RoundSetupDialogState();
}

class _RoundSetupDialogState extends State<RoundSetupDialog> {
  int _step = 0; // 0: contract type, 1: players, 2: trump, 3: result
  Map<String, dynamic>? _selectedContract;
  Player? _declarer;
  Player? _partner;
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
    final appColors = AppTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: appColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              if (_step > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _prevStep,
                ),
              Expanded(
                child: Text(
                  _stepTitle(loc),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              if (_step > 0) const SizedBox(width: 48),
            ],
          ),
          // Step indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
               // Hide step 2 dot if misere
               if (i == 2 && _selectedContract?['hasTricks'] == false) return const SizedBox();
               return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                width: i == _step ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _step ? appColors.error : appColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
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
      case 0: return loc.translate('setup_contract_step') != 'setup_contract_step' ? loc.translate('setup_contract_step') : 'Select Contract';
      case 1: return loc.translate('setup_players_step') != 'setup_players_step' ? loc.translate('setup_players_step') : 'Select Players';
      case 2: return loc.translate('setup_trump_step') != 'setup_trump_step' ? loc.translate('setup_trump_step') : 'Select Trump';
      case 3: return loc.translate('setup_result_step') != 'setup_result_step' ? loc.translate('setup_result_step') : 'Enter Result';
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
    final appColors = AppTheme.of(context);
    return Column(
      key: const ValueKey(0),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kContracts.map((contract) {
            final selected = _selectedContract?['key'] == contract['key'];
            final displayName = getContractName(loc, contract['key']);
            final isPass = contract['isPass'] == true;
            return GestureDetector(
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
                width: (MediaQuery.of(context).size.width - 50) / 2,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: isPass
                      ? appColors.panel
                      : selected ? AppColors.selectedBg : appColors.surfaceDim,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPass
                        ? appColors.accentGold.withValues(alpha: 0.7)
                        : selected ? appColors.error : appColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(contract['icon'] as IconData,
                        size: 18,
                        color: isPass
                            ? appColors.accentGold
                            : selected ? appColors.textPrimary : appColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        style: TextStyle(
                          fontWeight: isPass || selected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                          color: isPass
                              ? appColors.accentGold
                              : selected ? appColors.textPrimary : appColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPass) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: appColors.accentGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: appColors.accentGold.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          'x2',
                          style: TextStyle(
                            color: appColors.accentGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildPlayersStep(LocalizationProvider loc) {
    final appColors = AppTheme.of(context);
    final needsPartner = _needsPartner;
    final isMiserie = _selectedContract?['hasTricks'] == false && _selectedContract?['isPass'] != true;

    return Column(
      key: const ValueKey(1),
      children: [
        if (isMiserie) ...[
          SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 1,
                label: Text(loc.currentLanguage == AppLanguage.nl ? '1 Speler' : '1 Player'),
                icon: const Icon(Icons.person),
              ),
              ButtonSegment(
                value: 2,
                label: Text(loc.currentLanguage == AppLanguage.nl ? '2 Spelers' : '2 Players'),
                icon: const Icon(Icons.people),
              ),
            ],
            selected: {_miseriePlayerCount},
            onSelectionChanged: (val) {
              setState(() {
                _miseriePlayerCount = val.first;
                // Reset both player selections when switching count
                _declarer = null;
                _partner = null;
              });
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.selectedBg,
              selectedForegroundColor: appColors.textPrimary,
            ),
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
            // Auto-advance if complete
            if (!needsPartner || _partner != null) {
              Future.delayed(const Duration(milliseconds: 300), _nextStep);
            }
          },
          disabledPlayer: null,
        ),
        if (needsPartner) ...[
          const SizedBox(height: 12),
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
              // Auto-advance if complete
              if (_declarer != null) {
                Future.delayed(const Duration(milliseconds: 300), _nextStep);
              }
            },
            disabledPlayer: _declarer,
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _playerSelector({
    required LocalizationProvider loc,
    required String label,
    required Player? selected,
    required void Function(Player) onSelect,
    Player? disabledPlayer,
  }) {
    final appColors = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label.toUpperCase(),
            style: TextStyle(color: appColors.textFaint, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: widget.players.map((player) {
            final isSelected = selected?.id == player.id;
            final isDisabled = disabledPlayer?.id == player.id;
            return GestureDetector(
              onTap: isDisabled ? null : () => onSelect(player),
              child: Opacity(
                opacity: isDisabled ? 0.3 : 1.0,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? appColors.error : AppColors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: isSelected ? AppColors.selectedBg : appColors.surfaceDim,
                            child: Text(
                              player.name[0].toUpperCase(),
                              style: TextStyle(
                                color: isSelected ? appColors.textPrimary : appColors.textFaint,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(color: appColors.error, shape: BoxShape.circle),
                              child: Icon(Icons.check, size: 10, color: appColors.textPrimary),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      player.name.split(' ').first,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? appColors.textPrimary : appColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTrumpStep(LocalizationProvider loc) {
    final appColors = AppTheme.of(context);
    final suits = [
      {'key': 'Hearts', 'icon': '♥', 'color': AppColors.suitRed},
      {'key': 'Diamonds', 'icon': '♦', 'color': AppColors.suitRed},
      {'key': 'Clubs', 'icon': '♣', 'color': AppColors.suitBlack},
      {'key': 'Spades', 'icon': '♠', 'color': AppColors.suitBlack},
    ];

    return Column(
      key: const ValueKey(1.5),
      children: [
        Text('SELECT THE TRUMP SUIT', style: TextStyle(color: appColors.textFaint, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: suits.map((s) {
            final isSelected = _selectedTrump == s['key'];
            return GestureDetector(
              onTap: () {
                setState(() => _selectedTrump = s['key'] as String);
                Future.delayed(const Duration(milliseconds: 300), _nextStep);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.selectedBg : appColors.surfaceDim,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? appColors.error : appColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    s['icon'] as String,
                    style: TextStyle(
                      fontSize: 28,
                      color: isSelected ? s['color'] as Color : (s['color'] as Color).withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
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

    final appColors = AppTheme.of(context);
    return Column(
      key: const ValueKey(2),
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
            Text(
              _declarer!.name.toUpperCase(),
              style: TextStyle(color: appColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(loc.translate('setup_succeeded')), icon: const Icon(Icons.check)),
                ButtonSegment(value: false, label: Text(loc.translate('setup_failed')), icon: const Icon(Icons.close)),
              ],
              selected: {_declarerMiserieSuccess},
              onSelectionChanged: (val) => setState(() => _declarerMiserieSuccess = val.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _declarerMiserieSuccess ? appColors.success : appColors.error,
                selectedForegroundColor: appColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _partner!.name.toUpperCase(),
              style: TextStyle(color: appColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(loc.translate('setup_succeeded')), icon: const Icon(Icons.check)),
                ButtonSegment(value: false, label: Text(loc.translate('setup_failed')), icon: const Icon(Icons.close)),
              ],
              selected: {_partnerMiserieSuccess},
              onSelectionChanged: (val) => setState(() => _partnerMiserieSuccess = val.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _partnerMiserieSuccess ? appColors.success : appColors.error,
                selectedForegroundColor: appColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(loc.translate('setup_result'), style: TextStyle(color: appColors.textFaint, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(loc.translate('setup_succeeded')), icon: const Icon(Icons.check)),
                ButtonSegment(value: false, label: Text(loc.translate('setup_failed')), icon: const Icon(Icons.close)),
              ],
              selected: {_declarerMiserieSuccess},
              onSelectionChanged: (val) => setState(() => _declarerMiserieSuccess = val.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _declarerMiserieSuccess ? appColors.success : appColors.error,
                selectedForegroundColor: appColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _confirmButtonColor(success, isMiserie),
            foregroundColor: appColors.textPrimary,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: _confirmButtonColor(success, isMiserie).withValues(alpha: 0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_confirmButtonIcon(success, isMiserie)),
              const SizedBox(width: 12),
              Text(
                _confirmButtonLabel(loc, success, isMiserie),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Helper: pick confirm button color based on context
  Color _confirmButtonColor(bool success, bool isMiserie) {
    final appColors = AppTheme.of(context);
    if (isMiserie && _partner != null) {
      // Mixed outcome = neutral; both succeed = green; both fail = red
      if (_declarerMiserieSuccess && _partnerMiserieSuccess) return appColors.success;
      if (!_declarerMiserieSuccess && !_partnerMiserieSuccess) return appColors.error;
      return AppColors.selectedBg; // one wins, one loses
    }
    return success ? appColors.success : AppColors.selectedBg;
  }

  // Helper: pick confirm button icon based on context
  IconData _confirmButtonIcon(bool success, bool isMiserie) {
    if (isMiserie && _partner != null) {
      if (_declarerMiserieSuccess && _partnerMiserieSuccess) return Icons.emoji_events;
      if (!_declarerMiserieSuccess && !_partnerMiserieSuccess) return Icons.error_outline;
      return Icons.splitscreen; // mixed
    }
    return success ? Icons.emoji_events : Icons.error_outline;
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
    final appColors = AppTheme.of(context);
    return Column(
      children: [
        Text(label, style: TextStyle(color: appColors.textFaint, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton.filled(
              onPressed: value > min ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: appColors.surface,
                foregroundColor: appColors.error,
                minimumSize: const Size(44, 44),
              ),
            ),
            const SizedBox(width: 24),
            Text('$value', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(width: 24),
            IconButton.filled(
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: appColors.surfaceDim,
                foregroundColor: AppColors.infoBlue,
                minimumSize: const Size(44, 44),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
