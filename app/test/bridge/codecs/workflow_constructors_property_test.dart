import 'support/codec_rows.dart';
import 'support/workflow_codec_rows.dart';

const int _firstSeed = 9410000;

void main() {
  testConstructorRows(rows: workflowConstructorRows, firstSeed: _firstSeed);
}
