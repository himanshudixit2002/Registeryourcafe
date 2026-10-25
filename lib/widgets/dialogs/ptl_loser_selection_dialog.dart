import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:registeryourcafe/constants/app_strings.dart';
import 'package:registeryourcafe/theme/app_theme.dart';

class PTLLoserSelectionDialog extends StatefulWidget {
  final List<String> playerNames;
  final int playerCount;

  const PTLLoserSelectionDialog({
    super.key,
    required this.playerNames,
    required this.playerCount,
  });

  @override
  State<PTLLoserSelectionDialog> createState() =>
      _PTLLoserSelectionDialogState();
}

class _PTLLoserSelectionDialogState extends State<PTLLoserSelectionDialog>
    with TickerProviderStateMixin {
  int? _selectedPlayer;
  late AnimationController _shakeController;
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  bool _isConfirming = false;
  bool _showCountdown = false;
  int _countdownValue = 3;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    );
    _slideController.forward();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.reset();
    _shakeController.forward();
  }

  Future<void> _startCountdown() async {
    if (_selectedPlayer == null) {
      _triggerShake();
      await HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _showCountdown = true;
      _countdownValue = 3;
    });

    for (int i = 3; i > 0; i--) {
      if (!mounted) return;
      setState(() => _countdownValue = i);
      await HapticFeedback.mediumImpact();
      await Future<void>.delayed(const Duration(seconds: 1));
    }

    if (!mounted) return;
    setState(() {
      _isConfirming = true;
      _showCountdown = false;
    });

    await HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.of(context).pop(_selectedPlayer);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = AppSemanticColors.of(context);
    return Stack(
      children: [
        SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(_slideAnimation),
          child: FadeTransition(
            opacity: _slideAnimation,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.emoji_events_outlined,
                      color: cs.error,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Loser To Pay',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          'Select the losing player',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            sem.warningContainer,
                            cs.errorContainer,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: sem.warning.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: sem.warning,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'The selected player will settle the entire bill',
                              style: TextStyle(
                                fontSize: 12,
                                color: sem.onWarningContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...List.generate(widget.playerCount, (index) {
                      final playerNumber = index + 1;
                      final playerName =
                          (widget.playerNames.isNotEmpty &&
                              index < widget.playerNames.length)
                          ? widget.playerNames[index]
                          : 'Player $playerNumber';
                      final isSelected = _selectedPlayer == playerNumber;

                      return AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale = isSelected
                              ? 1.0 + (_pulseController.value * 0.03)
                              : 1.0;
                          return TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, animation, child) {
                              return Transform.scale(
                                scale: scale,
                                child: Opacity(
                                  opacity: 0.4 + (animation * 0.6),
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - animation) * 20),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(
                                    () => _selectedPlayer = playerNumber,
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? LinearGradient(
                                            colors: [
                                              cs.error,
                                              cs.error.withValues(alpha: 0.85),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isSelected
                                        ? null
                                        : cs.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isSelected
                                          ? cs.error
                                          : cs.outlineVariant,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: cs.error.withValues(
                                                alpha: 0.35,
                                              ),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? cs.onError.withValues(
                                                  alpha: 0.2,
                                                )
                                              : cs.surfaceContainerHighest,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isSelected
                                              ? Icons.emoji_events
                                              : Icons.person,
                                          color: isSelected
                                              ? cs.onError
                                              : cs.onSurfaceVariant,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              playerName,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected
                                                    ? cs.onError
                                                    : cs.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Player #$playerNumber',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: isSelected
                                                    ? cs.onError.withValues(
                                                        alpha: 0.9,
                                                      )
                                                    : cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedScale(
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        scale: isSelected ? 1.0 : 0.0,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerLowest,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            color: cs.error,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isConfirming
                      ? null
                      : () => Navigator.of(context).pop(null),
                  child: const Text(AppStrings.cancel),
                ),
                AnimatedBuilder(
                  animation: _shakeController,
                  builder: (context, child) {
                    final offset =
                        math.sin(_shakeController.value * math.pi * 4) * 5;
                    return Transform.translate(
                      offset: Offset(offset, 0),
                      child: child,
                    );
                  },
                  child: ElevatedButton.icon(
                    onPressed: _selectedPlayer == null || _isConfirming
                        ? null
                        : _startCountdown,
                    icon: _isConfirming
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onError,
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(_isConfirming ? 'Confirming...' : 'Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPlayer != null
                          ? cs.error
                          : null,
                      foregroundColor: _selectedPlayer != null
                          ? cs.onError
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Countdown overlay
        if (_showCountdown)
          Positioned.fill(
            child: Container(
              color: cs.scrim.withValues(alpha: 0.65),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(_countdownValue),
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: 0.5 + (value * 0.5),
                      child: Opacity(
                        opacity: value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.surfaceContainerLowest,
                            boxShadow: [
                              BoxShadow(
                                color: cs.error.withValues(
                                  alpha: 0.45,
                                ),
                                blurRadius: 30,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              '$_countdownValue',
                              style: TextStyle(
                                fontSize: 72,
                                fontWeight: FontWeight.bold,
                                color: cs.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
