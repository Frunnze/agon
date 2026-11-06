import 'package:agent_orchestration/data/folder_picker.dart';

const String fixedNewProjectsFolder = '/fixed-home/Agon';

final class FixedFolderPicker implements FolderPicker {
  FixedFolderPicker(this.chosenPath);

  String? chosenPath;
  int chooseCount = 0;
  int prepareCount = 0;

  @override
  Future<String?> chooseFolder() async {
    chooseCount += 1;
    return chosenPath;
  }

  @override
  Future<String> prepareNewProjectsFolder() async {
    prepareCount += 1;
    return fixedNewProjectsFolder;
  }
}
