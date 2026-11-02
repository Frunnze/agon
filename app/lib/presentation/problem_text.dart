import 'package:agent_orchestration/data/repository/explained_problem.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

String? describeProblemForPeople(Object problem) {
  if (problem is ExplainedProblem) {
    return problem.explanation;
  }
  if (problem is RecordNotFound) {
    return problem.toString();
  }
  if (problem is RangeError) {
    return null;
  }
  if (problem is ArgumentError) {
    return '${problem.message}';
  }
  if (problem is StateError) {
    return problem.message;
  }
  return null;
}
