import 'support/codec_rows.dart';
import 'support/live_run_codec_rows.dart';

const int _firstSeed = 9370000;

void main() {
  testConstructorRows(rows: liveRunConstructorRows, firstSeed: _firstSeed);
}
