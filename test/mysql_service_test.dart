import 'package:flutter_test/flutter_test.dart';
import 'package:sikunjung/services/mysql_service.dart';

void main() {
  test('MySqlConfig defaults to sikunjung_db on localhost 3306', () {
    const config = MySqlConfig();
    expect(config.host, equals('127.0.0.1'));
    expect(config.port, equals(3306));
    expect(config.user, equals('root'));
    expect(config.password, equals(''));
    expect(config.db, equals('sikunjung_db'));
  });

  test('MySqlService singleton instance exists', () {
    final service = MySqlService.instance;
    expect(service, isNotNull);
    expect(service.isConnected, isFalse);
  });
}

