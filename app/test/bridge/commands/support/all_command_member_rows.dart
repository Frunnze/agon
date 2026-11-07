import 'account_command_member_rows.dart';
import 'command_member_row.dart';
import 'device_command_member_rows.dart';

const List<CommandMemberRow> fieldlessCommandRows = <CommandMemberRow>[
  ...accountFieldlessCommandRows,
  ...deviceFieldlessCommandRows,
];

const List<CommandMemberRow> allCommandMemberRows = <CommandMemberRow>[
  ...fieldlessCommandRows,
  ...accountFieldCommandRows,
  ...deviceFieldCommandRows,
];
