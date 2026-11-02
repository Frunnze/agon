import 'package:agent_orchestration/data/folder_picker.dart';

final class FixedFolderPicker implements FolderPicker {
  FixedFolderPicker(this.chosenPath);

  String? chosenPath;
  int chooseCount = 0;

  @override
  Future<String?> chooseFolder() async {
    chooseCount += 1;
    return chosenPath;
  }
}
