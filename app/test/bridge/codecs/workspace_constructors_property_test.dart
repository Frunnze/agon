import 'support/codec_rows.dart';
import 'support/workspace_codec_rows.dart';

const int _firstSeed = 9420000;

void main() {
  testConstructorRows(rows: workspaceConstructorRows, firstSeed: _firstSeed);
}
