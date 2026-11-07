import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';

import '../fakes/support/project_inputs.dart';
import '../../support/random_inputs.dart';
import 'support/project_reply_race.dart';

const int _raceIterations = 40;
const int _longestRace = 12;

enum _RaceStep {
  createProject,
  addRepository,
  removeRepository,
  deleteProject,
  addRepositoryElsewhere,
  changeProjectsElsewhere,
  releaseOneReply,
  deliverAnnouncement,
}

void _addRandomRepository(Random random, ProjectReplyRace race) {
  final Project? project = pickListedProject(random, race);
  if (project == null) {
    return;
  }
  final Repository repository = randomRepositoryAt(
    random,
    randomCanonicalAddress(random),
  );
  race.pendingWork.start(race.projects.addRepository(project.id, repository));
}

void _removeRandomRepository(Random random, ProjectReplyRace race) {
  final Project? project = pickListedProject(random, race);
  if (project == null || project.repositories.isEmpty) {
    return;
  }
  final Repository repository = pickOne(random, project.repositories);
  race.pendingWork.start(
    race.projects.removeRepository(project.id, repository.address),
  );
}

void _deleteRandomProject(Random random, ProjectReplyRace race) {
  final Project? project = pickListedProject(random, race);
  if (project == null) {
    return;
  }
  race.pendingWork.start(race.projects.deleteProject(project.id));
}

void _takeStep(Random random, ProjectReplyRace race, _RaceStep step) {
  switch (step) {
    case _RaceStep.createProject:
      final ProjectDraft draft = ProjectDraft(
        workspaceId: pickRaceWorkspaceId(random, race),
        name: 'made-${random.nextInt(1000)}',
        repositories: randomDistinctRepositories(random),
        approvalPolicy: null,
      );
      race.pendingWork.start(race.projects.createProject(draft));
    case _RaceStep.addRepository:
      _addRandomRepository(random, race);
    case _RaceStep.removeRepository:
      _removeRandomRepository(random, race);
    case _RaceStep.deleteProject:
      _deleteRandomProject(random, race);
    case _RaceStep.addRepositoryElsewhere:
      addRepositoryElsewhere(random, race);
    case _RaceStep.changeProjectsElsewhere:
      changeProjectsElsewhere(random, race);
    case _RaceStep.releaseOneReply:
      race.transport.releaseRandomReply();
    case _RaceStep.deliverAnnouncement:
      deliverWaitingProjectAnnouncement(race);
  }
}

Future<void> _expectRaceEndsLikeAReload(
  Random random,
  List<_RaceStep> steps,
) async {
  for (int i = 0; i < _raceIterations; i += 1) {
    final ProjectReplyRace race = await openProjectReplyRace(random);
    final int stepCount = 1 + random.nextInt(_longestRace);

    for (int step = 0; step < stepCount; step += 1) {
      _takeStep(random, race, pickOne(random, steps));
      await pumpEventQueue();
    }

    final List<String> shown = await finishProjectReplyRace(race);
    expect(
      shown,
      await reloadProjectsFrom(race.node.channel, race.workspaces),
    );
    closeProjectReplyRace(race);
  }
}

void main() {
  test('test_node_backed_project_repository_add_repository_property_late_'
      'replies_end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(seededRandom(80751), const <_RaceStep>[
      _RaceStep.addRepository,
      _RaceStep.addRepositoryElsewhere,
      _RaceStep.releaseOneReply,
      _RaceStep.deliverAnnouncement,
    ]);
  });

  test('test_node_backed_project_repository_remove_repository_property_late_'
      'replies_end_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(seededRandom(80752), const <_RaceStep>[
      _RaceStep.removeRepository,
      _RaceStep.addRepository,
      _RaceStep.addRepositoryElsewhere,
      _RaceStep.releaseOneReply,
      _RaceStep.deliverAnnouncement,
    ]);
  });

  test('test_node_backed_project_repository_load_property_any_interleaving_'
      'ends_like_a_reload', () async {
    await _expectRaceEndsLikeAReload(seededRandom(80753), _RaceStep.values);
  });
}
