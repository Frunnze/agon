void requireRuleTitle(String title) {
  if (title.trim().isEmpty) {
    throw ArgumentError.value(title, 'title', 'Write the rule');
  }
}
