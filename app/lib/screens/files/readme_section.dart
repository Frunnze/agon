import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/file_content_view.dart';
import 'package:agent_orchestration/screens/files/file_sizes.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

class ReadmeSection extends StatelessWidget {
  const ReadmeSection({
    required this.readme,
    required this.repositoryPath,
    super.key,
  });

  final RepositoryFile readme;
  final String repositoryPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.space4,
          runSpacing: AppSpacing.space2,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                readme.path,
                style: AppTextStyles.bodyBold.merge(AppTextStyles.monospace),
              ),
            ),
            Text(
              describeFileSize(readme.size),
              style: AppTextStyles.bodyMuted,
            ),
          ],
        ),
        FileContentView(file: readme, repositoryPath: repositoryPath),
      ], AppSpacing.space3),
    );
  }
}
