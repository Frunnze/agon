import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

final TextStyle _titleStyle = AppTextStyles.heading.copyWith(
  height: AppLineHeights.body,
);

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    required this.action,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final Widget? shownAction = action;

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.measure),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.space7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(header: true, child: Text(title, style: _titleStyle)),
              const SizedBox(height: AppSpacing.space3),
              Text(message),
              if (shownAction != null) ...<Widget>[
                const SizedBox(height: AppSpacing.space3),
                shownAction,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
