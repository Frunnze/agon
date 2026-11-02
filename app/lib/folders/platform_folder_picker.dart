import 'package:file_selector/file_selector.dart';

import 'package:agent_orchestration/data/folder_picker.dart';

const String _confirmButtonText = 'Choose';

final class PlatformFolderPicker implements FolderPicker {
  const PlatformFolderPicker();

  @override
  Future<String?> chooseFolder() {
    return getDirectoryPath(confirmButtonText: _confirmButtonText);
  }
}
