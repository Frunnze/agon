import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

List<TextSegment> describeRunSummary({
  required Run run,
  required Task task,
  required ProjectRepository projectRepository,
  required DateTime now,
}) {
  final String projectName = projectRepository.findProject(task.projectId).name;
  final String timing = describeRunTiming(run, now);

  return <TextSegment>[TextSegment('${task.title} · $projectName · $timing')];
}
