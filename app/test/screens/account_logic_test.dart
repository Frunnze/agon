import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/rules.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/screens/setup.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/screens/skills/skill_name_problem.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../support/random_inputs.dart';
import '../support/sample_runners.dart';
import '../support/sample_scopes.dart';

void main() {
  final ProjectRepository projectRepository =
      buildGalleryDependencies().projectRepository;

  test('test_describe_skill_name_problem_property_naming_then_taken', () {
    final Random random = seededRandom(9801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = random.nextBool()
          ? pickOne(random, gallerySkills).name
          : randomWordPhrase(random).replaceAll(' ', '-');
      final String? problem = describeSkillNameProblem(
        name: name,
        existingSkills: gallerySkills,
      );
      final String? namingProblem = describeNameProblem(name);
      final bool isTaken = gallerySkills.any((skill) => skill.name == name);

      if (namingProblem != null) {
        expect(problem, namingProblem);
      } else if (isTaken) {
        expect(problem, 'A skill named $name already exists');
      } else {
        expect(problem, isNull);
      }
    }
  });

  test('test_build_preset_rule_scope_property_project_and_its_workspace', () {
    final Random random = seededRandom(9802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Project? project = random.nextBool()
          ? pickOne(random, galleryProjects)
          : null;
      final ScopeSelection selection = buildPresetRuleScope(
        presetProjectId: project?.id,
        projectRepository: projectRepository,
      );

      if (project == null) {
        expect(selection.workspaceIds, isEmpty);
        expect(selection.projectIds, isEmpty);
      } else {
        expect(selection.workspaceIds, <WorkspaceId>[project.workspaceId]);
        expect(selection.projectIds, <ProjectId>[project.id]);
      }
    }
  });

  test('test_split_markdown_lines_property_one_code_line_per_text_line', () {
    final Random random = seededRandom(9803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> textLines = <String>[
        for (int index = 0; index < 1 + random.nextInt(6); index += 1)
          if (random.nextBool()) '' else randomWordPhrase(random),
      ];
      final String markdown = '${textLines.join('\n')}\n';
      final List<CodeBlockLine> lines = splitMarkdownLines(markdown);

      expect(lines.length, textLines.length);
      for (int index = 0; index < lines.length; index += 1) {
        final String expected = textLines[index].isEmpty
            ? ' '
            : textLines[index];
        expect(lines[index].text, expected);
      }
    }
  });

  test('test_list_workspace_members_property_live_members_only', () {
    final Random random = seededRandom(9804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> devices = <Device>[
        for (final Device device in galleryDevices)
          if (random.nextBool()) device.asRevoked() else device,
      ];
      final WorkspaceId workspaceId = pickOne(random, sampleWorkspaceIds);
      final List<Device> members = listWorkspaceMembers(
        devices: devices,
        workspaceId: workspaceId,
      );

      for (final Device device in devices) {
        final bool isMember =
            !device.revoked && device.workspaces.contains(workspaceId);
        expect(members.contains(device), isMember);
      }
    }
  });

  test('test_build_app_server_status_label_property_online_is_calm', () {
    for (final AppServerState state in AppServerState.values) {
      final StatusLabel label = buildAppServerStatusLabel(state);

      expect(label.tone == StatusTone.normal, state == AppServerState.online);
    }
    expect(buildAppServerStatusLabel(AppServerState.online).text, 'Online');
  });

  test('test_build_runner_status_label_property_text_follows_reach', () {
    final Random random = seededRandom(9805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = randomRunner(random);
      final RunnerReach reach = pickOne(random, RunnerReach.values);
      final StatusLabel label = buildRunnerStatusLabel(
        runner: runner,
        reach: reach,
      );

      switch (reach) {
        case RunnerReach.reachable:
          expect(label.text, runner.acceptingNewRuns ? 'Online' : 'Paused');
        case RunnerReach.offline:
          expect(label.text, 'Offline');
        case RunnerReach.needsServer:
          expect(label.text, 'Unreachable');
      }
    }
  });

  test('test_find_steps_running_on_property_only_running_steps_there', () {
    final TaskRepository taskRepository =
        buildGalleryDependencies().taskRepository;

    for (final Runner runner in galleryRunners) {
      final List<RunningStep> steps = findStepsRunningOn(
        deviceId: runner.deviceId,
        taskRepository: taskRepository,
      );

      for (final RunningStep running in steps) {
        expect(running.step.runner, runner.deviceId);
        expect(running.run.taskId, running.task.id);
      }
    }
    final List<RunningStep> onMacStudio = findStepsRunningOn(
      deviceId: GalleryDeviceIds.macStudio,
      taskRepository: taskRepository,
    );
    expect(onMacStudio.single.task.title, 'Ship release 2.4');
    expect(onMacStudio.single.step.name, 'build-ios');
  });

  test('test_describe_paired_role_note_property_runner_roles_share_note', () {
    for (final String trayName in <String>['menu bar', 'tray']) {
      expect(
        describePairedRoleNote(role: DeviceRole.runner, trayName: trayName),
        describePairedRoleNote(
          role: DeviceRole.clientAndRunner,
          trayName: trayName,
        ),
      );
      expect(
        describePairedRoleNote(role: DeviceRole.client, trayName: trayName),
        isNot(
          describePairedRoleNote(role: DeviceRole.runner, trayName: trayName),
        ),
      );
      for (final DeviceRole role in DeviceRole.values) {
        expect(
          describePairedRoleNote(role: role, trayName: trayName),
          endsWith('.'),
        );
      }
    }
  });

  test('test_describe_paired_role_note_property_runners_name_their_tray', () {
    final Random random = seededRandom(9809);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRole role = pickOne(random, DeviceRole.values);
      final String trayName = randomWordPhrase(random);
      final String note = describePairedRoleNote(
        role: role,
        trayName: trayName,
      );
      final String trayPhrase = 'stays in the $trayName and keeps';

      expect(note.contains(trayPhrase), roleRunsTasks(role));
    }
    expect(
      describePairedRoleNote(role: DeviceRole.runner, trayName: 'menu bar'),
      'It starts when you log in, stays in the menu bar and keeps running '
      'tasks after you close this window. Your other devices can send it '
      'work now.',
    );
    expect(
      describePairedRoleNote(role: DeviceRole.runner, trayName: 'tray'),
      startsWith('It starts when you log in, stays in the tray and keeps'),
    );
  });

  test('gallery workspaces are the ones the presets resolve against', () {
    expect(
      galleryWorkspaces.map((Workspace workspace) => workspace.id),
      sampleWorkspaceIds,
    );
  });
}
