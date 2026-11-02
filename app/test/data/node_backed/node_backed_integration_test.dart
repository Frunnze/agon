import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/native/native_library_source.dart';
import 'package:agent_orchestration/bridge/native/native_node_transport.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_lifecycle.dart';
import 'package:agent_orchestration/bridge/node/node_start_configuration.dart';
import 'package:agent_orchestration/bridge/node/runner_settings.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/host_node_files.dart';
import '../../bridge/support/local_orchestration_server.dart';
import '../../support/memory_workspace_choice_store.dart';

const Duration _pollInterval = Duration(milliseconds: 200);
const Timeout _integrationTimeout = Timeout(Duration(minutes: 3));
final RegExp _displayedPairingCode = RegExp(r'^[0-9A-Z]{3}-[0-9A-Z]{3}$');

void main() {
  final String libraryPath = hostLibraryPath();
  final String? skipReason = File(libraryPath).existsSync()
      ? null
      : 'the host node library $libraryPath is missing; '
            'run scripts/build-rust-host.sh first';

  test(
    'test_create_hosted_account_property_account_flows_through_repositories',
    () async {
      final Directory workingDirectory = Directory.systemTemp.createTempSync(
        'node_backed_',
      );
      addTearDown(() => workingDirectory.deleteSync(recursive: true));
      final int appServerPort = await findFreePort();
      final NativeNodeTransport transport = NativeNodeTransport(
        source: LibraryFile(path: libraryPath),
      );
      await startNode(
        transport: transport,
        configuration: NodeStartConfiguration(
          dataDirectory: '${workingDirectory.path}/node',
          identityStore: const FileIdentityStore(),
          peerRelay: PeerRelayChoice.disabled,
          runner: const NoRunner(),
          appServerPort: appServerPort,
        ),
      );
      addTearDown(() => stopNode(transport));
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: transport,
      );
      const Clock clock = SystemClock();

      final NodeBackedPairingRepository pairing = NodeBackedPairingRepository(
        channel: channel,
        clock: clock,
        pollInterval: _pollInterval,
        runnerLabels: const <String>[],
      );
      final PairingOutcome outcome = await pairing.createHostedAccount(
        workspaceName: 'home',
        deviceName: 'laptop',
        role: DeviceRole.client,
      );
      expect(outcome.deviceName, 'laptop');
      expect(outcome.workspaceNames, <String>['home']);
      expect(outcome.approverName, isNull);

      final NodeBackedWorkspaceRepository workspaces =
          NodeBackedWorkspaceRepository(
            channel: channel,
            clock: clock,
            retryInterval: const Duration(seconds: 30),
            choiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
          );
      await workspaces.load();
      final Workspace home = workspaces.currentWorkspace();
      expect(home.name, 'home');
      expect(workspaces.findAppServerStatus().state, AppServerState.online);

      final NodeBackedProjectRepository projects = NodeBackedProjectRepository(
        channel: channel,
        workspaceRepository: workspaces,
      );
      final Project project = await projects.createProject(
        ProjectDraft(
          workspaceId: home.id,
          name: 'website',
          repositories: const <Repository>[
            Repository(
              address: 'https://github.com/example/site.git',
              defaultBranch: 'main',
              agentAccess: AgentAccess.readOnly,
            ),
          ],
        ),
      );
      await projects.load();
      expect(projects.listProjects(home.id).single.id, project.id);
      expect(
        projects.findProject(project.id).repositories.single.address,
        'github.com/example/site',
      );

      final NodeBackedSkillRepository skills = NodeBackedSkillRepository(
        channel: channel,
        workspaceRepository: workspaces,
      );
      final Skill skill = await skills.createSkill(
        const SkillDraft(
          name: 'code-review',
          summary: 'Reviews a change.',
          instructions: 'Read the diff first.',
          scope: Scope.everywhere(),
          usage: SkillUsage.whenChosen,
        ),
      );
      await skills.load();
      expect(skills.findSkill(skill.id).instructions, 'Read the diff first.');

      final NodeBackedRuleRepository rules = NodeBackedRuleRepository(
        channel: channel,
        workspaceRepository: workspaces,
      );
      final Rule rule = await rules.createRule(
        const RuleDraft(
          title: 'Run the tests',
          details: 'Before every push.',
          scope: Scope.everywhere(),
        ),
      );
      await rules.turnRuleOff(rule.id);
      await rules.load();
      expect(rules.listRules().single.details, 'Before every push.');
      expect(rules.listRules().single.enabled, isFalse);

      final NodeBackedWorkflowRepository workflows =
          NodeBackedWorkflowRepository(
            channel: channel,
            workspaceRepository: workspaces,
            draftPollInterval: _pollInterval,
          );
      await workflows.load();
      expect(workflows.listWorkflows(), isEmpty);

      final PairingSession session = await pairing.startPairing();
      expect(session.code, matches(_displayedPairingCode));
      expect(session.expiresAt.isAfter(clock.now()), isTrue);
      expect(pairing.findActiveSession()?.code, session.code);
      expect(pairing.findPendingRequest(), isNull);

      pairing.dispose();
      workflows.dispose();
      rules.dispose();
      skills.dispose();
      projects.dispose();
      workspaces.dispose();
    },
    skip: skipReason,
    timeout: _integrationTimeout,
  );
}
