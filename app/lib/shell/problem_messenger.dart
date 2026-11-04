import 'package:flutter/material.dart';

import 'package:agent_orchestration/presentation/problem_text.dart';

typedef MessengerKey = GlobalKey<ScaffoldMessengerState>;

final class ProblemMessenger {
  List<MessengerKey> _messengerKeys = const <MessengerKey>[];

  MessengerKey addMessengerKey() {
    final MessengerKey messengerKey = MessengerKey();
    _messengerKeys = List<MessengerKey>.unmodifiable(<MessengerKey>[
      ..._messengerKeys,
      messengerKey,
    ]);
    return messengerKey;
  }

  void removeMessengerKey(MessengerKey removedKey) {
    _messengerKeys = List<MessengerKey>.unmodifiable(<MessengerKey>[
      for (final MessengerKey messengerKey in _messengerKeys)
        if (messengerKey != removedKey) messengerKey,
    ]);
  }

  bool showProblem(Object problem, StackTrace stackTrace) {
    final String? text = describeProblemForPeople(problem);
    if (text == null) {
      return false;
    }

    bool isShown = false;
    for (final MessengerKey messengerKey in _messengerKeys) {
      final ScaffoldMessengerState? messenger = messengerKey.currentState;
      if (messenger != null) {
        messenger.showSnackBar(SnackBar(content: Text(text)));
        isShown = true;
      }
    }
    return isShown;
  }
}
