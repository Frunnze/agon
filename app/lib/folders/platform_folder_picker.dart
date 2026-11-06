import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/folders/new_projects_folder.dart';

const String _confirmButtonText = 'Choose';

final class PlatformFolderPicker implements FolderPicker {
  const PlatformFolderPicker();

  @override
  Future<String?> chooseFolder() {
    return getDirectoryPath(confirmButtonText: _confirmButtonText);
  }

  @override
  Future<String> prepareNewProjectsFolder() {
    return makeNewProjectsFolder(Platform.environment);
  }
}
