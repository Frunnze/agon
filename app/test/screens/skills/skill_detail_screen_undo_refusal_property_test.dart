import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/repository/skill_repository.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_library_action_repositories.dart';

const String _undoLabel = 'Undo';

RefusedActionCase _buildUndoCase() {
  late SkillRepository skillRepository;
  late int historyLengthBeforeUndo;

  return RefusedActionCase(
    functionName: 'undo_latest_agent_change',
    actionLabel: _undoLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      skillRepository = RefusingSkillRepository(
        stored: gallery.skillRepository,
        refusal: refusal,
      );
      await pumpApp(
        tester,
        size: size,
        route: const SkillDetailRoute(GallerySkillIds.iosRelease),
        dependencies: replaceRepositories(
          gallery,
          skillRepository: skillRepository,
        ),
      );
      historyLengthBeforeUndo = _readHistoryLength(skillRepository);
    },
    performAction: (tester) => tapButtonLabelled(tester, _undoLabel),
    expectSucceeded: (tester) {
      final int historyLength = _readHistoryLength(skillRepository);
      expect(historyLength, historyLengthBeforeUndo - 1);
    },
  );
}

int _readHistoryLength(SkillRepository skillRepository) {
  return skillRepository.findSkill(GallerySkillIds.iosRelease).history.length;
}

void main() {
  registerRefusedActionProperties(_buildUndoCase(), seed: 91701);
}
