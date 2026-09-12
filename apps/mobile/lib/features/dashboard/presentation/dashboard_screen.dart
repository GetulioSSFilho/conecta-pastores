import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../channel/domain/channel_post.dart';
import '../../notifications/data/notifications_providers.dart';
import '../../network/presentation/my_network_screen.dart';
import '../data/dashboard_providers.dart';
import '../domain/dashboard_models.dart';

/// Inicio da aplicacao.
///
/// Lider: foco na rede (quem precisa de cuidado, proximos acompanhamentos, tendencias).
/// Pastor: foco pessoal (proximo compromisso, comunicados, meu ministerio, ajuda).
/// Todos os numeros vem da API ja filtrados pelo escopo do usuario.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final size = context.windowSize;

    final sections = <Widget>[
      _Greeting(user: user, showActions: size.isCompact),
      ...switch (_dashboardRole(user)) {
        _DashboardRole.president => _adminSections(size),
        _DashboardRole.manager => _managerSections(size),
        _DashboardRole.leader => _leaderSections(size),
        _DashboardRole.pastor => _pastorSections(size, user),
      },
    ];

    return RefreshIndicator(
      onRefresh: () async {
        refreshDashboard(ref);
        ref.invalidate(unreadNotificationsCountProvider);
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          size.pagePadding,
          size.pagePadding,
          size.pagePadding,
          AppTokens.space32,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < sections.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppTokens.space24),
                    sections[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _leaderSections(WindowSize size) => [
    const _LeaderMetrics(),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _UpcomingCareSection(),
      right: const _AttentionSection(),
    ),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _CareActivitySection(),
      right: const _CountriesSection(),
    ),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _NextCommitmentSection(),
      right: const _AnnouncementsSection(),
    ),
  ];

  List<Widget> _adminSections(WindowSize size) => [
    const _AdminTreePreview(),
    const _AdminKpis(includeGlobal: true),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _AdminInsights(),
      right: const _CareActivitySection(),
    ),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _AttentionSection(),
      right: const _CountriesSection(),
    ),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _AnnouncementsSection(),
      right: const _NextCommitmentSection(),
    ),
  ];

  List<Widget> _managerSections(WindowSize size) => [
    const _AdminTreePreview(),
    const _AdminKpis(includeGlobal: false),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _AdminInsights(),
      right: const _CareActivitySection(),
    ),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _AttentionSection(),
      right: const _CountriesSection(),
    ),
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _AnnouncementsSection(),
      right: const _NextCommitmentSection(),
    ),
  ];

  // Ordem do desenho: o compromisso mais proximo, o que a lideranca comunicou,
  // os atalhos do proprio ministerio e, por fim, como pedir ajuda.
  List<Widget> _pastorSections(WindowSize size, AuthUser user) => [
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _NextCommitmentSection(),
      right: const _AnnouncementsSection(),
    ),
    const _MinistrySection(),
    const _HelpCard(),
  ];
}

// -----------------------------------------------------------------------------
// Layout
// -----------------------------------------------------------------------------

class _TwoColumns extends StatelessWidget {
  const _TwoColumns({
    required this.enabled,
    required this.left,
    required this.right,
  });

  final bool enabled;
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          left,
          const SizedBox(height: AppTokens.space24),
          right,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: AppTokens.space16),
        Expanded(child: right),
      ],
    );
  }
}

class _Greeting extends ConsumerWidget {
  const _Greeting({required this.user, required this.showActions});

  final AuthUser user;
  final bool showActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsCountProvider).value ?? 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.isLeader
                    ? 'Olá, ${user.firstName}'
                    : 'Olá, ${user.firstName} 👋',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              Text(
                user.isLeader
                    ? 'Aqui está um resumo da sua rede.'
                    : 'Que bom te ver por aqui!',
                style: const TextStyle(color: AppColors.mutedInk),
              ),
            ],
          ),
        ),
        if (showActions) ...[
          IconButton(
            tooltip: 'Notificações',
            onPressed: () => context.go('/notifications'),
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          IconButton(
            tooltip: 'Minha conta',
            onPressed: () => context.go('/more'),
            icon: PersonAvatar(
              name: user.displayName,
              photoUrl: user.avatarUrl,
              size: 36,
            ),
          ),
        ],
      ],
    );
  }
}

