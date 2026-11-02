import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_files.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

import '../../support/app_harness.dart';

const String fixLoginBranch = 'task/fix-login-redirect-a41c';
const ProjectFilesRoute appFilesRoute = ProjectFilesRoute(
  projectId: GalleryProjectIds.acmeApp,
  repositoryAddress: galleryAppRepositoryAddress,
);
const ProjectFilesRoute apiFilesRoute = ProjectFilesRoute(
  projectId: GalleryProjectIds.acmeApp,
  repositoryAddress: galleryApiRepositoryAddress,
);

Future<AppNavigation> openFiles(
  WidgetTester tester, {
  required Size size,
  required ProjectFilesRoute route,
  AppDependencies? dependencies,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: route,
    dependencies: dependencies ?? buildGalleryDependencies(),
  );
  await pumpFrames(tester);
  return navigation;
}

Finder findPicker(String label) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) => widget is FormFieldBlock && widget.label == label,
    ),
    matching: find.byType(DropdownButton<String>),
  );
}

Future<void> choosePickerOption(
  WidgetTester tester, {
  required String label,
  required String option,
}) async {
  await tester.ensureVisible(findPicker(label));
  await tester.pump();
  await tester.tap(findPicker(label));
  await pumpFrames(tester);
  await tester.tap(find.text(option).last);
  await pumpFrames(tester);
}

Future<void> tapTreeRow(WidgetTester tester, String name) async {
  final Finder row = find.text(name).first;
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
  await pumpFrames(tester);
}

Future<void> openTreePath(WidgetTester tester, List<String> names) async {
  for (final String name in names) {
    await tapTreeRow(tester, name);
  }
}

void expectTexts(List<String> texts) {
  for (final String text in texts) {
    expect(find.text(text), findsWidgets, reason: text);
  }
}

void expectNoTexts(List<String> texts) {
  for (final String text in texts) {
    expect(find.text(text), findsNothing, reason: text);
  }
}
