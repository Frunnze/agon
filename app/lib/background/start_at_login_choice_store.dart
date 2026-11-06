abstract interface class StartAtLoginChoiceStore {
  Future<bool> readIsStartAtLoginChosen();

  Future<void> saveIsStartAtLoginChosen({required bool isChosen});
}
