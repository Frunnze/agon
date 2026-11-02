import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../support/app_harness.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';

const double _lineHeight = AppFontSizes.body * AppLineHeights.body;
const double _fieldFrame = 2 * (AppSpacing.space2 + AppBorders.thin);
const int _wishRows = 5;
const int _changeNoteRows = 1;
const int _workflowDescriptionRows = 4;
const List<Size> _designSizes = <Size>[phoneSize, desktopSize];

Finder _findFieldWithRows(int rows) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is TextField && widget.minLines == rows,
  );
}

void _expectDesignRows(
  WidgetTester tester, {
  required int rows,
  required String reason,
}) {
  final double height = tester.getSize(_findFieldWithRows(rows)).height;
  final int shownRows = ((height - _fieldFrame) / _lineHeight).floor();
  final double designHeight = max(
    AppSizes.controlHeight,
    shownRows * _lineHeight + _fieldFrame,
  );

  expect(height, designHeight, reason: reason);
  expect(shownRows >= rows, isTrue, reason: reason);
}

Future<void> _openRoute(
  WidgetTester tester, {
  required AppRoute route,
  required Size size,
  required AppDependencies dependencies,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: SectionRoute(route.section),
    dependencies: dependencies,
  );
  navigation.openRoute(route);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_item_request_view_property_wish_follows_design_rows', (
    WidgetTester tester,
  ) async {
    for (final DraftKind kind in DraftKind.values) {
      for (final Size size in _designSizes) {
        await _openRoute(
          tester,
          route: newItemRoutes[kind]!,
          size: size,
          dependencies: buildNewItemDependencies(
            ScriptedItemDraftRepository(),
          ),
        );

        _expectDesignRows(tester, rows: _wishRows, reason: '$kind at $size');
      }
    }
  });

  testWidgets('test_change_request_composer_property_note_follows_design', (
    WidgetTester tester,
  ) async {
    for (final Size size in _designSizes) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      await _openRoute(
        tester,
        route: const NewTaskRoute(),
        size: size,
        dependencies: buildNewItemDependencies(drafts),
      );
      final String draftLabel = describeNewItem(DraftKind.task).draftLabel;
      await startNewItemDraft(tester, draftLabel);
      await finishNewItemDraft(
        tester,
        drafts,
        findGalleryItemDraft(DraftKind.task),
      );

      _expectDesignRows(tester, rows: _changeNoteRows, reason: '$size');
    }
  });

  testWidgets('test_new_workflow_screen_property_description_follows_design', (
    WidgetTester tester,
  ) async {
    for (final Size size in _designSizes) {
      await _openRoute(
        tester,
        route: const NewWorkflowRoute(),
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      _expectDesignRows(
        tester,
        rows: _workflowDescriptionRows,
        reason: '$size',
      );
    }
  });
}
