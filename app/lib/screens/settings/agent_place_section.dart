import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

class AgentPlaceSection extends StatelessWidget {
  const AgentPlaceSection({
    required this.place,
    required this.onChanged,
    super.key,
  });

  final AgentPlace place;
  final ValueChanged<AgentPlace> onChanged;

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: agentPlaceTitle,
      children: <Widget>[
        ChoiceListField<AgentPlace>(
          options: <ChoiceOption<AgentPlace>>[
            for (final AgentPlace option in AgentPlace.values)
              ChoiceOption<AgentPlace>(
                value: option,
                title: describeAgentPlaceTitle(option),
                detail: describeAgentPlaceDetail(option),
              ),
          ],
          selected: place,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
