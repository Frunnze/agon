import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

class FingerprintWords extends StatelessWidget {
  const FingerprintWords({required this.words, super.key});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Words in order: ${words.join(', ')}',
      excludeSemantics: true,
      child: Wrap(
        spacing: AppSpacing.space2,
        runSpacing: AppSpacing.space2,
        children: <Widget>[
          for (final String word in words)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.space3,
                vertical: AppSpacing.space2,
              ),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.ink,
                  width: AppBorders.selected,
                ),
                borderRadius: BorderRadius.circular(AppRadii.control),
              ),
              child: Text(
                word,
                style: AppTextStyles.heading.merge(AppTextStyles.monospace),
              ),
            ),
        ],
      ),
    );
  }
}