class _MetricData {
  const _MetricData(
    this.value,
    this.label,
    this.icon,
    this.color,
    this.valueColor,
    this.path,
  );

  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color valueColor;
  final String path;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricData> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? math.min(items.length, 6)
            : constraints.maxWidth >= 600
            ? 3
            : 2;
        const gap = AppTokens.space12;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: MetricCard(
                  value: item.value,
                  label: item.label,
                  icon: item.icon,
                  color: item.color,
                  valueColor: item.valueColor,
                  onTap: () => context.go(item.path),
                ),
              ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Lider
// -----------------------------------------------------------------------------

// ignore: unused_element
class _AdminHero extends StatelessWidget {
  const _AdminHero({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final compact = context.windowSize.isCompact;
    final role = _dashboardRole(user);
    final roleLabel = switch (role) {
      _DashboardRole.president => 'PAINEL DA PRESID\u00caNCIA',
      _DashboardRole.manager => 'PAINEL DE GEST\u00c3O DE L\u00cdDERES',
      _DashboardRole.leader => 'PAINEL DO L\u00cdDER DE PASTORES',
      _DashboardRole.pastor => 'PAINEL PASTORAL',
    };
    final title = switch (role) {
      _DashboardRole.president => 'Vis\u00e3o global da rede',
      _DashboardRole.manager => 'Vis\u00e3o da lideran\u00e7a',
      _DashboardRole.leader => 'Minha equipe pastoral',
      _DashboardRole.pastor => 'Meu minist\u00e9rio',
    };
    final description = switch (role) {
      _DashboardRole.president =>
        'Acompanhe a sa\u00fade e o crescimento de toda a rede em um s\u00f3 lugar.',
      _DashboardRole.manager =>
        'Acompanhe gestores, l\u00edderes e pastores dentro do seu escopo.',
      _DashboardRole.leader =>
        'Cuide das pessoas, acompanhe os pr\u00f3ximos passos e fortale\u00e7a sua equipe.',
      _DashboardRole.pastor =>
        'Organize seus compromissos e mantenha seu cuidado pastoral em dia.',
    };
    return Container(
      padding: const EdgeInsets.all(AppTokens.space24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF176B75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTokens.radius24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Flex(
        direction: compact ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: compact ? 0 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space8,
                    vertical: AppTokens.space4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppTokens.pill),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppTokens.space4),
                Text(
                  'Ol\u00e1, ${user.firstName}. $description',
                  style: const TextStyle(color: Colors.white70, height: 1.35),
                ),
              ],
            ),
          ),
          SizedBox(
            width: compact ? 0 : AppTokens.space24,
            height: compact ? AppTokens.space16 : 0,
          ),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/network'),
                icon: const Icon(Icons.account_tree_outlined, size: 18),
                label: const Text('Ver organograma'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space12,
                    vertical: AppTokens.space12,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => context.go('/pastors/new'),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('Novo pastor'),
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space12,
                    vertical: AppTokens.space12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DashboardRole { pastor, leader, manager, president }

_DashboardRole _dashboardRole(AuthUser user) {
  if (user.roles.contains('GLOBAL_ADMIN')) return _DashboardRole.president;
  if (user.roles.contains('NATIONAL_LEADER') ||
      user.roles.contains('REGIONAL_LEADER')) {
    return _DashboardRole.manager;
  }
  if (user.roles.contains('SUPERVISOR') || user.isLeader) {
    return _DashboardRole.leader;
  }
  return _DashboardRole.pastor;
}

class _AdminKpis extends ConsumerWidget {
  const _AdminKpis({required this.includeGlobal});

  final bool includeGlobal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!includeGlobal) {
      return AsyncValueView(
        value: ref.watch(leaderDashboardProvider),
        onRetry: () => ref.invalidate(leaderDashboardProvider),
        loading: const Skeleton(height: 112, radius: AppTokens.radius16),
        data: (leader) => _buildKpis(context, leader, null),
      );
    }
    return AsyncValueView(
      value: ref.watch(globalDashboardProvider),
      onRetry: () => ref.invalidate(globalDashboardProvider),
      loading: const Skeleton(height: 112, radius: AppTokens.radius16),
      data: (global) => AsyncValueView(
        value: ref.watch(leaderDashboardProvider),
        onRetry: () => ref.invalidate(leaderDashboardProvider),
        loading: const Skeleton(height: 112, radius: AppTokens.radius16),
        data: (leader) => _buildKpis(context, leader, global),
      ),
    );
  }

