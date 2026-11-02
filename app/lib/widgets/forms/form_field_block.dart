import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

class FormFieldBlock extends StatelessWidget {
  const FormFieldBlock({
    required this.label,
    required this.children,
    super.key,
    this.hint,
  });

  final String label;
  final List<Widget> children;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final String? hintText = hint;

    return Semantics(
      label: label,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaceVertically(<Widget>[
          Text(label, style: AppTextStyles.bodyBold),
          ...children,
          if (hintText != null)
            Text(hintText, style: AppTextStyles.smallMuted),
        ], AppSpacing.space2),
      ),
    );
  }
}

class FormColumn extends StatelessWidget {
  const FormColumn({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.measure),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spaceVertically(children, AppSpacing.space5),
        ),
      ),
    );
  }
}
