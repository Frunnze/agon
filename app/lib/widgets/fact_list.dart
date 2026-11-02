import 'dart:math';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/gaps.dart';
import 'package:agent_orchestration/widgets/label_chip.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

final class Fact {
  const Fact({required this.term, required this.description})
    : chips = const <String>[],
      content = null;

  const Fact.chips({required this.term, required this.chips})
    : description = const <TextSegment>[],
      content = null;

  const Fact.content({required this.term, required Widget this.content})
    : description = const <TextSegment>[],
      chips = const <String>[];

  final String term;
  final List<TextSegment> description;
  final List<String> chips;
  final Widget? content;
}

const double _factGap = AppSpacing.space3;

int countFactColumns({required double width, required int factCount}) {
  const double columnWithGap = AppSizes.factColumnMinimumWidth + _factGap;
  final int fittingColumns = ((width + _factGap) / columnWithGap).floor();
  return max(1, min(fittingColumns, factCount));
}

class FactList extends StatelessWidget {
  const FactList({required this.facts, super.key});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: spaceVertically(<Widget>[
        for (final Fact fact in facts) _FactView(fact),
      ], _factGap),
    );
  }
}

class FactRow extends StatelessWidget {
  const FactRow({required this.facts, super.key});

  final List<Fact> facts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildColumns);
  }

  Widget _buildColumns(BuildContext context, BoxConstraints constraints) {
    final double width = constraints.maxWidth;
    final int columns = countFactColumns(
      width: width,
      factCount: facts.length,
    );
    final double columnWidth = (width - (columns - 1) * _factGap) / columns;

    return Wrap(
      spacing: _factGap,
      runSpacing: _factGap,
      children: <Widget>[
        for (final Fact fact in facts)
          SizedBox(width: columnWidth, child: _FactView(fact)),
      ],
    );
  }
}

class _FactView extends StatelessWidget {
  const _FactView(this.fact);

  final Fact fact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(fact.term, style: AppTextStyles.smallMuted),
        const SizedBox(height: AppSpacing.space1),
        _buildDescription(),
      ],
    );
  }

  Widget _buildDescription() {
    final Widget? content = fact.content;
    if (content != null) {
      return content;
    }
    if (fact.chips.isNotEmpty) {
      return ChipList(fact.chips);
    }
    return MixedText(fact.description, style: AppTextStyles.body);
  }
}
