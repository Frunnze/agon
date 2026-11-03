import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';

const String _chooseFolderLabel = 'Choose folder…';
const String _startedGitPlace =
    'on air-laptop · main · Started git in this folder';
const String _folderParent = '/Users/someone/work';
const List<String> _gitlessFolderNames = <String>['notes', 'drafts'];
const List<String> _gitFolderNames = <String>['billing-ui', 'app'];

Future<FixedFolderPicker> _openNewProject(WidgetTester tester) async {
  final FixedFolderPicker picker = FixedFolderPicker(null);
  await tester.pumpWidget(const SizedBox.shrink());
  await openNewItem(
    tester,
    route: const NewProjectRoute(),
    dependencies: replaceRepositories(
      buildNewItemDependencies(ScriptedItemDraftRepository()),
      deviceRepository: FakeDeviceRepository(
        devices: galleryDevices,
        currentDeviceId: GalleryDeviceIds.airLaptop,
        peerAddressProblem: null,
        gitlessFolderPaths: <String>{
          for (final String name in _gitlessFolderNames)
            '$_folderParent/$name',
        },
      ),
      folderPicker: picker,
    ),
  );
  return picker;
}

Future<void> _chooseFolder(
  WidgetTester tester,
  FixedFolderPicker picker,
  String name,
) async {
  picker.chosenPath = '$_folderParent/$name';
  await tapVisible(tester, find.text(_chooseFolderLabel));
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_chosen_folder_field_property_notes_where_git_started', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FixedFolderPicker picker = await _openNewProject(tester);
      final List<String> names = <String>[
        ..._gitlessFolderNames,
        ..._gitFolderNames,
      ]..shuffle(random);

      for (final String name in names) {
        await _chooseFolder(tester, picker, name);
      }

      expect(
        find.text(_startedGitPlace),
        findsNWidgets(_gitlessFolderNames.length),
      );
      expect(
        find.text('on air-laptop · main'),
        findsNWidgets(_gitFolderNames.length),
      );
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