  Widget _buildKpis(
    BuildContext context,
    LeaderDashboard leader,
    GlobalDashboard? global,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 520
            ? 2
            : 1;
        final gap = AppTokens.space12;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final items = [
          _AdminKpiData(
            value: '${global?.totalPastors ?? leader.totalInNetwork}',
            label: global == null ? 'Pastores na rede' : 'Pastores cadastrados',
            detail: global == null
                ? '${leader.directReports} sob sua lideran\u00e7a direta'
                : '${global.activePastors} ativos na rede',
            icon: Icons.groups_rounded,
            color: AppColors.softPrimary,
            path: '/pastors',
          ),
          _AdminKpiData(
            value: global == null
                ? '${leader.activePastors}'
                : '${global.totalChurches}',
            label: global == null ? 'Pastores ativos' : 'Igrejas conectadas',
            detail: global == null
                ? 'dentro do seu escopo'
                : '${global.countries} pa\u00edses alcan\u00e7ados',
            icon: global == null
                ? Icons.verified_user_outlined
                : Icons.church_rounded,
            color: AppColors.softBlue,
            path: global == null ? '/network' : '/churches',
          ),
          _AdminKpiData(
            value: '${leader.withoutCareOver30Days}',
            label: 'Precisam de cuidado',
            detail: 'h\u00e1 mais de 30 dias',
            icon: Icons.favorite_border_rounded,
            color: const Color(0xFFFFF1E5),
            valueColor: AppColors.accent,
            path: '/network?careOverdueDays=30',
          ),
          _AdminKpiData(
            value: global == null
                ? '${leader.upcomingCareNext7Days}'
                : '${global.newPastors}',
            label: global == null
                ? 'Pr\u00f3ximos 7 dias'
                : 'Novos este m\u00eas',
            detail: global == null
                ? '${leader.openRequests} solicita\u00e7\u00f5es em aberto'
                : '${leader.openRequests} solicita\u00e7\u00f5es em aberto',
            icon: global == null
                ? Icons.event_available_rounded
                : Icons.trending_up_rounded,
            color: const Color(0xFFEAF8F0),
            valueColor: AppColors.success,
            path: global == null ? '/calendar' : '/pastors',
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _AdminKpiCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _AdminKpiData {
  const _AdminKpiData({
    required this.value,
    required this.label,
    required this.detail,
    required this.icon,
    required this.color,
    required this.path,
    this.valueColor = AppColors.primary,
  });

  final String value;
  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  final Color valueColor;
  final String path;
}

class _AdminKpiCard extends StatelessWidget {
  const _AdminKpiCard({required this.item});

  final _AdminKpiData item;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: item.color,
      onTap: () => context.go(item.path),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: 10,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(AppTokens.radius8),
            ),
            child: Icon(item.icon, color: item.valueColor, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.value,
                      style: TextStyle(
                        color: item.valueColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space8),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.mutedInk,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTokens.space8),
          const Icon(
            Icons.arrow_outward_rounded,
            color: AppColors.mutedInk,
            size: 16,
          ),
        ],
      ),
    );
  }
}

