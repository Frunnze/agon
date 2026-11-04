import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/new_items/item_drafting_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/draft_kind_sections.dart';
import 'package:agent_orchestration/shell/new_item_route_screens.dart';

import '../../support/random_inputs.dart';

DraftedWork _workFor(ProjectId? projectId, String title) {
  return DraftedWork(
    title: title,
    details: '',
    projectId: projectId,
    doer: const OneAgentDoer(AgentKind.geminiCli),
    runsOn: const AnyFreeRunner(),
    agentPlace: AgentPlace.localProcess,
    skills: const <SkillId>[],
    usesAutomaticSkills: false,
    approvalPolicy: ApprovalPolicy.neverAsk,
    schedule: null,
  );
}

void main() {
  test('test_describe_new_item_property_titles_name_the_kind', () {
    for (final DraftKind kind in DraftKind.values) {
      final NewItemTexts texts = describeNewItem(kind);

      expect(texts.pageTitle, 'New ${kind.name}');
      expect(texts.draftLabel, 'Draft ${kind.name}');
      expect(texts.question, endsWith('?'));
      expect(texts.changeExample, startsWith('For example: '));
    }
  });

  test('test_find_draft_kind_section_property_form_route_matches_kind', () {
    for (final DraftKind kind in DraftKind.values) {
      final NewItemFormRoute route = NewItemFormRoute(kind);

      expect(route.section, findDraftKindSection(kind));
      expect(route, NewItemFormRoute(kind));
      expect(route.section.name, startsWith(kind.name));
    }
  });

  test(
    'test_describe_agent_access_choice_title_property_every_access_has_one',
    () {
      for (final AgentAccess access in AgentAccess.values) {
        expect(describeAgentAccessChoiceTitle(access), isNotEmpty);
      }
    },
  );

  test('test_describe_drafted_repository_place_property_ends_with_branch', () {
    final Random random = seededRandom(8604);
    final DeviceNames deviceNames = DeviceNames(const []);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String branch = 'branch-${random.nextInt(100)}';
      final String address = random.nextBool()
          ? 'github.com/acme/app'
          : renderLocalFolderAddress(
              deviceId: GalleryDeviceIds.airLaptop,
              path: '/code/app',
            );

      final String place = describeDraftedRepositoryPlace(
        RepositoryDraft(address: address, defaultBranch: branch),
        deviceNames,
      );

      expect(place, endsWith(' · $branch'));
    }
  });

  test('test_to_task_draft_property_needs_a_project_and_keeps_fields', () {
    final Random random = seededRandom(8605);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomText(random);

      final TaskDraft draft = _workFor(
        GalleryProjectIds.docs,
        title,
      ).toTaskDraft();

      expect(draft.title, title);
      expect(draft.projectId, GalleryProjectIds.docs);
      expect(() => _workFor(null, title).toTaskDraft(), throwsStateError);
    }
  });

  test('test_to_project_draft_property_gives_every_repo_the_access', () {
    final Random random = seededRandom(8606);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentAccess access = pickOne(random, AgentAccess.values);
      final DraftedProject drafted = DraftedProject(
        name: 'billing',
        repositories: <RepositoryDraft>[
          for (int j = 0; j < random.nextInt(4); j += 1)
            RepositoryDraft(
              address: 'github.com/a/r$j',
              defaultBranch: 'main',
            ),
        ],
        agentAccess: access,
        approvalPolicy: null,
      );

      final ProjectDraft project = drafted.toProjectDraft(
        GalleryWorkspaceIds.acme,
      );

      expect(project.repositories, hasLength(drafted.repositories.length));
      for (final Repository repository in project.repositories) {
        expect(repository.agentAccess, access);
      }
    }
  });

  test('test_describe_starting_place_property_names_the_place', () {
    final Random random = seededRandom(8607);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomText(random);

      expect(describeStartingProject(name), contains(name));
      expect(describeStartingWorkflow(name), contains(name));
    }
  });

  test('test_describe_item_drafter_property_names_agent_and_device', () {
    final DeviceNames deviceNames = DeviceNames(const []);
    for (final AgentKind kind in AgentKind.values) {
      final String text = describeItemDrafter(
        running: DraftRunning(
          drafterKind: kind,
          drafterDeviceId: GalleryDeviceIds.officeServer,
        ),
        deviceNames: deviceNames,
      );

      expect(text, startsWith(kind.label));
      expect(text, contains(' is drafting on '));
    }
    expect(
      describeItemDrafter(running: null, deviceNames: deviceNames),
      startingDraftText,
    );
  });
}
