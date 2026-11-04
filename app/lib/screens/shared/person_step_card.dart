import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/message_field.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String whatCameInLabel = 'What came in';
const String writtenAnswerHint = 'Or write an answer';
const String writtenAnswerLabel = 'Your answer';
const String sendAnswerLabel = 'Send';
const String emptyAnswerProblem = 'Write an answer first';
const int _resultMaximumLines = 8;

final TextStyle _problemStyle = AppTextStyles.small.copyWith(
  color: AppColors.danger,
);

String describeQuestionTitle(String stepName) => '$stepName asks you';

String describeAnswerProblem(String problem) {
  if (problem.isEmpty) {
    return problem;
  }
  return '${problem[0].toUpperCase()}${problem.substring(1)}';
}

class PersonStepCard extends StatefulWidget {
  const PersonStepCard({
    required this.openStep,
    required this.incomingResults,
    required this.contextLine,
    required this.personStepRepository,
    super.key,
  });

  final OpenPersonStep openStep;
  final List<RunStep> incomingResults;
  final String? contextLine;
  final PersonStepRepository personStepRepository;

  @override
  State<PersonStepCard> createState() => _PersonStepCardState();
}

class _PersonStepCardState extends State<PersonStepCard> {
  final TextEditingController _answerController = TextEditingController();
  String? _problem;
  bool _isSending = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final OpenPersonStep openStep = widget.openStep;
    final String? contextLine = widget.contextLine;
    final String? problem = _problem;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.raised,
        border: Border(
          left: BorderSide(
            color: AppColors.attention,
            width: AppBorders.route,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: spaceVertically(<Widget>[
            if (contextLine != null)
              Text(contextLine, style: AppTextStyles.smallMuted),
            Text(
              describeQuestionTitle(openStep.stepName),
              style: AppTextStyles.bodyBold,
            ),
            Text(openStep.question, style: AppTextStyles.body),
            ..._buildIncomingResults(),
            if (openStep.choices.isNotEmpty) _buildChoiceButtons(openStep),
            _buildWrittenAnswer(),
            if (problem != null) Text(problem, style: _problemStyle),
          ], AppSpacing.space3),
        ),
      ),
    );
  }

  List<Widget> _buildIncomingResults() {
    if (widget.incomingResults.isEmpty) {
      return const <Widget>[];
    }

    return <Widget>[
      const Text(whatCameInLabel, style: AppTextStyles.smallMuted),
      for (final RunStep step in widget.incomingResults)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              step.name,
              style: AppTextStyles.small.merge(AppTextStyles.monospace),
            ),
            Text(
              step.result ?? '',
              style: AppTextStyles.bodyMuted,
              maxLines: _resultMaximumLines,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
    ];
  }

  Widget _buildChoiceButtons(OpenPersonStep openStep) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: <Widget>[
        for (final String choice in openStep.choices)
          AppButton.secondary(
            label: choice,
            onPressed: _isSending
                ? null
                : () => unawaited(_sendAnswer(choice)),
          ),
      ],
    );
  }

  Widget _buildWrittenAnswer() {
    final VoidCallback? sendWrittenAnswer = _isSending
        ? null
        : _sendWrittenAnswer;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: MessageField(
            controller: _answerController,
            hintText: writtenAnswerHint,
            fieldLabel: writtenAnswerLabel,
            onSend: sendWrittenAnswer,
          ),
        ),
        const SizedBox(width: AppSpacing.space2),
        AppButton.primary(
          label: sendAnswerLabel,
          icon: AppIconKind.send,
          onPressed: sendWrittenAnswer,
        ),
      ],
    );
  }

  void _sendWrittenAnswer() {
    final String answer = _answerController.text.trim();
    if (answer.isEmpty) {
      setState(() => _problem = emptyAnswerProblem);
      return;
    }
    unawaited(_sendAnswer(answer));
  }

  Future<void> _sendAnswer(String answer) async {
    setState(() {
      _isSending = true;
      _problem = null;
    });

    try {
      await widget.personStepRepository.answerPersonStep(
        runId: widget.openStep.runId,
        stepName: widget.openStep.stepName,
        answer: answer,
      );
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (mounted) {
        setState(() {
          _problem = describeAnswerProblem(explanation);
          _isSending = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isSending = false);
    }
  }
}
