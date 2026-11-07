import '../support/random_run_json.dart';
import '../support/random_work_json.dart';
import 'support/library_and_live_reply_properties.dart';

const int _firstObjectReplySeed = 7363000;
const int _firstListReplySeed = 7364000;

const List<String> _taskReplyFields = <String>[
  'id',
  'title',
  'details',
  'project_id',
  'doer',
  'runs_on',
  'agent_place',
  'skills',
  'uses_automatic_skills',
  'status',
  'created_at',
];

const List<ReplyRow> _objectReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'list_tasks_command',
    commandName: 'list_tasks',
    buildObjectJson: randomTasksViewJson,
    requiredFields: <String>['summary', 'summary_text', 'tasks'],
  ),
  ReplyRow(
    typeName: 'create_task_command',
    commandName: 'create_task',
    buildObjectJson: randomTaskJson,
    requiredFields: _taskReplyFields,
  ),
  ReplyRow(
    typeName: 'update_task_command',
    commandName: 'update_task',
    buildObjectJson: randomTaskJson,
    requiredFields: _taskReplyFields,
  ),
  ReplyRow(
    typeName: 'create_job_command',
    commandName: 'create_job',
    buildObjectJson: randomTaskJson,
    requiredFields: _taskReplyFields,
  ),
  ReplyRow(
    typeName: 'update_job_command',
    commandName: 'update_job',
    buildObjectJson: randomTaskJson,
    requiredFields: _taskReplyFields,
  ),
  ReplyRow(
    typeName: 'start_task_command',
    commandName: 'start_task',
    buildObjectJson: randomRunJson,
    requiredFields: <String>[
      'id',
      'task_id',
      'number',
      'status',
      'steps',
      'log',
      'chat',
      'link',
      'started_by',
      'started_at',
    ],
  ),
];

const List<ReplyRow> _listReplyRows = <ReplyRow>[
  ReplyRow(
    typeName: 'list_jobs_command',
    commandName: 'list_jobs',
    buildObjectJson: randomJobViewJson,
    requiredFields: <String>[
      'task',
      'project_name',
      'schedule_description',
      'next_run_at',
    ],
  ),
];

void main() {
  testObjectReplyRows(_objectReplyRows, _firstObjectReplySeed);
  testListReplyRows(_listReplyRows, _firstListReplySeed);
}
