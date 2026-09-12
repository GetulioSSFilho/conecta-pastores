import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/admin_providers.dart';
import '../domain/admin_models.dart';

/// Administração: contas de acesso, papéis e trilha de auditoria.
///
/// Quem decide o que aparece é a API: cada aba consulta seu endpoint e o bloco
/// some quando o servidor responde 403.
class AdminConsoleScreen extends ConsumerStatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  ConsumerState<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends ConsumerState<AdminConsoleScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administração',
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Contas, papéis e registro de atividades',
                    style: TextStyle(color: AppColors.mutedInk),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final (index, label) in const [
                          (0, 'Usuários'),
                          (1, 'Papéis e permissões'),
                          (2, 'Auditoria'),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: AppTokens.space8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: _tab == index,
                              onSelected: (_) => setState(() => _tab = index),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (_tab) {
                0 => const _UsersTab(),
                1 => const _RolesTab(),
                _ => const _AuditTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(userQueryProvider.notifier).update((q) => q.copyWith(search: value.trim()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final query = ref.watch(userQueryProvider);
    final notifier = ref.read(userQueryProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, AppTokens.space16, padding, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Buscar por nome ou e-mail',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: AppTokens.space12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Todos'),
                      selected: query.status == null,
                      onSelected: (_) => notifier.update((q) => q.copyWith(status: () => null)),
                    ),
                    for (final status in AccountStatus.values) ...[
                      const SizedBox(width: AppTokens.space8),
                      ChoiceChip(
                        label: Text(status.label),
                        selected: query.status == status,
                        onSelected: (selected) => notifier.update(
                          (q) => q.copyWith(status: () => selected ? status : null),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: PagedListView(
            value: ref.watch(adminUsersProvider),
            padding: EdgeInsets.fromLTRB(padding, AppTokens.space16, padding, AppTokens.space32),
            onLoadMore: () => ref.read(adminUsersProvider.notifier).loadMore(),
            onRetry: () => ref.invalidate(adminUsersProvider),
            onRefresh: () async => ref.invalidate(adminUsersProvider),
            empty: InlineEmpty(
              icon: query.hasFilters ? Icons.filter_alt_off_outlined : Icons.person_off_outlined,
              message: query.hasFilters
                  ? 'Nenhuma conta com esses filtros.'
                  : 'Nenhuma conta de acesso visível para você.',
              action: query.hasFilters
                  ? TextButton(
                      onPressed: () {
                        _search.clear();
                        notifier.set(const UserQuery());
                      },
                      child: const Text('Limpar filtros'),
                    )
                  : null,
            ),
            itemBuilder: (context, user) => _UserCard(user: user),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          PersonAvatar(name: user.fullName, size: 40),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final role in user.roles)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.softPrimary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          role.name,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (user.mustChangePassword)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Troca de senha pendente',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                user.status.label,
                style: TextStyle(
                  color: user.status.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.lastLoginAt == null
                    ? 'Nunca acessou'
                    : 'Acesso em ${Formatters.date(user.lastLoginAt!)}',
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RolesTab extends ConsumerWidget {
  const _RolesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.windowSize.pagePadding;

    return AsyncValueView(
      value: ref.watch(adminRolesProvider),
      forbidden: const Padding(
        padding: EdgeInsets.all(AppTokens.space16),
        child: NoAccessNotice(
          message: 'Só quem administra papéis e permissões vê esta lista.',
        ),
      ),
      onRetry: () => ref.invalidate(adminRolesProvider),
      loading: const Padding(
        padding: EdgeInsets.all(AppTokens.space16),
        child: SkeletonCard(lines: 5),
      ),
      data: (roles) => ListView(
        padding: EdgeInsets.fromLTRB(padding, AppTokens.space16, padding, AppTokens.space32),
        children: [
          for (final role in roles)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          role.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (role.isSystem)
                        const Padding(
                          padding: EdgeInsets.only(right: AppTokens.space8),
                          child: Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.mutedInk),
                        ),
                      Text(
                        '${role.permissions.length} permissões',
                        style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${role.key} · nível ${role.rank}',
                    style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppTokens.space16,
                    0,
                    AppTokens.space16,
                    AppTokens.space16,
                  ),
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final permission in role.permissions)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              permission,
                              style: const TextStyle(fontSize: 11, color: AppColors.ink),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuditTab extends ConsumerWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.windowSize.pagePadding;
    final filter = ref.watch(auditFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(padding, AppTokens.space16, padding, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tudo'),
                  selected: filter == null,
                  onSelected: (_) => ref.read(auditFilterProvider.notifier).set(null),
                ),
                for (final action in const [
                  'LOGIN',
                  'CREATE',
                  'UPDATE',
                  'DELETE',
                  'READ_CONFIDENTIAL',
                ]) ...[
                  const SizedBox(width: AppTokens.space8),
                  ChoiceChip(
                    label: Text(
                      AuditEntry(
                        id: '',
                        action: action,
                        entity: '',
                        createdAt: DateTime.now(),
                      ).actionLabel,
                    ),
                    selected: filter == action,
                    onSelected: (selected) =>
                        ref.read(auditFilterProvider.notifier).set(selected ? action : null),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: PagedListView(
            value: ref.watch(auditProvider),
            padding: EdgeInsets.fromLTRB(padding, AppTokens.space16, padding, AppTokens.space32),
            onLoadMore: () => ref.read(auditProvider.notifier).loadMore(),
            onRetry: () => ref.invalidate(auditProvider),
            onRefresh: () async => ref.invalidate(auditProvider),
            empty: const InlineEmpty(
              icon: Icons.history_toggle_off_rounded,
              message: 'Nenhum registro de auditoria.',
            ),
            itemBuilder: (context, entry) => AppCard(
              child: Row(
                children: [
                  Icon(entry.icon, color: entry.actionColor, size: 20),
                  const SizedBox(width: AppTokens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${entry.actionLabel} · ${entry.entity}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            ?entry.authorName ?? entry.authorEmail,
                            if (entry.ip != null) 'IP ${entry.ip}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  Text(
                    '${Formatters.date(entry.createdAt)} ${Formatters.time(entry.createdAt)}',
                    style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
