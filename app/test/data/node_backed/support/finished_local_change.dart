import 'package:agent_orchestration/data/node_backed.dart';

Future<void> _reloadNothing() async {}

void finishLocalChangeAtOnce(FetchSequence fetches) {
  final int change = fetches.startLocalChange();
  fetches.finishLocalChange(change, reloadWhenOvertaken: _reloadNothing);
}
