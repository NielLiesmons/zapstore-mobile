import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that updates current time every 10 seconds for reactive time displays
final currentTimeProvider =
    StateNotifierProvider<CurrentTimeNotifier, DateTime>((ref) {
      return CurrentTimeNotifier();
    });

class CurrentTimeNotifier extends StateNotifier<DateTime> {
  late final Timer _timer;

  CurrentTimeNotifier() : super(DateTime.now()) {
    // Update every 10 seconds to keep "time ago" displays fresh
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      state = DateTime.now();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

class TimeUtils {
  /// Formats a timestamp for compact UI labels:
  ///   < 60s        → "Just Now"
  ///   same day     → "14:23"
  ///   older        → "Jan 21"
  static String formatTimestamp(DateTime timestamp) {
    return formatTimestampRelativeTo(timestamp, DateTime.now());
  }

  /// Same logic as [formatTimestamp] but against an explicit [currentTime]
  /// (useful for tests and reactive displays driven by [currentTimeProvider]).
  static String formatTimestampRelativeTo(
    DateTime timestamp,
    DateTime currentTime,
  ) {
    final diff = currentTime.difference(timestamp);
    if (diff.inSeconds < 60) return 'Just Now';

    final isToday = timestamp.year == currentTime.year &&
        timestamp.month == currentTime.month &&
        timestamp.day == currentTime.day;
    if (isToday) {
      final h = timestamp.hour.toString().padLeft(2, '0');
      final m = timestamp.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}';
  }
}

/// A reactive text widget that automatically updates time-relative displays
class TimeAgoText extends ConsumerWidget {
  final DateTime timestamp;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TimeAgoText(
    this.timestamp, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current time provider to automatically rebuild when time changes
    final currentTime = ref.watch(currentTimeProvider);

    return Text(
      TimeUtils.formatTimestampRelativeTo(timestamp, currentTime),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
