import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/shell/app_section.dart';

AppSection findDraftKindSection(DraftKind kind) {
  return switch (kind) {
    DraftKind.task => AppSection.tasks,
    DraftKind.job => AppSection.jobs,
    DraftKind.skill => AppSection.skills,
    DraftKind.rule => AppSection.rules,
  };
}
