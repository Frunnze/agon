import 'support/change_codec_rows.dart';
import 'support/codec_rows.dart';

const int _firstSeed = 9330000;

void main() {
  testConstructorRows(rows: changeConstructorRows, firstSeed: _firstSeed);
}
