import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String noneChosenText = 'None';
const String notChosenText = 'Not chosen';

abstract interface class DraftReview {
  List<Fact> describeFacts(DraftedItem item);

  Future<void> approve(DraftedItem item);
}

Fact describeTextFact(String term, String text) {
  return Fact(term: term, description: <TextSegment>[TextSegment(text)]);
}

Fact describeMutedFact(String term, String text) {
  return Fact.content(term: term, content: MutedNote(text));
}

Fact describeOptionalTextFact(String term, String text) {
  if (text.trim().isEmpty) {
    return describeMutedFact(term, noneChosenText);
  }
  return describeTextFact(term, text);
}
