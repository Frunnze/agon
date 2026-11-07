import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

void requireRuleTitle(String title) {
  if (trimUnicodeWhiteSpace(title).isEmpty) {
    throw ArgumentError.value(title, 'title', 'Write the rule');
  }
}
