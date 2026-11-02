import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/task_views.dart' as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/bridge/commands/task_commands.dart'
    as node;
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../support/form_finders.dart';
import 'support/item_form_steps.dart';
import 'support/real_stack.dart';
import 'support/stack_catalog.dart';
import 'support/stack_navigation.dart';
import 'support/stack_waiting.dart';

const String _jobsTitle = 'Jobs';
const String _projectsTitle = 'Projects';
const String _newJobTitle = 'New job';
const String _editJobTitle = 'Edit job';
const String _titleLabel = 'What should be done?';
const String _siteProjectName = 'site';
const String _docsProjectName = 'docs';
const String _siteAddress = 'github.com/example/site';
const String _docsAddress = 'github.com/example/docs';
const String _jobTitle = 'Check the site links';
const String _editedJobTitle = 'Check the docs links';
const int _dailyHour = 7;
const int _dailyMinute = 30;
const String _dailyTimeText = '07:30';
const int _weeklyHour = 18;
const int _weeklyMinute = 45;
const String _weeklyTimeText = '18:45';
final DateTime _referenceMonday = DateTime.utc(2026, DateTime.january, 5);

Finder _findFieldSelect(String label) {
  return find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) => widget is FormFieldBlock && widget.label == label,
    ),
    matching: find.byWidgetPredicate((Widget widget) => widget is SelectField),
  );
}

Future<void> _chooseFieldOption(
  WidgetTester tester, {
  required String label,
  required String option,
}) async {
  await tapWhenShown(tester, _findFieldSelect(label));
  await tapWhenShown(tester, find.text(option).last);
}

DateTime _findUtcMoment({
  required node.Weekday localDay,
  required int hour,
  required int minute,
}) {
  final Duration utcOffset = DateTime.now().timeZoneOffset;
  final DateTime localWallClock = _referenceMonday.add(
    Duration(days: localDay.index, hours: hour, minutes: minute),
  );
  return localWallClock.subtract(utcOffset);
}

node.ScheduleTime _readScheduleTime(DateTime utcMoment) {
  return node.ScheduleTime(hour: utcMoment.hour, minute: utcMoment.minute);
}

node.Schedule _expectedDailySchedule() {
  final DateTime utcMoment = _findUtcMoment(
    localDay: node.Weekday.monday,
    hour: _dailyHour,
    minute: _dailyMinute,
  );
  return node.EveryDay(at: _readScheduleTime(utcMoment));
}

node.Schedule _expectedWeeklySchedule() {
  final DateTime utcMoment = _findUtcMoment(
    localDay: node.Weekday.friday,
    hour: _weeklyHour,
    minute: _weeklyMinute,
  );
  final node.Weekday utcDay = node.Weekday.values[utcMoment.weekday - 1];
  return node.EveryWeek(on: utcDay, at: _readScheduleTime(utcMoment));
}

Future<node.JobView> _readOnlyJob(WidgetTester tester, RealStack stack) async {
  final List<node.JobView> jobs = await askNode(
    tester,
    () => stack.channel.execute(
      node.ListJobsCommand(workspaceId: stack.homeWorkspaceId),
    ),
  );
  return jobs.single;
}

Future<void> _waitForBothProjects(WidgetTester tester) async {
  await openRailSection(
    tester,
    label: _projectsTitle,
    pageTitle: _projectsTitle,
  );
  await waitUntilShown(tester, find.text(_siteProjectName));
  await waitUntilShown(tester, find.text(_docsProjectName));
}

Future<void> _createDailyJob(WidgetTester tester) async {
  await openRailSection(tester, label: _jobsTitle, pageTitle: _jobsTitle);
  await tapAndWait(
    tester,
    find.text(_newJobTitle),
    expected: findPageTitle(_newJobTitle),
  );
  await waitUntilGone(tester, findPageTitle(_jobsTitle));
  await replaceChatWithForm(tester, kind: DraftKind.job);
  await enterFieldText(tester, label: _titleLabel, text: _jobTitle);
  await _chooseFieldOption(tester, label: 'Project', option: _docsProjectName);
  await _chooseFieldOption(tester, label: 'Repeat', option: 'Every day');
  await enterFieldText(tester, label: 'At', text: _dailyTimeText);
  await tapWhenShown(tester, find.text('Create job'));
  await waitUntilShown(tester, findPageTitle(_jobsTitle));
  await waitUntilGone(tester, findPageTitle(_newJobTitle));
  await waitUntilShown(tester, find.text(_jobTitle));
}

Future<void> _editIntoWeeklyJob(WidgetTester tester) async {
  await tapAndWait(
    tester,
    find.text(_jobTitle),
    expected: findPageTitle(_editJobTitle),
  );
  await waitUntilGone(tester, findPageTitle(_jobsTitle));
  await enterFieldText(tester, label: _titleLabel, text: _editedJobTitle);
  await _chooseFieldOption(tester, label: 'Repeat', option: 'Every week');
  await _chooseFieldOption(tester, label: 'On', option: 'Friday');
  await enterFieldText(tester, label: 'At', text: _weeklyTimeText);
  await tapWhenShown(tester, find.text('Save job'));
  await waitUntilShown(tester, findPageTitle(_jobsTitle));
  await waitUntilGone(tester, findPageTitle(_editJobTitle));
  await waitUntilShown(tester, find.text(_editedJobTitle));
}

void main() {
  testWidgets(
    'test_save_job_property_created_and_edited_job_reach_the_node',
    (WidgetTester tester) async {
      final RealStack stack = await RealStack.openWithAccount(tester);
      await createProjectOnNode(
        tester,
        stack: stack,
        projectName: _siteProjectName,
        repositoryAddress: _siteAddress,
      );
      final node.Project docs = await createProjectOnNode(
        tester,
        stack: stack,
        projectName: _docsProjectName,
        repositoryAddress: _docsAddress,
      );
      await _waitForBothProjects(tester);

      await _createDailyJob(tester);
      expect(find.text('$_docsProjectName · Claude Code'), findsOneWidget);
      expect(find.text('Every day at $_dailyTimeText'), findsOneWidget);
      final node.JobView created = await _readOnlyJob(tester, stack);
      expect(created.task.title, _jobTitle);
      expect(created.task.projectId, docs.id);
      expect(
        created.task.schedule?.toJson(),
        _expectedDailySchedule().toJson(),
      );

      await _editIntoWeeklyJob(tester);
      expect(find.text(_jobTitle), findsNothing);
      expect(find.text('Every Friday at $_weeklyTimeText'), findsOneWidget);
      final node.JobView edited = await _readOnlyJob(tester, stack);
      expect(edited.task.id, created.task.id);
      expect(edited.task.title, _editedJobTitle);
      expect(edited.task.projectId, docs.id);
      expect(
        edited.task.schedule?.toJson(),
        _expectedWeeklySchedule().toJson(),
      );
      await stack.close(tester);
    },
    skip: findRealStackSkipReason() != null,
    timeout: realStackTimeout,
  );
}
