import 'support/account_codec_rows.dart';
import 'support/codec_rows.dart';

const int _firstSeed = 9310000;

void main() {
  testConstructorRows(rows: accountConstructorRows, firstSeed: _firstSeed);
}
