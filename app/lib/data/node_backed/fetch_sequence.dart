import 'package:agent_orchestration/data/node_backed/background_node_work.dart';

final class FetchSequence {
  int _latestStarted = 0;
  int _latestFetch = 0;
  int _newestAccepted = 0;

  int startFetch() {
    _latestStarted += 1;
    _latestFetch = _latestStarted;
    return _latestFetch;
  }

  int startLocalChange() {
    _latestStarted += 1;
    return _latestStarted;
  }

  void finishLocalChange(
    int change, {
    required BackgroundNodeWork reloadWhenOvertaken,
  }) {
    final bool isOvertaken = change < _newestAccepted;

    _latestStarted += 1;
    _newestAccepted = _latestStarted;

    if (isOvertaken) {
      startBackgroundNodeWork(reloadWhenOvertaken);
    }
  }

  bool acceptIfNewest(int fetch) {
    if (fetch <= _newestAccepted) {
      return false;
    }
    _newestAccepted = fetch;
    return true;
  }

  bool isLatestFetch(int fetch) => fetch == _latestFetch;
}