class _AdminTreePreview extends StatelessWidget {
  const _AdminTreePreview();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space16,
        AppTokens.space16,
        AppTokens.space8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Organograma da rede',
            actionLabel: 'Abrir rede',
            onAction: () => context.go('/network?view=tree'),
          ),
          const SizedBox(height: AppTokens.space8),
          const NetworkTreeOrganogram(),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _AdminOrganogram extends ConsumerWidget {
  const _AdminOrganogram();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Organograma da rede',
            actionLabel: 'Abrir rede',
            onAction: () => context.go('/network'),
          ),
          const SizedBox(height: AppTokens.space4),
          const Text(
            'Uma leitura r\u00e1pida da estrutura de lideran\u00e7a.',
            style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
          const SizedBox(height: AppTokens.space16),
          AsyncValueView(
            value: ref.watch(leaderDashboardProvider),
            onRetry: () => ref.invalidate(leaderDashboardProvider),
            loading: const Skeleton(height: 150),
            data: (d) {
              final user = ref.watch(currentUserProvider);
              final president = user?.roles.contains('GLOBAL_ADMIN') ?? false;
              final nodes = [
                _OrgNode(
                  title: president ? 'Presidente' : 'Gestor de l\u00edderes',
                  detail: president
                      ? 'Vis\u00e3o global da igreja'
                      : 'Gest\u00e3o do seu escopo',
                  icon: president
                      ? Icons.stars_rounded
                      : Icons.manage_accounts_rounded,
                  color: AppColors.primary,
                  foreground: Colors.white,
                ),
                if (president)
                  const _OrgNode(
                    title: 'Gestor de l\u00edderes',
                    detail: 'Vis\u00e3o nacional ou regional',
                    icon: Icons.public_rounded,
                    color: AppColors.softPrimary,
                  ),
                _OrgNode(
                  title: 'L\u00edder de pastores',
                  detail: '${d.directReports} lideran\u00e7as diretas',
                  icon: Icons.hub_outlined,
                  color: AppColors.softBlue,
                ),
                _OrgNode(
                  title: 'Pastores',
                  detail:
                      '${d.activePastors} ativos · ${d.withoutCareOver30Days} em aten\u00e7\u00e3o',
                  icon: Icons.groups_outlined,
                  color: AppColors.softPurple,
                ),
              ];
              return Column(
                children: [
                  for (var i = 0; i < nodes.length; i++) ...[
                    nodes[i],
                    if (i < nodes.length - 1)
                      Container(
                        width: 2,
                        height: 16,
                        color: AppColors.secondary.withValues(alpha: 0.5),
                      ),
                  ],
                  const SizedBox(height: AppTokens.space16),
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.mutedInk,
                      ),
                      const SizedBox(width: AppTokens.space8),
                      Expanded(
                        child: Text(
                          '${d.upcomingCareNext7Days} acompanhamentos previstos nos pr\u00f3ximos 7 dias',
                          style: const TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrgNode extends StatelessWidget {
  const _OrgNode({
    required this.title,
    required this.detail,
    required this.icon,
    required this.color,
    this.foreground = AppColors.primary,
  });

  final String title;
  final String detail;
  final IconData icon;
  final Color color;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppTokens.space12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        border: Border.all(color: foreground.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(height: AppTokens.space8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground.withValues(alpha: 0.72),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminInsights extends ConsumerWidget {
  const _AdminInsights();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Insights para hoje'),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: ref.watch(leaderDashboardProvider),
            onRetry: () => ref.invalidate(leaderDashboardProvider),
            loading: const _ListSkeleton(),
            data: (d) => Column(
              children: [
                _InsightTile(
                  icon: Icons.favorite_rounded,
                  color: AppColors.alert,
                  title: d.withoutCareOver30Days == 0
                      ? 'Cuidado pastoral em dia'
                      : '${d.withoutCareOver30Days} pastores pedem aten\u00e7\u00e3o',
                  detail: d.withoutCareOver30Days == 0
                      ? 'Nenhuma pessoa passou de 30 dias sem acompanhamento.'
                      : 'Priorize a lista de acompanhamento desta semana.',
                  onTap: () => context.go('/network?careOverdueDays=30'),
                ),
                _InsightTile(
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.secondary,
                  title: '${d.upcomingCareNext7Days} compromissos na agenda',
                  detail: d.careToday == 0
                      ? 'Nenhum acompanhamento marcado para hoje.'
                      : '${d.careToday} acompanhamento${d.careToday == 1 ? '' : 's'} previsto${d.careToday == 1 ? '' : 's'} para hoje.',
                  onTap: () => context.go('/calendar'),
                ),
                _InsightTile(
                  icon: Icons.mark_unread_chat_alt_rounded,
                  color: AppColors.accent,
                  title: '${d.openRequests} solicita\u00e7\u00f5es abertas',
                  detail: 'Acompanhe as demandas que aguardam resposta.',
                  onTap: () => context.go('/requests'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.radius12),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedInk),
          ],
        ),
      ),
    );
  }
}

class _LeaderMetrics extends ConsumerWidget {
  const _LeaderMetrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(leaderDashboardProvider),
      onRetry: () => ref.invalidate(leaderDashboardProvider),
      loading: const Skeleton(height: 72, radius: AppTokens.radius16),
      // Tres numeros, como no desenho: tamanho da rede, quem esta sem
      // acompanhamento e o que chegou para responder. O resto dos totais
      // vive em Relatorios.
      data: (d) => _MetricGrid(
        items: [
          _MetricData(
            '${d.totalInNetwork}',
            'Pastores',
            Icons.account_tree_outlined,
            AppColors.softPrimary,
            AppColors.primary,
            '/network',
          ),
          _MetricData(
            '${d.withoutCareOver30Days}',
            '> 30 dias',
            Icons.schedule_rounded,
            const Color(0xFFFFE9E9),
            AppColors.alert,
            '/network?careOverdueDays=30',
          ),
          _MetricData(
            '${d.openRequests}',
            'Pedidos',
            Icons.support_agent_outlined,
            AppColors.softOrange,
            AppColors.accent,
            '/requests',
          ),
        ],
      ),
    );
  }
}

class _UpcomingCareSection extends ConsumerWidget {
  const _UpcomingCareSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Próximos acompanhamentos',
            actionLabel: 'Registrar',
            onAction: () => context.go('/care/new'),
          ),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: ref.watch(leaderDashboardProvider),
            onRetry: () => ref.invalidate(leaderDashboardProvider),
            loading: const _ListSkeleton(),
            data: (d) => d.nextCare.isEmpty
                ? const InlineEmpty(
                    icon: Icons.event_available_outlined,
                    message:
                        'Nenhum acompanhamento agendado.\nRegistre um acompanhamento e defina a próxima data.',
                  )
                : Column(
                    children: [
                      for (final item in d.nextCare)
                        _PersonTile(
                          name: item.pastoralName,
                          trailing: Formatters.relativeDateTime(
                            item.nextCareAt,
                          ),
                          onTap: () => context.go('/pastors/${item.pastorId}'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AttentionSection extends ConsumerWidget {
  const _AttentionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Sem acompanhamento recente',
            actionLabel: 'Ver todos',
            onAction: () => context.go('/network?careOverdueDays=30'),
          ),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: ref.watch(attentionPastorsProvider),
            onRetry: () => ref.invalidate(attentionPastorsProvider),
            loading: const _ListSkeleton(),
            data: (page) => page.isEmpty
                ? const InlineEmpty(
                    icon: Icons.task_alt_rounded,
                    message:
                        'Todos os pastores da sua rede foram acompanhados nos últimos 30 dias.',
                  )
                : Column(
                    children: [
                      for (final m in page.items)
                        _PersonTile(
                          name: m.pastoralName,
                          photoUrl: m.photoUrl,
                          subtitle: m.churchName,
                          trailing: Formatters.careSince(
                            days: m.daysSinceLastCare,
                            neverCared: m.neverCared,
                          ),
                          trailingColor: AppColors.alert,
                          onTap: () => context.go('/pastors/${m.id}'),
                        ),
                      if (page.total > page.items.length)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTokens.space8),
                          child: Text(
                            '+${page.total - page.items.length} na lista completa',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _CareActivitySection extends ConsumerWidget {
  const _CareActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Acompanhamentos por semana'),
          const SizedBox(height: AppTokens.space4),
          const Text(
            'Últimas 12 semanas na sua rede',
            style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
          const SizedBox(height: AppTokens.space16),
          AsyncValueView(
            value: ref.watch(careActivityProvider),
            hideWhenForbidden: true,
            onRetry: () => ref.invalidate(careActivityProvider),
            loading: const Skeleton(height: 180),
            data: (points) => points.every((p) => p.count == 0)
                ? const InlineEmpty(
                    icon: Icons.bar_chart_rounded,
                    message: 'Nenhum acompanhamento registrado no período.',
                  )
                : _WeeklyBars(points: points),
          ),
        ],
      ),
    );
  }
}

class _WeeklyBars extends StatefulWidget {
  const _WeeklyBars({required this.points});

  final List<CareActivityPoint> points;

  @override
  State<_WeeklyBars> createState() => _WeeklyBarsState();
}

class _WeeklyBarsState extends State<_WeeklyBars> {
  late int _selected = widget.points.length - 1;

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final max = points.map((p) => p.count).fold<int>(1, math.max);
    final selected = points[_selected.clamp(0, points.length - 1)];
    final total = points.fold<int>(0, (sum, p) => sum + p.count);

    return Semantics(
      label: '$total acompanhamentos em ${points.length} semanas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Semana de ${Formatters.dayMonth(selected.weekStart)}: ${Formatters.count(selected.count, 'acompanhamento', 'acompanhamentos')}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTokens.space12),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < points.length; i++)
                  Expanded(
                    child: Tooltip(
                      message:
                          '${Formatters.dayMonth(points[i].weekStart)}: ${points[i].count}',
                      child: InkWell(
                        onTap: () => setState(() => _selected = i),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                height: math.max(
                                  4,
                                  130 * points[i].count / max,
                                ),
                                decoration: BoxDecoration(
                                  color: i == _selected
                                      ? AppColors.primary
                                      : AppColors.secondary.withValues(
                                          alpha: 0.75,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Formatters.dayMonth(points.first.weekStart),
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
              ),
              Text(
                Formatters.dayMonth(points.last.weekStart),
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountriesSection extends ConsumerWidget {
  const _CountriesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Pastores por país',
            actionLabel: 'Mapa',
            onAction: () => context.go('/map'),
          ),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: ref.watch(countryDistributionProvider),
            hideWhenForbidden: true,
            onRetry: () => ref.invalidate(countryDistributionProvider),
            loading: const _ListSkeleton(),
            data: (countries) {
              if (countries.isEmpty) {
                return const InlineEmpty(
                  icon: Icons.public_off_rounded,
                  message: 'Nenhum pastor na sua área.',
                );
              }
              final max = countries
                  .map((c) => c.pastors)
                  .fold<int>(1, math.max);
              return Column(
                children: [
                  for (final c in countries.take(6))
                    InkWell(
                      borderRadius: BorderRadius.circular(AppTokens.radius8),
                      onTap: () => context.go('/map?country=${c.code}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTokens.space8,
                          horizontal: AppTokens.space4,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Text(
                                  c.code,
                                  style: const TextStyle(
                                    color: AppColors.mutedInk,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: AppTokens.space8),
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${c.pastors} · ${Formatters.count(c.churches, 'igreja', 'igrejas')}',
                                  style: const TextStyle(
                                    color: AppColors.mutedInk,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTokens.pill,
                              ),
                              child: LinearProgressIndicator(
                                value: c.pastors / max,
                                minHeight: 6,
                                backgroundColor: AppColors.border,
                                color: AppColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Pastor (e comum ao lider)
// -----------------------------------------------------------------------------

class _NextCommitmentSection extends ConsumerWidget {
  const _NextCommitmentSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      color: AppColors.softPrimary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Próximo compromisso',
            actionLabel: 'Agenda',
            onAction: () => context.go('/calendar'),
          ),
          const SizedBox(height: AppTokens.space12),
          AsyncValueView(
            value: ref.watch(pastorDashboardProvider),
            onRetry: () => ref.invalidate(pastorDashboardProvider),
            loading: const Skeleton(height: 56),
            data: (d) {
              final event = d.nextEvent;
              if (event == null) {
                return const InlineEmpty(
                  icon: Icons.event_busy_outlined,
                  message: 'Nenhum compromisso agendado.',
                );
              }
              return InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radius12),
                onTap: () => context.go('/calendar?event=${event.id}'),
                child: Row(
                  children: [
                    Container(
                      width: 54,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.space8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppTokens.radius12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            Formatters.day(event.startsAt),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            Formatters.monthShort(event.startsAt),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            Formatters.relativeDateTime(event.startsAt),
                            style: const TextStyle(color: AppColors.mutedInk),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnnouncementsSection extends ConsumerWidget {
  const _AnnouncementsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: 'Comunicados',
            actionLabel: 'Ver todos',
            onAction: () => context.go('/channel'),
          ),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: ref.watch(latestAnnouncementsProvider),
            hideWhenForbidden: true,
            onRetry: () => ref.invalidate(latestAnnouncementsProvider),
            loading: const _ListSkeleton(),
            data: (posts) => posts.isEmpty
                ? const InlineEmpty(
                    icon: Icons.campaign_outlined,
                    message: 'Nenhum comunicado publicado.',
                  )
                : Column(
                    children: [
                      for (final p in posts) _AnnouncementTile(post: p),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.post});

  final ChannelPostSummary post;

  @override
  Widget build(BuildContext context) {
    final urgent = post.type == ChannelPostType.urgent;
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      onTap: () => context.go('/channel/${post.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.space8,
          horizontal: AppTokens.space4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: urgent
                    ? AppColors.alert.withValues(alpha: 0.12)
                    : AppColors.softPrimary,
                borderRadius: BorderRadius.circular(AppTokens.radius12),
              ),
              child: Icon(
                urgent
                    ? Icons.priority_high_rounded
                    : post.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.campaign_outlined,
                color: urgent ? AppColors.alert : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.summary != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      post.summary!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.mutedInk),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    [
                      post.typeLabel,
                      if (post.publishedAt != null)
                        Formatters.dayMonth(post.publishedAt!),
                      if (post.requiresAck) 'requer confirmação',
                    ].join(' · '),
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MinistrySection extends ConsumerWidget {
  const _MinistrySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: 'Meu ministério'),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: ref.watch(pastorDashboardProvider),
            onRetry: () => ref.invalidate(pastorDashboardProvider),
            loading: const _ListSkeleton(),
            data: (d) => _MinistryTiles(dashboard: d),
          ),
        ],
      ),
    );
  }
}

/// Grade 2x2 do desenho: os quatro atalhos do proprio ministerio.
/// O subtitulo e sempre fato (nome da igreja, nome do supervisor, progresso).
class _MinistryTiles extends StatelessWidget {
  const _MinistryTiles({required this.dashboard});

  final PastorDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final church = dashboard.church;
    final leadership = dashboard.leadership;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppTokens.space12;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _MinistryTile(
                icon: Icons.church_outlined,
                label: 'Minha Igreja',
                detail: church?.name ?? 'Sem igreja vinculada',
                color: AppColors.softPrimary,
                onTap: church == null
                    ? null
                    : () => context.go('/churches/${church.id}'),
              ),
            ),
            SizedBox(
              width: width,
              child: _MinistryTile(
                icon: Icons.supervisor_account_outlined,
                label: 'Minha liderança',
                detail: leadership?.name ?? 'Sem supervisor definido',
                color: const Color(0xFFE7F7F2),
                onTap: leadership == null
                    ? null
                    : () => context.go('/pastors/${leadership.id}'),
              ),
            ),
            SizedBox(
              width: width,
              child: _MinistryTile(
                icon: Icons.calendar_month_outlined,
                label: 'Agenda',
                detail: dashboard.nextEvent == null
                    ? 'Nada agendado'
                    : Formatters.relativeDateTime(
                        dashboard.nextEvent!.startsAt,
                      ),
                color: AppColors.softBlue,
                onTap: () => context.go('/calendar'),
              ),
            ),
            SizedBox(
              width: width,
              child: _MinistryTile(
                icon: Icons.school_outlined,
                label: 'Formação',
                detail: dashboard.trainingTotal == 0
                    ? 'Nenhuma matrícula'
                    : '${dashboard.trainingProgressPct}% concluída',
                color: AppColors.softPurple,
                onTap: () => context.go('/training'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MinistryTile extends StatelessWidget {
  const _MinistryTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(height: AppTokens.space8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.mutedInk,
                  fontSize: 12,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpCard extends StatelessWidget {
  const _HelpCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: const Color(0xFFE7F7F2),
      onTap: () => context.go('/requests?new=1'),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.success,
            child: Icon(Icons.support_agent_rounded, color: Colors.white),
          ),
          SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Precisa de ajuda?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Abra uma solicitação para sua liderança.',
                  style: TextStyle(color: AppColors.mutedInk),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Componentes locais
// -----------------------------------------------------------------------------

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.name,
    required this.trailing,
    required this.onTap,
    this.photoUrl,
    this.subtitle,
    this.trailingColor = AppColors.mutedInk,
  });

  final String name;
  final String? photoUrl;
  final String? subtitle;
  final String trailing;
  final Color trailingColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.space8,
          horizontal: AppTokens.space4,
        ),
        child: Row(
          children: [
            PersonAvatar(name: name, photoUrl: photoUrl, size: 38),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space8),
            Flexible(
              child: Text(
                trailing,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: trailingColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedInk),
          ],
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTokens.space8),
            child: Row(
              children: [
                Skeleton(width: 38, height: 38, radius: 19),
                SizedBox(width: AppTokens.space12),
                Expanded(child: Skeleton(height: 12)),
                SizedBox(width: AppTokens.space24),
                Skeleton(width: 80, height: 12),
              ],
            ),
          ),
      ],
    );
  }
}
