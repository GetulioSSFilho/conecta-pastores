import 'package:flutter_test/flutter_test.dart';
import 'package:pastoral_app/app/shell/destinations.dart';

import '../support/test_users.dart';

void main() {
  List<String> paths(Iterable<AppDestination> items) =>
      items.map((d) => d.path).toList();

  test('pastor ve apenas areas pessoais', () {
    final visible = paths(destinationsFor(testUser()));
    expect(
      visible,
      containsAll([
        '/dashboard',
        '/channel',
        '/calendar',
        '/requests',
        '/training',
        '/documents',
        '/credential',
      ]),
    );
    expect(visible, isNot(contains('/network')));
    expect(visible, isNot(contains('/pastors')));
    expect(visible, isNot(contains('/care')));
    expect(visible, isNot(contains('/reports')));
    expect(visible, isNot(contains('/admin')));
  });

  test('supervisor ve rede, pastores e acompanhamentos', () {
    final visible = paths(
      destinationsFor(
        testUser(
          permissions: supervisorPermissions,
          roles: const ['SUPERVISOR'],
        ),
      ),
    );
    expect(visible, containsAll(['/network', '/pastors', '/care', '/reports']));
    expect(visible, isNot(contains('/admin')));
  });

  test('usuario sem pastor vinculado nao ve credencial', () {
    final visible = paths(destinationsFor(testUser(pastorId: null)));
    expect(visible, isNot(contains('/credential')));
  });

  test('bottom navigation tem no maximo 4 destinos e sempre o inicio', () {
    for (final user in [
      testUser(),
      testUser(permissions: supervisorPermissions),
    ]) {
      final compact = compactDestinationsFor(user);
      expect(compact.length, lessThanOrEqualTo(4));
      expect(compact.first.path, '/dashboard');
    }
  });

  test('destino casa com subrotas', () {
    final pastors = appDestinations.firstWhere((d) => d.path == '/pastors');
    expect(pastors.matches('/pastors/123'), isTrue);
    expect(pastors.matches('/pastorsx'), isFalse);
  });
}
