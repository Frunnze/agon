import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

const String galleryBillingFolderPath = '/Users/someone/code/billing-ui';
const int _weeklyRunHour = 9;
const int _weeklyRunMinute = 0;

ItemDraft _buildTaskDraft() {
  return ItemDraft(
    item: DraftedWork(
      title: 'Clean up old feature branches',
      details:
          'Delete branches merged more than 30 days ago. Keep release '
          'branches.',
      projectId: GalleryProjectIds.acmeApp,
      doer: const OneAgentDoer(AgentKind.claudeCode),
      runsOn: const AnyFreeRunner(),
      agentPlace: AgentPlace.localProcess,
      skills: const <SkillId>[GallerySkillIds.gitCleanup],
      usesAutomaticSkills: true,
      approvalPolicy: null,
      schedule: null,
    ),
    problems: const <String>[],
  );
}

ItemDraft _buildJobDraft() {
  return ItemDraft(
    item: DraftedWork(
      title: 'Update dependencies',
      details:
          'Update the npm and Swift packages. Open a pull request with the '
          'changes.',
      projectId: GalleryProjectIds.acmeApp,
      doer: const OneAgentDoer(AgentKind.claudeCode),
      runsOn: const AnyFreeRunner(),
      agentPlace: AgentPlace.localProcess,
      skills: const <SkillId>[],
      usesAutomaticSkills: true,
      approvalPolicy: null,
      schedule: WeeklySchedule(
        on: Weekday.monday,
        at: ScheduleTime(hour: _weeklyRunHour, minute: _weeklyRunMinute),
      ),
    ),
    problems: const <String>[],
  );
}

ItemDraft _buildProjectDraft() {
  return ItemDraft(
    item: DraftedProject(
      name: 'billing',
      repositories: <RepositoryDraft>[
        const RepositoryDraft(
          address: 'github.com/acme/billing',
          defaultBranch: 'main',
        ),
        RepositoryDraft(
          address: renderLocalFolderAddress(
            deviceId: GalleryDeviceIds.airLaptop,
            path: galleryBillingFolderPath,
          ),
          defaultBranch: 'main',
        ),
      ],
      agentAccess: AgentAccess.pushAfterApproval,
      approvalPolicy: null,
    ),
    problems: const <String>[],
  );
}

ItemDraft _buildSkillDraft() {
  return ItemDraft(
    item: DraftedSkill(
      SkillDraft(
        name: 'release-notes',
        summary: 'Write release notes from merged pull requests',
        instructions:
            'List merged pull requests.\n'
            'Group: Added, Changed, Fixed.\n'
            'One plain sentence each.',
        scope: Scope(
          workspaces: const AllWorkspaces(),
          projects: OnlyProjects(const <ProjectId>[GalleryProjectIds.docs]),
        ),
        usage: SkillUsage.automatic,
        improvement: SkillImprovement.never,
      ),
    ),
    problems: const <String>[],
  );
}

ItemDraft _buildRuleDraft() {
  return ItemDraft(
    item: const DraftedRule(
      RuleDraft(
        title: 'Keep commits small',
        details:
            'One change per commit, with a short message that says what '
            'changed.',
        scope: Scope.everywhere(),
      ),
    ),
    problems: const <String>[],
  );
}

Map<DraftKind, ItemDraft> buildGalleryItemDrafts() {
  return <DraftKind, ItemDraft>{
    DraftKind.task: _buildTaskDraft(),
    DraftKind.job: _buildJobDraft(),
    DraftKind.project: _buildProjectDraft(),
    DraftKind.skill: _buildSkillDraft(),
    DraftKind.rule: _buildRuleDraft(),
  };
}
