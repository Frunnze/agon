import 'support/codec_rows.dart';
import 'support/run_codec_rows.dart';

const int _firstSeed = 9380000;

void main() {
  testConstructorRows(rows: runConstructorRows, firstSeed: _firstSeed);
}
