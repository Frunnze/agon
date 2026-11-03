import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

const List<AgentPlace> _shownPlaceOrder = <AgentPlace>[
  AgentPlace.localProcess,
  AgentPlace.container,
];

class AgentPlaceField extends StatelessWidget {
  const AgentPlaceField({
    required this.place,
    required this.onChanged,
    super.key,
  });

  final AgentPlace place;
  final ValueChanged<AgentPlace> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormFieldBlock(
      label: agentPlaceTitle,
      hint: taskPlaceHint,
      children: <Widget>[
        SelectField<AgentPlace>(
          value: place,
          entries: <SelectEntry<AgentPlace>>[
            for (final AgentPlace option in _shownPlaceOrder)
              SelectOption<AgentPlace>(
                value: option,
                label: describeTaskPlace(option),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
