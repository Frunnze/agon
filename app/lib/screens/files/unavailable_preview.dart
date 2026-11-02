import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_frames.dart';
import 'package:agent_orchestration/screens/files/file_text.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const String unavailablePreviewTitle = "Can't preview this file";

class UnavailablePreview extends StatelessWidget {
  const UnavailablePreview({
    required this.fileName,
    required this.reason,
    required this.repositoryPath,
    super.key,
  });

  final String fileName;
  final PreviewUnavailableReason reason;
  final String repositoryPath;

  @override
  Widget build(BuildContext context) {
    return FileFrame(
      child: EmptySection(
        title: unavailablePreviewTitle,
        children: <Widget>[
          Text(describeUnavailablePreview(fileName: fileName, reason: reason)),
          Text(
            describeOwnCloneHint(repositoryPath),
            style: AppTextStyles.body.copyWith(color: AppColors.inkMuted),
          ),
        ],
      ),
    );
  }
}
