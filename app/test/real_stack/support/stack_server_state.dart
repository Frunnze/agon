import 'dart:convert';
import 'dart:io';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import 'real_stack.dart';

const String _stateFileName = 'state.json';

String readServerStateText(RealStack stack) {
  final String statePath =
      '${stack.server.dataDirectory.path}/$_stateFileName';
  return File(statePath).readAsStringSync();
}

List<String> listServerTaskTitles(RealStack stack) {
  final JsonObject state = decodeObject(
    jsonDecode(readServerStateText(stack)),
  );
  final JsonObject tasks = decodeObject(state['tasks']);
  return <String>[
    for (final Object? task in tasks.values)
      decodeObject(task)['title']! as String,
  ];
}
