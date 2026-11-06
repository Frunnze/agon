abstract interface class FolderPicker {
  Future<String?> chooseFolder();

  Future<String> prepareNewProjectsFolder();
}
