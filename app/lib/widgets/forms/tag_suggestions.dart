import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const double _suggestionListMaximumWidth = 280;
const double _suggestionListMaximumHeight = 240;

List<String> findTagSuggestions({
  required List<String> suggestions,
  required List<String> chosenTags,
  required String typedText,
}) {
  final String typed = typedText.trim().toLowerCase();
  final List<String> matches = <String>[];

  for (final String suggestion in suggestions) {
    final bool isChosen = chosenTags.contains(suggestion);
    final bool isMatch = suggestion.toLowerCase().contains(typed);
    if (!isChosen && isMatch) {
      matches.add(suggestion);
    }
  }

  return matches;
}

String? matchTagSuggestion({
  required List<String> suggestions,
  required List<String> chosenTags,
  required String typedText,
}) {
  final String typed = typedText.trim().toLowerCase();

  for (final String suggestion in suggestions) {
    final bool isChosen = chosenTags.contains(suggestion);
    if (!isChosen && suggestion.toLowerCase() == typed) {
      return suggestion;
    }
  }
  return null;
}

class TagSuggestionList extends StatelessWidget {
  const TagSuggestionList({
    required this.options,
    required this.onSelected,
    super.key,
  });

  final Iterable<String> options;
  final AutocompleteOnSelected<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        margin: const EdgeInsets.only(top: AppSpacing.space1),
        padding: const EdgeInsets.all(AppSpacing.space1),
        constraints: const BoxConstraints(
          maxWidth: _suggestionListMaximumWidth,
          maxHeight: _suggestionListMaximumHeight,
        ),
        decoration: BoxDecoration(
          color: AppColors.raised,
          border: Border.all(color: AppColors.lineStrong),
          borderRadius: BorderRadius.circular(AppRadii.panel),
        ),
        child: Material(
          color: AppColors.transparent,
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: <Widget>[
              for (final String option in options)
                InkWell(
                  onTap: () => onSelected(option),
                  mouseCursor: WidgetStateMouseCursor.clickable,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.space3,
                      vertical: AppSpacing.space2,
                    ),
                    child: Text(
                      option,
                      style: AppTextStyles.body.merge(AppTextStyles.monospace),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
