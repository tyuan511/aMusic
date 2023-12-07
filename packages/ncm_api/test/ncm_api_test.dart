import 'package:flutter_test/flutter_test.dart';
import 'package:ncm_api/ncm_api.dart';

void main() {
  test('apitest', () async {
    await init(cookiePath: './cookies');
  });
}
