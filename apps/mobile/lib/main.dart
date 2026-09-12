import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URLs limpas (/pastors/123) em vez de /#/pastors/123.
  // Em producao o servidor web deve responder index.html para rotas desconhecidas.
  usePathUrlStrategy();
  await initializeDateFormatting('pt_BR');

  runApp(
    ProviderScope(
      // Riverpod 3 repete providers com erro automaticamente; aqui isso so
      // geraria chamadas extras em 401/403. Retry fica a cargo da tela.
      retry: (retryCount, error) => null,
      overrides: [authSessionExpiredOverride],
      child: const PastoralApp(),
    ),
  );
}

class PastoralApp extends ConsumerWidget {
  const PastoralApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Conecta Pastores',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => Consumer(
        builder: (context, ref, _) =>
            ref.watch(authControllerProvider) is AuthRestoring
            ? const AppSplashView()
            : child ?? const SizedBox.shrink(),
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
        Locale('es'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
