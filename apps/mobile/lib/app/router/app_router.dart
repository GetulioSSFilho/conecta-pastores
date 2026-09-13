import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_brand.dart';
import '../../features/admin/presentation/admin_console_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/password_screens.dart';
import '../../features/care/presentation/care_form_screen.dart';
import '../../features/care/presentation/care_list_screen.dart';
import '../../features/channel/presentation/channel_feed_screen.dart';
import '../../features/channel/presentation/channel_post_screen.dart';
import '../../features/churches/presentation/church_detail_screen.dart';
import '../../features/churches/presentation/church_form_screen.dart';
import '../../features/churches/presentation/churches_list_screen.dart';
import '../../features/credentials/presentation/credential_card_screen.dart';
import '../../features/credentials/presentation/credential_scan_screen.dart';
import '../../features/credentials/presentation/credential_verify_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/documents/presentation/documents_list_screen.dart';
import '../../features/map/presentation/church_map_screen.dart';
import '../../features/network/presentation/my_network_screen.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/pastors/presentation/pastor_form_screen.dart';
import '../../features/pastors/presentation/pastor_directory_screen.dart';
import '../../features/profile/presentation/pastor_profile_screen.dart';
import '../../features/profile/presentation/demo_pastor_profile_screen.dart';
import '../../features/reports/presentation/reports_dashboard_screen.dart';
import '../../features/requests/presentation/request_detail_screen.dart';
import '../../features/requests/presentation/request_form_screen.dart';
import '../../features/requests/presentation/requests_list_screen.dart';
import '../../features/schedule/presentation/event_form_screen.dart';
import '../../features/schedule/presentation/schedule_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/training/presentation/training_catalog_screen.dart';
import '../../features/training/presentation/training_detail_screen.dart';
import '../shell/app_scaffold.dart';
import '../shell/more_screen.dart';

/// Rotas publicas: acessiveis sem sessao.
/// `/verify/:token` e o destino do QR Code da credencial - precisa abrir para
/// qualquer pessoa que confira o documento.
bool _isPublic(String path) =>
    path == '/login' ||
    path == '/reset-password' ||
    path.startsWith('/verify/');

/// Aceita apenas caminhos internos como destino pos-login (evita open redirect).
String? _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  if (from.startsWith('/login') || from.startsWith('/splash')) return null;
  return from;
}

