import 'package:agent_orchestration/background/start_at_login_choice_store.dart';

final class MemoryStartAtLoginChoiceStore implements StartAtLoginChoiceStore {
  MemoryStartAtLoginChoiceStore({required this.isStartAtLoginChosen});

  bool isStartAtLoginChosen;

  @override
  Future<bool> readIsStartAtLoginChosen() async => isStartAtLoginChosen;

  @override
  Future<void> saveIsStartAtLoginChosen({required bool isChosen}) async {
    isStartAtLoginChosen = isChosen;
  }
}
