import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/notifications/data/notifications_providers.dart';
import 'destinations.dart';

/// "Mais" do celular: todos os destinos que nao cabem na bottom navigation.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final primary = compactDestinationsFor(user);
    final others = destinationsFor(
      user,
    ).where((d) => !primary.contains(d)).toList();
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;

    return ListView(
      padding: const EdgeInsets.all(AppTokens.space16),
      children: [
        AppCard(
          onTap: user.pastorId != null ? () => context.go('/profile') : null,
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.softPrimary,
                foregroundImage: user.avatarUrl != null
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      user.email,
                      style: const TextStyle(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
              if (user.pastorId != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.mutedInk,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                title: const Text('Notificações'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/notifications'),
              ),
              for (final d in others)
                ListTile(
                  leading: Icon(d.icon),
                  title: Text(d.label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.go(d.path),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space16),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Configurações'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go('/settings'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.alert,
                ),
                title: const Text(
                  'Sair',
                  style: TextStyle(color: AppColors.alert),
                ),
                onTap: () => ref.read(authControllerProvider.notifier).logout(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
