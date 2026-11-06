import 'dart:io';

import 'package:flutter/services.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/folders/new_projects_folder.dart';

const MethodChannel folderChannel = MethodChannel(
  'agent_orchestration/folders',
);
const String chooseFolderMethod = 'chooseFolder';

final class RunnerFolderPicker implements FolderPicker {
  const RunnerFolderPicker();

  @override
  Future<String?> chooseFolder() {
    return folderChannel.invokeMethod<String>(chooseFolderMethod);
  }

  @override
  Future<String> prepareNewProjectsFolder() {
    return makeNewProjectsFolder(Platform.environment);
  }
}
