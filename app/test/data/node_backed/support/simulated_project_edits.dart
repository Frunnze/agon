import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';

import 'simulated_node_replies.dart';

const String _addressField = 'address';
const String _defaultBranchField = 'default_branch';
const String _repositoriesField = 'repositories';
const String _emptyBranchRefusal = 'the default branch cannot be empty';
const String _missingRepositoryRefusal =
    'the app server answered 404: the repository was not found';

typedef SimulatedRepository = Map<String, Object?>;

String canonicalizeSimulatedAddress(Object? address) {
  final String addressText = address! as String;
  final String? remoteAddress = parseRepositoryAddress(addressText);
  if (remoteAddress != null) {
    return remoteAddress;
  }

  final String trimmedAddress = addressText.trim();
  if (parseLocalFolderAddress(trimmedAddress) != null) {
    return trimmedAddress;
  }
  throw SimulatedNodeFailure('$addressText is not a repository address');
}

SimulatedRepository _checkRepository(Object? repository) {
  final SimulatedRepository given = repository! as SimulatedRepository;
  final String defaultBranch = (given[_defaultBranchField]! as String).trim();
  if (defaultBranch.isEmpty) {
    throw const SimulatedNodeFailure(_emptyBranchRefusal);
  }

  final SimulatedRepository checked = SimulatedRepository.of(given);
  checked[_addressField] = canonicalizeSimulatedAddress(given[_addressField]);
  checked[_defaultBranchField] = defaultBranch;
  return checked;
}

List<String> _listAddresses(Map<String, Object?> project) {
  final List<String> addresses = <String>[];
  for (final Object? repository
      in project[_repositoriesField]! as List<Object?>) {
    addresses.add(
      (repository! as SimulatedRepository)[_addressField]! as String,
    );
  }
  return addresses;
}

final class SimulatedProjectEdits {
  SimulatedProjectEdits({
    required this.projects,
    required this.nextIdentifier,
  });

  final List<Map<String, Object?>> projects;
  final String Function(String kind) nextIdentifier;

  Object? createProject(SimulatedCommand command) {
    final List<SimulatedRepository> repositories = <SimulatedRepository>[];
    final Set<String> seenAddresses = <String>{};
    for (final Object? repository
        in command[_repositoriesField]! as List<Object?>) {
      final SimulatedRepository checked = _checkRepository(repository);
      final String address = checked[_addressField]! as String;
      if (!seenAddresses.add(address)) {
        throw SimulatedNodeFailure('the project lists $address twice');
      }
      repositories.add(checked);
    }

    final Map<String, Object?> project = <String, Object?>{
      'id': nextIdentifier('project'),
      'workspace_id': command['workspace_id'],
      'name': command['name'],
      _repositoriesField: repositories,
      'approval_policy': command['approval_policy'],
    };
    projects.add(project);
    return project;
  }

  Object? createRepository(SimulatedCommand command) {
    final Map<String, Object?> project = _findProject(command);
    final SimulatedRepository checked = _checkRepository(
      command['repository'],
    );
    final String address = checked[_addressField]! as String;
    if (_listAddresses(project).contains(address)) {
      throw SimulatedNodeFailure(
        'the app server answered 409: the project already has $address',
      );
    }

    project[_repositoriesField] = <Object?>[
      ...project[_repositoriesField]! as List<Object?>,
      checked,
    ];
    return checked;
  }

  Object? removeRepository(SimulatedCommand command) {
    final Map<String, Object?> project = _findProject(command);
    final String address = canonicalizeSimulatedAddress(
      command[_addressField],
    );
    if (!_listAddresses(project).contains(address)) {
      throw const SimulatedNodeFailure(_missingRepositoryRefusal);
    }

    final List<Object?> remaining = <Object?>[];
    for (final Object? repository
        in project[_repositoriesField]! as List<Object?>) {
      final SimulatedRepository listed = repository! as SimulatedRepository;
      if (listed[_addressField] != address) {
        remaining.add(listed);
      }
    }
    project[_repositoriesField] = remaining;
    return remaining;
  }

  Map<String, Object?> _findProject(SimulatedCommand command) {
    return findSimulatedRecord(
      projects,
      kind: 'project',
      identifier: command['project_id'],
    );
  }
}
