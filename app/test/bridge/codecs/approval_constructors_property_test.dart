import 'support/approval_codec_rows.dart';
import 'support/codec_rows.dart';

const int _firstSeed = 9320000;

void main() {
  testConstructorRows(rows: approvalConstructorRows, firstSeed: _firstSeed);
}
