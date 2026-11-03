import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/skill_names.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/field_padding.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/check_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const int _taskMinimumLines = 4;
const int _taskMaximumLines = 8;

class AgentSettingsPanel extends StatefulWidget {
  const AgentSettingsPanel({
    required this.workflow,
    required this.agent,
    required this.runnerOptions,
    required this.skills,
    required this.onAgentChanged,
    required this.onFillInRequested,
    required this.onRemoved,
    required this.onDone,
    super.key,
  });

  final Workflow workflow;
  final WorkflowAgent agent;
  final List<SelectOption<RunnerTarget>> runnerOptions;
  final List<Skill> skills;
  final ValueChanged<WorkflowAgent> onAgentChanged;
  final VoidCallback onFillInRequested;
  final VoidCallback onRemoved;
  final VoidCallback onDone;

  @override
  State<AgentSettingsPanel> createState() => _AgentSettingsPanelState();
}

class _AgentSettingsPanelState extends State<AgentSettingsPanel> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.agent.name,
  );
  late final TextEditingController _taskController = TextEditingController(
    text: widget.agent.task,
  );
  String? _nameProblem;

  @override
  void didUpdateWidget(AgentSettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_taskController.text != widget.agent.task) {
      _taskController.text = widget.agent.task;
    }
    if (_nameProblem == null && _nameController.text != widget.agent.name) {
      _nameController.text = widget.agent.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final WorkflowAgent agent = widget.agent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: const Text(
                  'Agent settings',
                  style: AppTextStyles.bodyBold,
                ),
              ),
            ),
            AppButton.secondary(label: 'Done', onPressed: widget.onDone),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: 'Fill in with agent',
            icon: AppIconKind.draft,
            onPressed: widget.onFillInRequested,
          ),
        ),
        FormFieldBlock(
          label: 'Name',
          children: <Widget>[
            TextField(
              controller: _nameController,
              autocorrect: false,
              style: AppTextStyles.body.merge(AppTextStyles.monospace),
              decoration: InputDecoration(errorText: _nameProblem),
              onChanged: _changeName,
            ),
          ],
        ),
        FormFieldBlock(
          label: 'Agent',
          children: <Widget>[
            SelectField<AgentKindChoice>(
              value: AgentKindChoice(agent.kind),
              entries: buildAgentKindEntries(agent.kind),
              onChanged: (AgentKindChoice choice) =>
                  widget.onAgentChanged(agent.copyWith(kind: choice.kind)),
            ),
          ],
        ),
        FormFieldBlock(
          label: 'Task',
          children: <Widget>[
            TextField(
              controller: _taskController,
              minLines: _taskMinimumLines,
              maxLines: _taskMaximumLines,
              decoration: const InputDecoration(
                hintText: 'What should this agent do?',
                contentPadding: multiLineFieldPadding,
              ),
              onChanged: (String task) =>
                  widget.onAgentChanged(agent.copyWith(task: task)),
            ),
          ],
        ),
        FormFieldBlock(
          label: 'Runs on',
          children: <Widget>[
            SelectField<RunnerTarget>(
              value: agent.runsOn,
              entries: widget.runnerOptions,
              onChanged: (RunnerTarget target) =>
                  widget.onAgentChanged(agent.copyWith(runsOn: target)),
            ),
          ],
        ),
        _buildSkillsField(agent),
        _buildApprovalField(agent),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.secondary(
            label: 'Remove agent',
            onPressed: widget.onRemoved,
          ),
        ),
      ], AppSpacing.space4),
    );
  }

  Widget _buildSkillsField(WorkflowAgent agent) {
    return FormFieldBlock(
      label: 'Skills to use',
      children: <Widget>[
        TagInputField(
          tags: describeSkillNames(
            skills: widget.skills,
            skillIds: agent.skills,
          ),
          suggestions: <String>[
            for (final Skill skill in widget.skills) skill.name,
          ],
          placeholder: 'Add a skill',
          onTagAdded: (String name) => _addSkill(agent, name),
          onTagRemoved: (String name) => _removeSkill(agent, name),
        ),
        CheckField(
          label: 'Also let the agent pick automatic skills',
          value: agent.usesAutomaticSkills,
          onChanged: (bool usesAutomaticSkills) => widget.onAgentChanged(
            agent.copyWith(usesAutomaticSkills: usesAutomaticSkills),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalField(WorkflowAgent agent) {
    return ApprovalPolicyField(
      selected: agent.approvalPolicy,
      onChanged: (ApprovalPolicy policy) =>
          widget.onAgentChanged(agent.copyWith(approvalPolicy: policy)),
    );
  }

  void _changeName(String name) {
    final String? problem = describeAgentNameProblem(
      workflow: widget.workflow,
      agent: widget.agent,
      name: name,
    );

    setState(() => _nameProblem = problem);
    if (problem == null) {
      widget.onAgentChanged(widget.agent.copyWith(name: name));
    }
  }

  void _addSkill(WorkflowAgent agent, String skillName) {
    final SkillId skillId = findSkillIdByName(
      skills: widget.skills,
      skillName: skillName,
    );

    widget.onAgentChanged(
      agent.copyWith(skills: <SkillId>[...agent.skills, skillId]),
    );
  }

  void _removeSkill(WorkflowAgent agent, String skillName) {
    final SkillId skillId = findSkillIdByName(
      skills: widget.skills,
      skillName: skillName,
    );
    final List<SkillId> remaining = <SkillId>[
      for (final SkillId candidate in agent.skills)
        if (candidate != skillId) candidate,
    ];

    widget.onAgentChanged(agent.copyWith(skills: remaining));
  }
}
