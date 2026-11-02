import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

final class MissingFolderRunner {
  const MissingFolderRunner({
    required this.deviceName,
    required this.folderName,
    required this.projectName,
  });

  final String deviceName;
  final String folderName;
  final String projectName;
}

MissingFolderRunner? findMissingFolderRunner({
  required Project project,
  required List<Runner> runners,
  required DeviceNames deviceNames,
}) {
  final LocalFolderAddress? folder = findLocalFolder(project.repositories);
  if (folder == null) {
    return null;
  }
  for (final Runner runner in runners) {
    if (runner.deviceId == folder.deviceId) {
      return null;
    }
  }
  return MissingFolderRunner(
    deviceName: deviceNames.describeDevice(folder.deviceId),
    folderName: describeFolderName(folder.path),
    projectName: project.name,
  );
}

class FolderRunnerNotice extends StatelessWidget {
  const FolderRunnerNotice({required this.missing, super.key});

  final MissingFolderRunner missing;

  @override
  Widget build(BuildContext context) {
    final String deviceName = missing.deviceName;

    return NoticeBanner(
      tone: BannerTone.attention,
      icon: AppIconKind.offline,
      title: '$deviceName has no runner',
      body: <Widget>[
        Text(
          '${missing.folderName} is a folder on $deviceName, so only '
          '$deviceName can work on ${missing.projectName}. The task waits '
          'until it runs tasks.',
        ),
      ],
    );
  }
}
