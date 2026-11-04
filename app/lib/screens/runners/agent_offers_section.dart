import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/check_choice_list_field.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

class AgentOffersSection extends StatelessWidget {
  const AgentOffersSection({
    required this.offers,
    required this.onChanged,
    super.key,
  });

  final List<PlaceOffer> offers;
  final ValueChanged<List<AgentPlace>> onChanged;

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: agentOffersTitle,
      children: <Widget>[
        CheckChoiceListField<AgentPlace>(
          options: <CheckChoiceOption<AgentPlace>>[
            for (final AgentPlace place in AgentPlace.values)
              CheckChoiceOption<AgentPlace>(
                value: place,
                title: describeAgentPlaceTitle(place),
                detail: describeAgentPlaceDetail(place),
                problem: _findProblem(place),
              ),
          ],
          selected: _findOfferedPlaces(),
          onToggled: _toggle,
        ),
        const Text(agentOffersHint, style: AppTextStyles.smallMuted),
      ],
    );
  }

  Set<AgentPlace> _findOfferedPlaces() {
    return <AgentPlace>{for (final PlaceOffer offer in offers) offer.place};
  }

  String? _findProblem(AgentPlace place) {
    for (final PlaceOffer offer in offers) {
      if (offer.place == place) {
        return offer.problem;
      }
    }
    return null;
  }

  void _toggle(AgentPlace place) {
    final Set<AgentPlace> nextPlaces = _findOfferedPlaces();
    if (nextPlaces.contains(place)) {
      nextPlaces.remove(place);
    } else {
      nextPlaces.add(place);
    }
    if (nextPlaces.isEmpty) {
      return;
    }

    final List<AgentPlace> nextOffers = <AgentPlace>[
      for (final AgentPlace candidate in AgentPlace.values)
        if (nextPlaces.contains(candidate)) candidate,
    ];
    onChanged(nextOffers);
  }
}
