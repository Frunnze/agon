import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/person_step_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';

const String _separator = ' · ';

String describeAskedTime(DateTime? askedAt, DateTime now) {
  if (askedAt == null) {
    return 'Waiting for your answer';
  }
  return 'Asked ${lowercaseFirstLetter(describeTimeSince(askedAt, now))}';
}

List<OpenPersonStep> findQuestionsForRun(
  List<OpenPersonStep> openSteps,
  RunId runId,
) {
  return <OpenPersonStep>[
    for (final OpenPersonStep openStep in openSteps)
      if (openStep.runId == runId) openStep,
  ];
}

final class PersonStepQuestions {
  const PersonStepQuestions({
    required this.taskRepository,
    required this.workflowRepository,
    required this.personStepRepository,
  });

  final TaskRepository taskRepository;
  final WorkflowRepository workflowRepository;
  final PersonStepRepository personStepRepository;

  Widget buildCardOnRunPage({
    required OpenPersonStep openStep,
    required Run run,
    required Workflow? workflow,
    required DateTime now,
  }) {
    return _buildCard(
      openStep: openStep,
      run: run,
      workflow: workflow,
      contextLine: describeAskedTime(openStep.askedAt, now),
    );
  }

  Widget buildCardInApprovals({
    required OpenPersonStep openStep,
    required DateTime now,
  }) {
    final String asked = describeAskedTime(openStep.askedAt, now);
    final Run? run = _findRun(openStep.runId);
    if (run == null) {
      return _buildCard(
        openStep: openStep,
        run: null,
        workflow: null,
        contextLine: asked,
      );
    }

    final Workflow? workflow = _findWorkflow(run);
    final String runLabel = _describeRun(run, workflow);
    return _buildCard(
      openStep: openStep,
      run: run,
      workflow: workflow,
      contextLine: '$runLabel$_separator${lowercaseFirstLetter(asked)}',
    );
  }

  Widget _buildCard({
    required OpenPersonStep openStep,
    required Run? run,
    required Workflow? workflow,
    required String contextLine,
  }) {
    return PersonStepCard(
      key: ValueKey<String>('${openStep.runId.value} ${openStep.stepName}'),
      openStep: openStep,
      incomingResults: run == null
          ? const <RunStep>[]
          : findIncomingResults(
              run: run,
              workflow: workflow,
              stepName: openStep.stepName,
            ),
      contextLine: contextLine,
      personStepRepository: personStepRepository,
    );
  }

  Run? _findRun(RunId runId) {
    try {
      return taskRepository.findRun(runId);
    } on RecordNotFound {
      return null;
    }
  }

  Workflow? _findWorkflow(Run run) {
    final Task task = taskRepository.findTask(run.taskId);
    return findWorkflowForDoer(task.doer, workflowRepository.listWorkflows());
  }

  String _describeRun(Run run, Workflow? workflow) {
    final Task task = taskRepository.findTask(run.taskId);
    return describeRunLabel(task: task, workflow: workflow, run: run);
  }
}
