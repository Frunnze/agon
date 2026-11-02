final class FetchSequence {
  int _latestStarted = 0;
  int _newestAccepted = 0;

  int startFetch() {
    _latestStarted += 1;
    return _latestStarted;
  }

  void recordLocalChange() {
    _newestAccepted = startFetch();
  }

  bool acceptIfNewest(int fetch) {
    if (fetch <= _newestAccepted) {
      return false;
    }
    _newestAccepted = fetch;
    return true;
  }
}