final routerProvider = Provider<GoRouter>((ref) {
  // O roteador reavalia `redirect` sempre que o estado de autenticacao muda.
  final authChanges = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: authChanges,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final path = state.matchedLocation;
      final onAuthPages = path == '/login';
      // Destino original preservado no login (F5 em /pastors/123 volta para la).
      final from = onAuthPages
          ? state.uri.queryParameters['from']
          : state.uri.toString();

      switch (auth) {
        case AuthRestoring():
          // Nao redireciona: a URL fica intacta e o splash e sobreposto em
          // PastoralApp.builder. Redirecionar para /splash criava entradas no
          // historico do navegador e prendia o botao "voltar".
          return null;
        case AuthSignedOut():
          if (_isPublic(path)) return null;
          final target = _safeFrom(from);
          return Uri(
            path: '/login',
            queryParameters: target == null ? null : {'from': target},
          ).toString();
        case AuthSignedIn(:final user):
          if (user.mustChangePassword && path != '/settings/password') {
            return '/settings/password';
          }
          if (onAuthPages) return _safeFrom(from) ?? '/dashboard';
          return null;
      }
    },
    errorBuilder: (context, state) => const _NotFoundScreen(),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/dashboard'),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) =>
            ResetPasswordScreen(token: state.uri.queryParameters['token']),
      ),
      // Fora do shell: pagina publica aberta pelo QR Code da credencial.
      GoRoute(
        path: '/verify/:token',
        builder: (_, state) =>
            CredentialVerifyScreen(token: state.pathParameters['token']!),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppScaffold(location: state.uri.path, child: child),
        routes: [
          _page('/dashboard', (context, state) => const DashboardScreen()),
          _page('/network', (context, state) => const MyNetworkScreen()),
          _page('/pastors', (context, state) => const PastorDirectoryScreen()),
          _page('/pastors/new', (context, state) => const PastorFormScreen()),
          _page('/pastors/:id', (context, state) {
            final id = state.pathParameters['id']!;
            final query = state.uri.queryParameters;
            if (query['demo'] == '1') {
              return DemoPastorProfileScreen(
                pastorId: id,
                name: query['name'] ?? 'Pastor',
                detail: query['detail'] ?? 'Perfil de demonstração',
                image: query['image'],
              );
            }
            return PastorProfileScreen(pastorId: id);
          }),
          _page('/churches', (context, state) => const ChurchesListScreen()),
          _page('/churches/new', (context, state) => const ChurchFormScreen()),
          _page(
            '/churches/:id',
            (context, state) =>
                ChurchDetailScreen(churchId: state.pathParameters['id']!),
          ),
          _page('/care', (context, state) => const CareListScreen()),
          _page(
            '/care/new',
            (context, state) => CareFormScreen(
              initialPastorId: state.uri.queryParameters['pastorId'],
            ),
          ),
          _page('/channel', (context, state) => const ChannelFeedScreen()),
          _page(
            '/channel/:id',
            (context, state) =>
                ChannelPostScreen(postId: state.pathParameters['id']!),
          ),
          _page('/calendar', (context, state) => const ScheduleScreen()),
          _page(
            '/calendar/new',
            (context, state) => EventFormScreen(
              initialPastorId: state.uri.queryParameters['pastorId'],
            ),
          ),
          _page('/requests', (context, state) => const RequestsListScreen()),
          _page('/requests/new', (context, state) => const RequestFormScreen()),
          _page(
            '/requests/:id',
            (context, state) =>
                RequestDetailScreen(requestId: state.pathParameters['id']!),
          ),
          _page('/training', (context, state) => const TrainingCatalogScreen()),
          _page(
            '/training/:id',
            (context, state) =>
                TrainingDetailScreen(trainingId: state.pathParameters['id']!),
          ),
          _page('/documents', (context, state) => const DocumentsListScreen()),
          _page(
            '/credential',
            (context, state) => const CredentialCardScreen(),
          ),
          _page(
            '/credential/scan',
            (context, state) => const CredentialScanScreen(),
          ),
          _page('/map', (context, state) => const ChurchMapScreen()),
          _page('/reports', (context, state) => const ReportsDashboardScreen()),
          _page('/admin', (context, state) => const AdminConsoleScreen()),
          _page(
            '/notifications',
            (context, state) => const NotificationCenterScreen(),
          ),
          // Meu perfil = Perfil 360 do pastor vinculado ao usuario.
          GoRoute(
            path: '/profile',
            redirect: (_, _) {
              final pastorId = ref.read(currentUserProvider)?.pastorId;
              return pastorId == null ? '/settings' : '/pastors/$pastorId';
            },
          ),
          _page('/settings', (context, state) => const SettingsScreen()),
          _page(
            '/settings/password',
            (context, state) => const ChangePasswordScreen(),
          ),
          _page('/more', (context, state) => const MoreScreen()),
        ],
      ),
    ],
  );
});

/// Paginas de nivel superior trocam sem animacao (comportamento de app web).
GoRoute _page(
  String path,
  Widget Function(BuildContext, GoRouterState) builder,
) => GoRoute(
  path: path,
  pageBuilder: (context, state) =>
      NoTransitionPage(key: state.pageKey, child: builder(context, state)),
);

/// Exibido sobre qualquer rota enquanto a sessao salva e revalidada.
class AppSplashView extends StatelessWidget {
  const AppSplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBrandMark(size: 72, color: Colors.white),
            SizedBox(height: 24),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.explore_off_outlined,
                size: 56,
                color: AppColors.mutedInk,
              ),
              const SizedBox(height: 16),
              Text(
                'Página não encontrada',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'O endereço pode estar incorreto ou a página foi removida.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/dashboard'),
                child: const Text('Ir para o início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
