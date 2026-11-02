import 'package:flutter/material.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';
import 'package:agent_orchestration/widgets/forms/tag_suggestions.dart';

class TagInputField extends StatefulWidget {
  const TagInputField({
    required this.tags,
    required this.suggestions,
    required this.placeholder,
    required this.onTagAdded,
    required this.onTagRemoved,
    super.key,
  });

  final List<String> tags;
  final List<String> suggestions;
  final String placeholder;
  final ValueChanged<String> onTagAdded;
  final ValueChanged<String> onTagRemoved;

  @override
  State<TagInputField> createState() => _TagInputFieldState();
}

class _TagInputFieldState extends State<TagInputField> {
  final TextEditingController _entryController = TextEditingController();
  final FocusNode _entryFocus = FocusNode();
  bool _isFocused = false;

  @override
  void dispose() {
    _entryController.dispose();
    _entryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _handleFocusChange,
      skipTraversal: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: AppSizes.controlHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.space2,
          vertical: AppSpacing.space1,
        ),
        decoration: BoxDecoration(
          color: AppColors.raised,
          border: Border.all(
            color: _isFocused ? AppColors.action : AppColors.lineStrong,
            width: _isFocused ? AppBorders.selected : AppBorders.thin,
          ),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Wrap(
          spacing: AppSpacing.space2,
          runSpacing: AppSpacing.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final String tag in widget.tags)
              RemovableTag(label: tag, onRemoved: widget.onTagRemoved),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: AppSizes.tagInputFieldMinimumWidth,
              ),
              child: IntrinsicWidth(
                child: RawAutocomplete<String>(
                  textEditingController: _entryController,
                  focusNode: _entryFocus,
                  optionsBuilder: _findMatchingSuggestions,
                  onSelected: _addTag,
                  fieldViewBuilder: _buildEntryField,
                  optionsViewBuilder: _buildSuggestionList,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() => _isFocused = hasFocus);
  }

  Iterable<String> _findMatchingSuggestions(TextEditingValue entry) {
    return findTagSuggestions(
      suggestions: widget.suggestions,
      chosenTags: widget.tags,
      typedText: entry.text,
    );
  }

  void _addTag(String tag) {
    widget.onTagAdded(tag);
    _entryController.clear();
  }

  void _submitTypedText(String typedText) {
    final String? match = matchTagSuggestion(
      suggestions: widget.suggestions,
      chosenTags: widget.tags,
      typedText: typedText,
    );
    if (match != null) {
      _addTag(match);
    }
  }

  Widget _buildEntryField(
    BuildContext context,
    TextEditingController controller,
    FocusNode focusNode,
    VoidCallback onFieldSubmitted,
  ) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onSubmitted: _submitTypedText,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: widget.placeholder,
        filled: false,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: AppSpacing.space1,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
    );
  }

  Widget _buildSuggestionList(
    BuildContext context,
    AutocompleteOnSelected<String> onSelected,
    Iterable<String> options,
  ) {
    return TagSuggestionList(options: options, onSelected: onSelected);
  }
}
