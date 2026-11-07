import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart';
import 'package:agent_orchestration/bridge/commands/project_commands.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../codecs/support/codec_rows.dart';
import '../support/hostile_texts.dart';
import '../support/list_copy_properties.dart';
import 'support/project_command_wire_models.dart';

const int _repositoriesCopySeed = 6063000;
const int _nestedArgumentsSeed = 6063100;
const String _repositoriesField = 'repositories';
const String _repositoryField = 'repository';
const String _strayField = 'stray';

CreateProjectCommand _buildCreateProject(
  Random random,
  List<Repository> repositories,
) {
  return CreateProjectCommand(
    workspaceId: WorkspaceId(randomHostileText(random)),
    projectName: randomHostileText(random),
    repositories: repositories,
    approvalPolicy: randomChosenApprovalPolicy(random),
  );
}

List<Repository> _readRepositories(CreateProjectCommand command) {
  return command.repositories;
}

void _scribbleOverRepositoriesJson(Random random, List<Object?> sentJson) {
  if (sentJson.isNotEmpty) {
    final JsonObject firstRepository = sentJson.first! as JsonObject;
    firstRepository['address'] = randomHostileText(random);
    firstRepository.remove('agent_access');
  }
  sentJson.add(<String, Object?>{_strayField: randomText(random)});
  if (random.nextBool()) {
    sentJson.clear();
  }
}

void main() {
  testListCopyProperties(
    const ListCopy<CreateProjectCommand, Repository>(
      testNamePrefix:
          'test_create_project_command_constructor_property_repositories',
      seed: _repositoriesCopySeed,
      buildElement: randomHostileRepository,
      construct: _buildCreateProject,
      readList: _readRepositories,
    ),
  );

  test('test_create_project_command_arguments_property_'
      'nested_repositories_are_fresh_on_every_read', () {
    final Random random = seededRandom(_nestedArgumentsSeed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Repository> repositories = randomHostileRepositories(random);
      final CreateProjectCommand command = _buildCreateProject(
        random,
        repositories,
      );
      final Object? firstRead = command.arguments[_repositoriesField];
      _scribbleOverRepositoriesJson(random, firstRead! as List<Object?>);

      expect(
        rereadThroughWire(command.arguments[_repositoriesField]),
        equals(expectedRepositoriesJson(repositories)),
      );
    }
  });

  test('test_create_project_command_arguments_property_'
      'keeps_repository_order_and_repeats', () {
    final Random random = seededRandom(_nestedArgumentsSeed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Repository repeated = randomHostileRepository(random);
      final List<Repository> repositories = <Repository>[
        repeated,
        ...randomHostileRepositories(random),
        repeated,
      ];
      final CreateProjectCommand command = _buildCreateProject(
        random,
        repositories,
      );
      final List<Object?> sentRepositories =
          rereadThroughWire(command.arguments[_repositoriesField])!
              as List<Object?>;

      expect(sentRepositories, hasLength(repositories.length));
      expect(sentRepositories.first, equals(sentRepositories.last));
      expect(sentRepositories, equals(expectedRepositoriesJson(repositories)));
    }
  });

  test('test_create_repository_command_arguments_property_'
      'nested_repository_is_fresh_on_every_read', () {
    final Random random = seededRandom(_nestedArgumentsSeed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Repository repository = randomHostileRepository(random);
      final CreateRepositoryCommand command = CreateRepositoryCommand(
        projectId: ProjectId(randomHostileText(random)),
        repository: repository,
      );
      final JsonObject firstRead =
          command.arguments[_repositoryField]! as JsonObject;
      firstRead['default_branch'] = randomHostileText(random);
      firstRead[_strayField] = randomText(random);
      firstRead.remove('address');

      expect(
        rereadThroughWire(command.arguments[_repositoryField]),
        equals(expectedRepositoryJson(repository)),
      );
    }
  });
}
