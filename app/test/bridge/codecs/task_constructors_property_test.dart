import 'support/codec_rows.dart';
import 'support/task_codec_rows.dart';

const int _firstSeed = 9390000;

void main() {
  testConstructorRows(rows: taskConstructorRows, firstSeed: _firstSeed);
}
