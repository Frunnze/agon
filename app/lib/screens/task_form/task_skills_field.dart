import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/widgets/forms/check_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';

class TaskSkillsField extends StatelessWidget {
  const TaskSkillsField({
    required this.skillIds,
    required this.usesAutomaticSkills,
    required this.options,
    required this.onSkillsChanged,
    required this.onAutomaticSkillsChanged,
    super.key,
  });

  final List<SkillId> skillIds;
  final bool usesAutomaticSkills;
  final TaskFormOptions options;
  final ValueChanged<List<SkillId>> onSkillsChanged;
  final ValueChanged<bool> onAutomaticSkillsChanged;

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: 'Skills to use',
      hint: 'A workflow sets the skills of each of its agents.',
      children: <Widget>[
        TagInputField(
          tags: options.describeSkills(skillIds),
          suggestions: <String>[
            for (final Skill skill in options.skills) skill.name,
          ],
          placeholder: 'Add a skill',
          onTagAdded: _addSkill,
          onTagRemoved: _removeSkill,
        ),
        CheckField(
          label: 'Also let the agent pick automatic skills',
          value: usesAutomaticSkills,
          onChanged: onAutomaticSkillsChanged,
        ),
      ],
    );
  }

  void _addSkill(String skillName) {
    final SkillId skillId = options.findSkillId(skillName);

    onSkillsChanged(<SkillId>[...skillIds, skillId]);
  }

  void _removeSkill(String skillName) {
    final SkillId skillId = options.findSkillId(skillName);
    final List<SkillId> remaining = skillIds
        .where((SkillId candidate) => candidate != skillId)
        .toList();

    onSkillsChanged(remaining);
  }
}
