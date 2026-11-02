import 'package:agent_orchestration/presentation/time_phrases.dart';

const int _digitGroupSize = 3;
const String _digitGroupSeparator = ',';

String describeAuditTime(DateTime at, DateTime now) {
  final bool isSameDay = countCalendarDaysBetween(at, now) == 0;

  if (isSameDay) {
    return formatClockTime(at);
  }
  return describeTimeSince(at, now);
}

String _groupDigits(int count) {
  final String digits = count.toString();
  final StringBuffer grouped = StringBuffer();

  for (int index = 0; index < digits.length; index += 1) {
    final int digitsLeft = digits.length - index;
    final bool startsGroup = index > 0 && digitsLeft % _digitGroupSize == 0;
    if (startsGroup) {
      grouped.write(_digitGroupSeparator);
    }
    grouped.write(digits[index]);
  }

  return grouped.toString();
}

String describeEntryCount(int count) {
  if (count < 0) {
    throw ArgumentError.value(count, 'count', 'Counts cannot be negative');
  }

  final String noun = count == 1 ? 'entry' : 'entries';
  return '${_groupDigits(count)} $noun';
}
