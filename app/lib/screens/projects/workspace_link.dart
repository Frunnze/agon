import 'package:flutter/material.dart';

import 'package:agent_orchestration/icons/app_icon.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/quiet_link_style.dart';

class WorkspaceLinkButton extends StatelessWidget {
  const WorkspaceLinkButton({
    required this.workspaceName,
    required this.onPressed,
    super.key,
  });

  final String workspaceName;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        style: buildQuietLinkStyle(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Flexible(child: Text('$workspaceName workspace')),
            const SizedBox(width: AppSpacing.space1),
            const AppIcon(AppIconKind.chevronDown, size: AppIconSize.small),
          ],
        ),
      ),
    );
  }
}
