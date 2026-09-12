import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pastoral_app/core/api/paginated.dart';
import 'package:pastoral_app/core/errors/app_failure.dart';
import 'package:pastoral_app/core/theme/app_theme.dart';
import 'package:pastoral_app/features/auth/application/auth_controller.dart';
import 'package:pastoral_app/features/auth/domain/auth_user.dart';
import 'package:pastoral_app/features/dashboard/data/dashboard_providers.dart';
import 'package:pastoral_app/features/dashboard/domain/dashboard_models.dart';
import 'package:pastoral_app/features/dashboard/presentation/dashboard_screen.dart';
import 'package:pastoral_app/features/network/domain/network_member.dart';
import 'package:pastoral_app/features/notifications/data/notifications_providers.dart';

import '../support/test_users.dart';

const _leader = LeaderDashboard(
  totalInNetwork: 42,
  activePastors: 40,
  directReports: 6,
  neverCared: 2,
  careOverdue30Days: 7,
  upcomingCareNext7Days: 3,
  careToday: 1,
  careThisWeek: 9,
  withoutCareOver30Days: 7,
  openRequests: 3,
  nextCare: [],
);

final _attention = Paginated<NetworkMember>(
  items: const [
    NetworkMember(
      id: 'p1',
      pastoralName: 'Pr. Marcos Lima',
      status: 'ACTIVE',
      neverCared: false,
      daysSinceLastCare: 63,
    ),
    NetworkMember(
      id: 'p2',
      pastoralName: 'Pra. Ana Souza',
      status: 'ACTIVE',
      neverCared: true,
    ),
  ],
  page: 1,
  pageSize: 5,
  total: 7,
  totalPages: 2,
  hasNext: true,
);

/// Riverpod nao permite sobrescrever o mesmo provider duas vezes:
/// o painel pessoal padrao so entra quando o teste nao fornece o seu.
Widget _app(
  AuthUser user,
  List overrides, {
  PastorDashboard pastor = const PastorDashboard(),
}) => ProviderScope(
  retry: (_, _) => null,
  overrides: [
    currentUserProvider.overrideWithValue(user),
    unreadNotificationsCountProvider.overrideWith((ref) async => 0),
    pastorDashboardProvider.overrideWith((ref) async => pastor),
    latestAnnouncementsProvider.overrideWith((ref) async => const []),
    careActivityProvider.overrideWith((ref) async => const []),
    countryDistributionProvider.overrideWith((ref) async => const []),
    ...overrides,
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    home: const Scaffold(body: DashboardScreen()),
  ),
);

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(
      1400,
      1600,
    );
    binding.platformDispatcher.views.first.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('lider ve indicadores factuais da rede', (tester) async {
    await tester.pumpWidget(
      _app(testUser(permissions: supervisorPermissions, firstName: 'Paulo'), [
        leaderDashboardProvider.overrideWith((ref) async => _leader),
        attentionPastorsProvider.overrideWith((ref) async => _attention),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Olá, Paulo'), findsOneWidget);
    expect(find.text('Pastores'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('63 dias sem acompanhamento'), findsOneWidget);
    expect(find.text('Nunca acompanhado'), findsOneWidget);
    expect(find.text('+5 na lista completa'), findsOneWidget);
    expect(find.textContaining('risco'), findsNothing);
  });

  testWidgets('falha em uma secao nao derruba as demais', (tester) async {
    await tester.pumpWidget(
      _app(testUser(permissions: supervisorPermissions), [
        leaderDashboardProvider.overrideWith(
          (ref) async => throw const AppFailure(kind: FailureKind.network),
        ),
        attentionPastorsProvider.overrideWith((ref) async => _attention),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tentar novamente'), findsWidgets);
    expect(find.text('Pr. Marcos Lima'), findsOneWidget);
  });

  testWidgets('pastor ve painel pessoal sem blocos de lideranca', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        testUser(),
        const [],
        pastor: PastorDashboard(
          nextEvent: EventRef(
            id: 'e1',
            title: 'Reunião com liderança',
            startsAt: DateTime.now().add(const Duration(days: 3)),
          ),
          church: const ChurchRef(
            id: 'c1',
            name: 'Igreja Belo Horizonte',
            city: 'Belo Horizonte',
          ),
          leadership: const PersonRef(id: 's1', name: 'Pr. Paulo Ribeiro'),
          openRequests: 2,
          trainingTotal: 4,
          trainingCompleted: 1,
          trainingProgressPct: 25,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reunião com liderança'), findsOneWidget);
    expect(find.text('Igreja Belo Horizonte'), findsOneWidget);
    expect(find.text('Pr. Paulo Ribeiro'), findsOneWidget);
    expect(find.text('25% concluída'), findsOneWidget);
    expect(find.text('Pastores na rede'), findsNothing);
    expect(find.text('Precisa de ajuda?'), findsOneWidget);
  });
}
