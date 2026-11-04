import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';

const String _chooseFolderLabel = 'Choose folder…';
const String _removeLabel = 'Remove';
const String _folderPlace = 'on air-laptop · main';
const String _draftProjectLabel = 'Draft project';
const String _alreadyAddedProblem = 'This repo is already added';
const String _folderParent = '/Users/someone/work';
const List<String> _folderNames = <String>[
  'billing-ui',
  'app',
  'site_2',
  'docs',
];

Future<ScriptedItemDraftRepository> _openNewItem(
  WidgetTester tester, {
  required AppRoute route,
  required FixedFolderPicker picker,
}) async {
  final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
  await tester.pumpWidget(const SizedBox.shrink());
  await openNewItem(
    tester,
    route: route,
    dependencies: replaceRepositories(
      buildNewItemDependencies(drafts),
      folderPicker: picker,
    ),
  );
  return drafts;
}

Future<void> _chooseFolder(
  WidgetTester tester, {
  required FixedFolderPicker picker,
  required String? path,
}) async {
  picker.chosenPath = path;
  await tapVisible(tester, find.text(_chooseFolderLabel));
  await pumpFrames(tester);
}

List<String> _pickFolderNames(Random random) {
  final List<String> names = List<String>.of(_folderNames)..shuffle(random);
  return names.take(1 + random.nextInt(names.length)).toList();
}

String _describeFolderAddress(String name) {
  return renderLocalFolderAddress(
    deviceId: GalleryDeviceIds.airLaptop,
    path: '$_folderParent/$name',
  );
}

List<String> _listChosenAddresses(ScriptedItemDraftRepository drafts) {
  return <String>[
    for (final RepositoryDraft folder in drafts.latestRequest.chosenFolders)
      folder.address,
  ];
}

Future<void> _chooseFolders(
  WidgetTester tester, {
  required FixedFolderPicker picker,
  required List<String> names,
}) async {
  for (final String name in names) {
    await _chooseFolder(tester, picker: picker, path: '$_folderParent/$name');
    expect(find.text(name), findsOneWidget);
  }
  expect(find.text(_folderPlace), findsNWidgets(names.length));
}

void main() {
  testWidgets('test_new_item_screen_property_chosen_folders_go_with_drafts', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final Random random = seededRandom(9501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FixedFolderPicker picker = FixedFolderPicker(null);
      final ScriptedItemDraftRepository drafts = await _openNewItem(
        tester,
        route: const NewProjectRoute(),
        picker: picker,
      );
      final List<String> names = _pickFolderNames(random);
      await _chooseFolders(tester, picker: picker, names: names);

      await startNewItemDraft(tester, _draftProjectLabel);
      final List<String> expected = <String>[
        for (final String name in names) _describeFolderAddress(name),
      ];
      expect(_listChosenAddresses(drafts), expected);
      await finishNewItemDraft(
        tester,
        drafts,
        findGalleryItemDraft(DraftKind.project),
      );
      await tester.enterText(find.byType(TextField).last, 'Read only');
      await tapVisible(tester, find.text(sendChangeLabel));
      await pumpFrames(tester);
      expect(drafts.requests, hasLength(2));
      expect(_listChosenAddresses(drafts), expected);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_item_screen_property_a_removed_folder_stays_behind', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final Random random = seededRandom(9502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FixedFolderPicker picker = FixedFolderPicker(null);
      final ScriptedItemDraftRepository drafts = await _openNewItem(
        tester,
        route: const NewProjectRoute(),
        picker: picker,
      );
      final List<String> names = _pickFolderNames(random);
      await _chooseFolders(tester, picker: picker, names: names);
      final int removedIndex = random.nextInt(names.length);

      await tapVisible(tester, find.text(_removeLabel).at(removedIndex));
      await pumpFrames(tester);
      await startNewItemDraft(tester, _draftProjectLabel);

      final List<String> expected = <String>[
        for (int j = 0; j < names.length; j += 1)
          if (j != removedIndex) _describeFolderAddress(names[j]),
      ];
      expect(_listChosenAddresses(drafts), expected);
      await tester.tap(find.text(stopDraftingLabel));
      await pumpFrames(tester);
      expect(find.text(names[removedIndex]), findsNothing);
      expect(find.text(_folderPlace), findsNWidgets(expected.length));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_item_screen_property_folder_problems_show_below', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    final Random random = seededRandom(9503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FixedFolderPicker picker = FixedFolderPicker(null);
      final ScriptedItemDraftRepository drafts = await _openNewItem(
        tester,
        route: const NewProjectRoute(),
        picker: picker,
      );
      final String name = pickOne(random, _folderNames);
      final String relativeProblem =
          'the folder "~/$name" is not an absolute path';

      await _chooseFolder(tester, picker: picker, path: '~/$name');
      expect(find.text(relativeProblem), findsOneWidget);
      expect(find.text(_folderPlace), findsNothing);
      await _chooseFolder(tester, picker: picker, path: null);
      expect(find.text(relativeProblem), findsOneWidget);
      await _chooseFolders(tester, picker: picker, names: <String>[name]);
      expect(find.text(relativeProblem), findsNothing);
      await _chooseFolder(
        tester,
        picker: picker,
        path: '$_folderParent/$name',
      );
      expect(find.text(_alreadyAddedProblem), findsOneWidget);
      expect(find.text(_folderPlace), findsOneWidget);

      await startNewItemDraft(tester, _draftProjectLabel);
      expect(_listChosenAddresses(drafts), <String>[
        _describeFolderAddress(name),
      ]);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_item_screen_property_only_computers_choose_folders', (
    WidgetTester tester,
  ) async {
    for (final TargetPlatform platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      for (final MapEntry<DraftKind, AppRoute> entry
          in newItemRoutes.entries) {
        final FixedFolderPicker picker = FixedFolderPicker(null);
        final ScriptedItemDraftRepository drafts = await _openNewItem(
          tester,
          route: entry.value,
          picker: picker,
        );
        final bool offersFolders =
            entry.key == DraftKind.project && canChooseFolders(platform);

        expect(
          find.text(_chooseFolderLabel),
          offersFolders ? findsOneWidget : findsNothing,
          reason: '${entry.key} on $platform',
        );
        await startNewItemDraft(tester, describeNewItem(entry.key).draftLabel);
        expect(drafts.latestRequest.chosenFolders, isEmpty);
      }
    }
    debugDefaultTargetPlatformOverride = null;
  });

  test('test_item_draft_request_property_keeps_its_own_folders', () {
    final Random random = seededRandom(9504);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RepositoryDraft> chosen = <RepositoryDraft>[
        for (final String name in _pickFolderNames(random))
          RepositoryDraft(
            address: _describeFolderAddress(name),
            defaultBranch: randomText(random),
          ),
      ];
      final List<RepositoryDraft> expected = List<RepositoryDraft>.of(chosen);

      final ItemDraftRequest request = ItemDraftRequest(
        kind: DraftKind.project,
        wish: randomText(random),
        startedFrom: null,
        change: null,
        chosenFolders: chosen,
      );
      chosen.clear();

      expect(request.chosenFolders, expected);
      expect(
        () => request.chosenFolders.add(expected.first),
        throwsUnsupportedError,
      );
    }
  });
}
