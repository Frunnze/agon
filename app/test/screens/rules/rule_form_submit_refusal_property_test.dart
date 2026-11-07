import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_library_action_repositories.dart';

const String _saveRuleLabel = 'Save rule';
const SectionRoute _rulesRoute = SectionRoute(AppSection.rules);

RefusedActionCase _buildSaveRuleCase() {
  final RuleId editedRuleId = galleryRules.first.id;
  late AppNavigation navigation;

  return RefusedActionCase(
    functionName: 'rule_form_submit',
    actionLabel: _saveRuleLabel,
    place: RefusalPlace.bannerOnPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      navigation = await pumpApp(
        tester,
        size: size,
        route: _rulesRoute,
        dependencies: replaceRepositories(
          gallery,
          ruleRepository: RefusingRuleRepository(
            stored: gallery.ruleRepository,
            refusal: refusal,
          ),
        ),
      );
      navigation.openRoute(EditRuleRoute(editedRuleId));
      await pumpFrames(tester);
    },
    performAction: (tester) => tapButtonLabelled(tester, _saveRuleLabel),
    expectSucceeded: (tester) {
      expect(navigation.routes, const <AppRoute>[_rulesRoute]);
    },
  );
}

void main() {
  registerRefusedActionProperties(_buildSaveRuleCase(), seed: 91901);
}
