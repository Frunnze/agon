import 'package:flutter/material.dart';

import 'package:agent_orchestration/presentation/problem_text.dart';

final class ProblemMessenger {
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool showProblem(Object problem, StackTrace stackTrace) {
    final String? text = describeProblemForPeople(problem);
    final ScaffoldMessengerState? messenger = messengerKey.currentState;
    if (text == null || messenger == null) {
      return false;
    }

    messenger.showSnackBar(SnackBar(content: Text(text)));
    return true;
  }
}
