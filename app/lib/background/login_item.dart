const String startAtLoginProblem =
    'could not make this computer start the app at login';
const String stopStartingAtLoginProblem =
    'could not stop this computer starting the app at login';

abstract interface class LoginItem {
  Future<void> register();

  Future<void> unregister();
}
