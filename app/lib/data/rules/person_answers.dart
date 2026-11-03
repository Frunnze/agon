const List<String> _approvalWords = <String>['approve', 'approved'];
const String _unmatchedAnswerStart = 'the answer names none of the choices: ';
const String _choiceSeparator = ', ';

String? matchChoice(String answer, List<String> choices) {
  final String normalizedAnswer = answer.trim().toLowerCase();
  for (final String choice in choices) {
    if (choice.toLowerCase() == normalizedAnswer) {
      return choice;
    }
  }

  if (!_approvalWords.contains(normalizedAnswer)) {
    return null;
  }
  for (final String choice in choices) {
    if (_approvalWords.contains(choice)) {
      return choice;
    }
  }
  return null;
}

String describeUnmatchedAnswer(List<String> choices) {
  return '$_unmatchedAnswerStart${choices.join(_choiceSeparator)}';
}
