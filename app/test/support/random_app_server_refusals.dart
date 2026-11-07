import 'dart:math';

import '../bridge/support/hostile_texts.dart';

const String appServerRefusalPrefix = 'the app server answered';
const int _lowestStatus = 100;
const int _statusSpan = 900;

typedef RandomRefusal = ({int status, String reason, String nodeMessage});

String renderRefusalMessage({required int status, required String reason}) {
  return '$appServerRefusalPrefix $status: $reason';
}

String randomRefusalReason(Random random) {
  return '${randomHostileText(random)}reason ${randomHostileText(random)}';
}

RandomRefusal randomRefusalWithReason(Random random, String reason) {
  final int status = _lowestStatus + random.nextInt(_statusSpan);
  return (
    status: status,
    reason: reason,
    nodeMessage: renderRefusalMessage(status: status, reason: reason),
  );
}

RandomRefusal randomRefusal(Random random) {
  return randomRefusalWithReason(random, randomRefusalReason(random));
}
