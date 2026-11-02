import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String _timeHint = 'HH:MM';

class ScheduleFields extends StatelessWidget {
  const ScheduleFields({
    required this.repeat,
    required this.repeatChoices,
    required this.repeatHint,
    required this.weekday,
    required this.timeController,
    required this.timeProblem,
    required this.onRepeatChanged,
    required this.onWeekdayChanged,
    super.key,
  });

  final RepeatChoice repeat;
  final List<RepeatChoice> repeatChoices;
  final String? repeatHint;
  final Weekday weekday;
  final TextEditingController timeController;
  final String? timeProblem;
  final ValueChanged<RepeatChoice> onRepeatChanged;
  final ValueChanged<Weekday> onWeekdayChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        FormFieldBlock(
          label: 'Repeat',
          hint: repeatHint,
          children: <Widget>[
            SelectField<RepeatChoice>(
              value: repeat,
              entries: <SelectEntry<RepeatChoice>>[
                for (final RepeatChoice choice in repeatChoices)
                  SelectOption<RepeatChoice>(
                    value: choice,
                    label: choice.label,
                  ),
              ],
              onChanged: onRepeatChanged,
            ),
          ],
        ),
        if (repeat == RepeatChoice.weekly)
          FormFieldBlock(
            label: 'On',
            children: <Widget>[
              SelectField<Weekday>(
                value: weekday,
                entries: <SelectEntry<Weekday>>[
                  for (final Weekday day in Weekday.values)
                    SelectOption<Weekday>(value: day, label: day.label),
                ],
                onChanged: onWeekdayChanged,
              ),
            ],
          ),
        if (repeat.needsTime)
          FormFieldBlock(
            label: 'At',
            children: <Widget>[
              TextField(
                controller: timeController,
                keyboardType: TextInputType.datetime,
                decoration: InputDecoration(
                  hintText: _timeHint,
                  errorText: timeProblem,
                ),
              ),
            ],
          ),
      ], AppSpacing.space5),
    );
  }
}
