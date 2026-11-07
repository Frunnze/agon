import 'account_codec_rows.dart';
import 'approval_codec_rows.dart';
import 'catalog_codec_rows.dart';
import 'change_codec_rows.dart';
import 'codec_rows.dart';
import 'device_codec_rows.dart';
import 'item_draft_codec_rows.dart';
import 'live_run_codec_rows.dart';
import 'repository_file_codec_rows.dart';
import 'repository_preview_codec_rows.dart';
import 'run_codec_rows.dart';
import 'task_codec_rows.dart';
import 'workflow_codec_rows.dart';
import 'workspace_codec_rows.dart';

const List<ConstructorRow> allConstructorRows = <ConstructorRow>[
  ...accountConstructorRows,
  ...approvalConstructorRows,
  ...catalogConstructorRows,
  ...changeConstructorRows,
  ...deviceConstructorRows,
  ...itemDraftConstructorRows,
  ...liveRunConstructorRows,
  ...repositoryFileConstructorRows,
  ...repositoryPreviewConstructorRows,
  ...runConstructorRows,
  ...taskConstructorRows,
  ...workflowConstructorRows,
  ...workspaceConstructorRows,
];

const List<EncodableRow> encodableOnlyRows = <EncodableRow>[
  ...accountEncodableRows,
  ...approvalEncodableRows,
  ...catalogEncodableRows,
  ...changeEncodableRows,
  ...deviceEncodableRows,
  ...liveRunEncodableRows,
  ...taskEncodableRows,
  ...workflowEncodableRows,
  ...workspaceEncodableRows,
];

List<EncodableRow> listEveryEncodableRow() {
  final List<EncodableRow> rows = <EncodableRow>[...encodableOnlyRows];
  for (final ConstructorRow constructorRow in allConstructorRows) {
    rows.add(constructorRow.encodable);
  }
  return rows;
}
