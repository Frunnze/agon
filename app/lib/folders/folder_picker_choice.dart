import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/folders/platform_folder_picker.dart';
import 'package:agent_orchestration/folders/runner_folder_picker.dart';

FolderPicker buildPlatformFolderPicker(TargetPlatform platform) {
  if (platform == TargetPlatform.macOS) {
    return const RunnerFolderPicker();
  }
  return const PlatformFolderPicker();
}
