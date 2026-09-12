import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../auth/application/auth_controller.dart';

class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.current,
    required this.lastUsedAt,
    required this.createdAt,
    this.deviceName,
    this.platform,
    this.ip,
  });

  factory ActiveSession.fromJson(Map<String, dynamic> json) => ActiveSession(
    id: json['id'] as String,
    current: json['current'] as bool? ?? false,
    deviceName: json['deviceName'] as String?,
    platform: json['platform'] as String?,
    ip: json['ip'] as String?,
    lastUsedAt: DateTime.parse(json['lastUsedAt'] as String).toLocal(),
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );

  final String id;
  final bool current;
  final String? deviceName;
  final String? platform;
  final String? ip;
  final DateTime lastUsedAt;
  final DateTime createdAt;
}

final activeSessionsProvider = FutureProvider.autoDispose<List<ActiveSession>>((
  ref,
) async {
  final list = await ref.watch(apiClientProvider).getList('/auth/sessions');
  return list.cast<Map<String, dynamic>>().map(ActiveSession.fromJson).toList();
});

/// Configuracoes da conta: dados, seguranca e sessoes em outros dispositivos.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final padding = context.windowSize.pagePadding;

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configurações',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppTokens.space4),
                const Text(
                  'Sua conta e segurança de acesso.',
                  style: TextStyle(color: AppColors.mutedInk),
                ),
                const SizedBox(height: AppTokens.space24),
                _Section(
                  title: 'Conta',
                  children: [
                    _InfoRow(label: 'Nome', value: user.displayName),
                    _InfoRow(label: 'E-mail', value: user.email),
                    _InfoRow(
                      label: 'Perfis de acesso',
                      value: user.roles.map(_roleLabel).join(', '),
                    ),
                    _InfoRow(label: 'Fuso horário', value: user.timezone),
                  ],
                ),
                const SizedBox(height: AppTokens.space16),
                _Section(
                  title: 'Segurança',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.password_rounded),
                      title: const Text('Alterar senha'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/settings/password'),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space16),
                const _SessionsSection(),
                const SizedBox(height: AppTokens.space16),
                _Section(
                  title: 'Sair',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Sair deste dispositivo'),
                      onTap: () =>
                          ref.read(authControllerProvider.notifier).logout(),
                    ),
                    ListTile(
                      leading: const Icon(
                        Icons.devices_other_rounded,
                        color: AppColors.alert,
                      ),
                      title: const Text(
                        'Sair de todos os dispositivos',
                        style: TextStyle(color: AppColors.alert),
                      ),
                      subtitle: const Text(
                        'Encerra todas as sessões, inclusive esta.',
                      ),
                      onTap: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Sair de todos os dispositivos?'),
                            content: const Text(
                              'Você precisará entrar novamente em cada aparelho.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancelar'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Sair de todos'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout(allDevices: true);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _roleLabel(String key) => switch (key) {
    'GLOBAL_ADMIN' => 'Administrador global',
    'NATIONAL_LEADER' => 'Líder nacional',
    'REGIONAL_LEADER' => 'Líder regional',
    'SUPERVISOR' => 'Supervisor',
    'PASTOR' => 'Pastor',
    'SECRETARY' => 'Secretaria',
    _ => key,
  };
}

class _SessionsSection extends ConsumerWidget {
  const _SessionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(activeSessionsProvider);
    final fmt = DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR');

    return _Section(
      title: 'Sessões ativas',
      children: [
        sessions.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppTokens.space24),
            child: AppLoadingState(),
          ),
          error: (e, _) => AppErrorState(
            onRetry: () => ref.invalidate(activeSessionsProvider),
          ),
          data: (items) => Column(
            children: [
              for (final s in items)
                ListTile(
                  leading: Icon(switch (s.platform) {
                    'ANDROID' => Icons.android_rounded,
                    'IOS' => Icons.phone_iphone_rounded,
                    _ => Icons.laptop_rounded,
                  }),
                  title: Text(s.deviceName ?? _platformLabel(s.platform)),
                  subtitle: Text(
                    'Último uso em ${fmt.format(s.lastUsedAt)}${s.ip != null ? ' · ${s.ip}' : ''}',
                  ),
                  trailing: s.current
                      ? const Chip(label: Text('Este dispositivo'))
                      : TextButton(
                          onPressed: () async {
                            try {
                              await ref
                                  .read(apiClientProvider)
                                  .delete('/auth/sessions/${s.id}');
                              ref.invalidate(activeSessionsProvider);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(errorMessage(e))),
                                );
                              }
                            }
                          },
                          child: const Text('Encerrar'),
                        ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static String _platformLabel(String? platform) => switch (platform) {
    'ANDROID' => 'Android',
    'IOS' => 'iPhone',
    'WEB' => 'Navegador',
    _ => 'Dispositivo',
  };
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.mutedInk),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
