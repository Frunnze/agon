import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_library_action_repositories.dart';

const String _saveSkillLabel = 'Save skill';
const SectionRoute _skillsRoute = SectionRoute(AppSection.skills);

RefusedActionCase _buildSaveSkillCase() {
  late AppNavigation navigation;

  return RefusedActionCase(
    functionName: 'skill_form_submit',
    actionLabel: _saveSkillLabel,
    place: RefusalPlace.bannerOnPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      navigation = await pumpApp(
        tester,
        size: size,
        route: _skillsRoute,
        dependencies: replaceRepositories(
          gallery,
          skillRepository: RefusingSkillRepository(
            stored: gallery.skillRepository,
            refusal: refusal,
          ),
        ),
      );
      navigation.openRoute(const EditSkillRoute(GallerySkillIds.codeReview));
      await pumpFrames(tester);
    },
    performAction: (tester) => tapButtonLabelled(tester, _saveSkillLabel),
    expectSucceeded: (tester) {
      expect(navigation.routes, const <AppRoute>[_skillsRoute]);
    },
  );
}

void main() {
  registerRefusedActionProperties(_buildSaveSkillCase(), seed: 92001);
}
