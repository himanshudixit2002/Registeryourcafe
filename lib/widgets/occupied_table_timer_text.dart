import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class OccupiedTableTimerText extends StatefulWidget {
  final DateTime startTime;
  final TextStyle? style;

  /// Whether the session is currently paused.
  final bool isPaused;

  /// When the session was paused. Used to calculate frozen time.
  final DateTime? pausedAt;

  /// Total accumulated paused time in seconds.
  final int totalPausedSeconds;

  /// Whether the session is currently on a 5-minute break.
  final bool isOnBreak;

  /// When the current break started.
  final DateTime? breakStartedAt;

  const OccupiedTableTimerText({
    super.key,
    required this.startTime,
    this.style,
    this.isPaused = false,
    this.pausedAt,
    this.totalPausedSeconds = 0,
    this.isOnBreak = false,
    this.breakStartedAt,
  });

  @override
  State<OccupiedTableTimerText> createState() => _OccupiedTableTimerTextState();
}

class _OccupiedTableTimerTextState extends State<OccupiedTableTimerText> {
  Timer? _timer;
  late Duration _duration;

  @override
  void initState() {
    super.initState();
    _calculateDuration();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(OccupiedTableTimerText oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isPaused != widget.isPaused ||
        oldWidget.pausedAt != widget.pausedAt ||
        oldWidget.totalPausedSeconds != widget.totalPausedSeconds ||
        oldWidget.startTime != widget.startTime ||
        oldWidget.isOnBreak != widget.isOnBreak ||
        oldWidget.breakStartedAt != widget.breakStartedAt) {
      _calculateDuration();
      _startTimerIfNeeded();
    }
  }

  void _calculateDuration() {
    final DateTime effectiveEndTime;

    if (widget.isPaused && widget.pausedAt != null) {
      // Session is paused - freeze at pause time
      effectiveEndTime = widget.pausedAt!;
    } else {
      // Session is active
      effectiveEndTime = DateTime.now();
    }

    final rawDuration = effectiveEndTime.difference(widget.startTime);
    final pausedDuration = Duration(seconds: widget.totalPausedSeconds);

    // Subtract paused time from raw duration
    final actualDuration = rawDuration - pausedDuration;

    _duration = actualDuration.isNegative ? Duration.zero : actualDuration;
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();

    // Tick when session is active OR on break (for the countdown display)
    if (!widget.isPaused || widget.isOnBreak) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _calculateDuration();
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatBreakCountdown() {
    if (widget.breakStartedAt == null) return '5:00';
    const breakDuration = Duration(minutes: 5);
    final elapsed = DateTime.now().difference(widget.breakStartedAt!);
    final remaining = breakDuration - elapsed;
    if (remaining.isNegative) return '0:00';
    final m = remaining.inMinutes;
    final s = remaining.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final sem = AppSemanticColors.of(context);

    if (widget.isOnBreak) {
      final breakColor = sem.info;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatDuration(_duration),
            style:
                widget.style?.copyWith(color: breakColor) ??
                TextStyle(color: breakColor),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.coffee_rounded,
                size: (widget.style?.fontSize ?? 16) * 0.8,
                color: breakColor,
              ),
              const SizedBox(width: 3),
              Text(
                _formatBreakCountdown(),
                style: TextStyle(
                  fontSize: (widget.style?.fontSize ?? 16) * 0.7,
                  fontWeight: FontWeight.w600,
                  color: breakColor,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (widget.isPaused) {
      final pauseColor = sem.warning;
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pause_circle_filled,
            size: (widget.style?.fontSize ?? 16) * 1.2,
            color: pauseColor,
          ),
          const SizedBox(width: 4),
          Text(
            _formatDuration(_duration),
            style:
                widget.style?.copyWith(color: pauseColor) ??
                TextStyle(color: pauseColor),
          ),
        ],
      );
    }

    return Text(_formatDuration(_duration), style: widget.style);
  }
}
