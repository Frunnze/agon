import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

class RepositoryEntryField extends StatelessWidget {
  const RepositoryEntryField({
    required this.controller,
    required this.problem,
    required this.placeholder,
    required this.onChanged,
    required this.onAdded,
    super.key,
  });

  final TextEditingController controller;
  final String? problem;
  final String placeholder;
  final ValueChanged<String> onChanged;
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            autocorrect: false,
            keyboardType: TextInputType.url,
            style: AppTextStyles.body.merge(AppTextStyles.monospace),
            onChanged: onChanged,
            onSubmitted: (String _) => onAdded(),
            decoration: InputDecoration(
              hintText: placeholder,
              errorText: problem,
              errorMaxLines: 2,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        SizedBox(
          height: AppSizes.controlHeight,
          child: AppButton.secondary(label: 'Add repo', onPressed: onAdded),
        ),
      ],
    );
  }
}
