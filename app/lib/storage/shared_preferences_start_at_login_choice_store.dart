import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_orchestration/background/start_at_login_choice_store.dart';

const String _startAtLoginChosenKey = 'is_start_at_login_chosen';
const bool _isStartAtLoginChosenBeforeAnyChoice = true;

final class SharedPreferencesStartAtLoginChoiceStore
    implements StartAtLoginChoiceStore {
  const SharedPreferencesStartAtLoginChoiceStore();

  @override
  Future<bool> readIsStartAtLoginChosen() async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    final bool? storedChoice = preferences.getBool(_startAtLoginChosenKey);
    return storedChoice ?? _isStartAtLoginChosenBeforeAnyChoice;
  }

  @override
  Future<void> saveIsStartAtLoginChosen({required bool isChosen}) async {
    final SharedPreferences preferences =
        await SharedPreferences.getInstance();
    await preferences.setBool(_startAtLoginChosenKey, isChosen);
  }
}
