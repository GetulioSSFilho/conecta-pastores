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
      if (user.can('report.read_global')) const _GlobalOverview(),
      if (user.isLeader)
        ..._leaderSections(size)
      else
        ..._pastorSections(size, user),
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

  List<Widget> _pastorSections(WindowSize size, AuthUser user) => [
    _TwoColumns(
      enabled: size.isAtLeastMedium,
      left: const _NextCommitmentSection(),
      right: const _MinistrySection(),
    ),
    const _AnnouncementsSection(),
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
                'Olá, ${user.firstName}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppTokens.space4),
              Text(
                user.isLeader
                    ? '${Formatters.fullDate(DateTime.now())} · resumo da sua rede'
                    : Formatters.fullDate(DateTime.now()),
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

// -----------------------------------------------------------------------------
// Visao global (admin/lider nacional)
// -----------------------------------------------------------------------------

class _GlobalOverview extends ConsumerWidget {
  const _GlobalOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(globalDashboardProvider),
      hideWhenForbidden: true,
      onRetry: () => ref.invalidate(globalDashboardProvider),
      loading: const Skeleton(height: 72, radius: AppTokens.radius16),
      data: (g) => _MetricGrid(
        items: [
          _MetricData(
            '${g.totalPastors}',
            'Pastores',
            Icons.people_alt_outlined,
            AppColors.softPrimary,
            AppColors.primary,
            '/pastors',
          ),
          _MetricData(
            '${g.activePastors}',
            'Ativos',
            Icons.verified_outlined,
            const Color(0xFFE7F7F2),
            AppColors.success,
            '/pastors?status=ACTIVE',
          ),
          _MetricData(
            '${g.totalChurches}',
            'Igrejas',
            Icons.church_outlined,
            AppColors.softBlue,
            AppColors.primary,
            '/churches',
          ),
          _MetricData(
            '${g.countries}',
            g.countries == 1 ? 'País' : 'Países',
            Icons.public_rounded,
            AppColors.softPurple,
            AppColors.primary,
            '/map',
          ),
          _MetricData(
            '${g.regions}',
            g.regions == 1 ? 'Região' : 'Regiões',
            Icons.map_outlined,
            AppColors.softOrange,
            AppColors.accent,
            '/map',
          ),
          _MetricData(
            '${g.newPastors}',
            'Novos (30 dias)',
            Icons.person_add_alt_1_outlined,
            const Color(0xFFE7F7F2),
            AppColors.success,
            '/pastors?sortBy=createdAt&sortOrder=desc',
          ),
        ],
      ),
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

class _LeaderMetrics extends ConsumerWidget {
  const _LeaderMetrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(leaderDashboardProvider),
      onRetry: () => ref.invalidate(leaderDashboardProvider),
      loading: const Skeleton(height: 72, radius: AppTokens.radius16),
      data: (d) => _MetricGrid(
        items: [
          _MetricData(
            '${d.totalInNetwork}',
            'Pastores na rede',
            Icons.account_tree_outlined,
            AppColors.softPrimary,
            AppColors.primary,
            '/network',
          ),
          _MetricData(
            '${d.withoutCareOver30Days}',
            'Há mais de 30 dias',
            Icons.schedule_rounded,
            const Color(0xFFFFE9E9),
            AppColors.alert,
            '/network?careOverdueDays=30',
          ),
          _MetricData(
            '${d.neverCared}',
            'Nunca acompanhados',
            Icons.person_off_outlined,
            AppColors.softOrange,
            AppColors.accent,
            '/network?neverCared=true',
          ),
          _MetricData(
            '${d.careThisWeek}',
            'Acompanhamentos na semana',
            Icons.volunteer_activism_outlined,
            const Color(0xFFE7F7F2),
            AppColors.success,
            '/care',
          ),
          _MetricData(
            '${d.upcomingCareNext7Days}',
            'Agendados (7 dias)',
            Icons.event_available_outlined,
            AppColors.softBlue,
            AppColors.primary,
            '/calendar',
          ),
          _MetricData(
            '${d.openRequests}',
            'Solicitações comigo',
            Icons.support_agent_outlined,
            AppColors.softPurple,
            AppColors.primary,
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
            data: (d) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.church_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(d.church?.name ?? 'Sem igreja vinculada'),
                  subtitle: Text(d.church?.city ?? 'Minha igreja'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.supervisor_account_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(d.leadership?.name ?? 'Sem supervisor definido'),
                  subtitle: const Text('Minha liderança'),
                  trailing: d.leadership == null
                      ? null
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: d.leadership == null
                      ? null
                      : () => context.go('/pastors/${d.leadership!.id}'),
                ),
                const Divider(),
                Wrap(
                  spacing: AppTokens.space8,
                  runSpacing: AppTokens.space8,
                  children: [
                    _CountChip(
                      icon: Icons.notifications_none_rounded,
                      label: Formatters.count(
                        d.unreadNotifications,
                        'notificação',
                        'notificações',
                      ),
                      path: '/notifications',
                    ),
                    _CountChip(
                      icon: Icons.support_agent_outlined,
                      label: Formatters.count(
                        d.openRequests,
                        'solicitação aberta',
                        'solicitações abertas',
                      ),
                      path: '/requests',
                    ),
                    _CountChip(
                      icon: Icons.event_note_outlined,
                      label: Formatters.count(
                        d.expiringDocuments,
                        'documento vencendo',
                        'documentos vencendo',
                      ),
                      path: '/documents',
                      alert: d.expiringDocuments > 0,
                    ),
                    _CountChip(
                      icon: Icons.school_outlined,
                      label: d.trainingTotal == 0
                          ? 'Nenhum treinamento'
                          : d.trainingPending == 0
                          ? 'Formação ${d.trainingProgressPct}% concluída'
                          : Formatters.count(
                              d.trainingPending,
                              'treinamento pendente',
                              'treinamentos pendentes',
                            ),
                      path: '/training',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.path,
    this.alert = false,
  });

  final IconData icon;
  final String label;
  final String path;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        icon,
        size: 18,
        color: alert ? AppColors.alert : AppColors.primary,
      ),
      label: Text(label),
      onPressed: () => context.go(path),
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.surface,
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
