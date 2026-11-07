import 'support/codec_rows.dart';
import 'support/item_draft_codec_rows.dart';

const int _firstSeed = 9400000;

void main() {
  testConstructorRows(rows: itemDraftConstructorRows, firstSeed: _firstSeed);
}
