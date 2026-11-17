import 'package:intl/intl.dart';

/// Formats a timestamp into a detailed, smart relative time string:
/// - Under 45 seconds: "just now"
/// - Minutes: "${m}m ago"
/// - Hours: "${h}h ${m}m ago" (or "${h}h ago" if m == 0)
/// - Days: "${d}d ${h}h ago" (or "${d}d ago" if h == 0)
/// - Months: "${mo}mo ${d}d ago" (or "${mo}mo ago" if d == 0)
/// - Years: "${y}y ${mo}mo ago" (or "${y}y ago" if mo == 0)
String relativeTime(int millis) {
  if (millis <= 0) return 'never';
  final now = DateTime.now();
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final diff = now.difference(dt);

  if (diff.isNegative || diff.inSeconds < 45) {
    return 'just now';
  }

  final minutes = diff.inMinutes;
  if (minutes < 60) {
    return '${minutes}m ago';
  }

  final hours = diff.inHours;
  if (hours < 24) {
    final remMinutes = minutes % 60;
    if (remMinutes > 0) {
      return '${hours}h ${remMinutes}m ago';
    }
    return '${hours}h ago';
  }

  final days = diff.inDays;
  if (days < 30) {
    final remHours = hours % 24;
    if (remHours > 0) {
      return '${days}d ${remHours}h ago';
    }
    return '${days}d ago';
  }

  // Calculate calendar months and remaining days
  int months = (now.year - dt.year) * 12 + (now.month - dt.month);
  if (now.day < dt.day) {
    months--;
  }
  if (months < 1) months = days ~/ 30;
  if (months < 1) months = 1;

  if (months < 12) {
    final approxDays = days - (months * 30);
    final remDays = approxDays > 0 ? approxDays : 0;
    if (remDays > 0 && remDays < 30) {
      return '${months}mo ${remDays}d ago';
    }
    return '${months}mo ago';
  }

  final years = months ~/ 12;
  final remMonths = months % 12;
  if (remMonths > 0) {
    return '${years}y ${remMonths}mo ago';
  }
  return '${years}y ago';
}

String absoluteTime(int millis) {
  if (millis <= 0) return '—';
  final dt = DateTime.fromMillisecondsSinceEpoch(millis);
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return 'Today ${DateFormat.Hm().format(dt)}';
  }
  return DateFormat('MMM d, HH:mm').format(dt);
}
