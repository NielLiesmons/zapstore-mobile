import 'package:flutter_test/flutter_test.dart';
import 'package:zapstore/utils/nostr_query_id.dart';

void main() {
  test('normalizeNostrQueryId accepts hex event ids', () {
    final id = 'a' * 64;
    expect(normalizeNostrQueryId(id), id);
  });

  test('normalizeNostrQueryId accepts replaceable coordinates', () {
    const coord =
        '32267:726a1e261cc6474674e8285e3951b3bb139be9a773d1acf49dc868db861a1c11:myapp';
    expect(normalizeNostrQueryId(coord), coord);
  });

  test('normalizeNostrQueryId rejects bare relay hints and garbage', () {
    expect(normalizeNostrQueryId('wss://relay.example.com'), isNull);
    expect(normalizeNostrQueryId('not-a-valid-id'), isNull);
    expect(normalizeNostrQueryId(''), isNull);
  });
}
