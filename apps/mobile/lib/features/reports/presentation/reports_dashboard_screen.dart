import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/reports_providers.dart';

/// Relatórios: números da rede dentro do escopo de quem consulta.
///
/// Cada bloco pede seus próprios dados e some quando o servidor nega acesso —
/// esconder no cliente não é segurança, quem decide é a API.
class ReportsDashboardScreen extends ConsumerWidget {
  const ReportsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.windowSize.pagePadding;

    // Quando a API nega todos os blocos, a página explica em vez de ficar vazia.
    final semAcesso = [
      ref.watch(globalReportProvider),
      ref.watch(leaderReportProvider),
      ref.watch(careActivityProvider),
      ref.watch(countryDistributionProvider),
    ].every((value) => isForbidden(value.error));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(globalReportProvider);
            ref.invalidate(leaderReportProvider);
            ref.invalidate(countryDistributionProvider);
            ref.invalidate(careActivityProvider);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(padding, padding, padding, AppTokens.space32),
            children: [
              Text(
                'Relatórios',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Números da rede que você acompanha',
                style: TextStyle(color: AppColors.mutedInk),
              ),
              const SizedBox(height: AppTokens.space24),
              if (semAcesso)
                const NoAccessNotice(
                  message:
                      'Você não acompanha indicadores de rede. Seus próprios '
                      'números estão no Início.',
                )
              else ...[
                const _GlobalNumbers(),
                const SizedBox(height: AppTokens.space16),
                const _NetworkNumbers(),
                const SizedBox(height: AppTokens.space16),
                const _CareActivity(),
                const SizedBox(height: AppTokens.space16),
                const _CountryDistribution(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalNumbers extends ConsumerWidget {
  const _GlobalNumbers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(globalReportProvider),
      hideWhenForbidden: true,
      onRetry: () => ref.invalidate(globalReportProvider),
      loading: const SkeletonCard(lines: 3),
      data: (report) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth > 680 ? 3 : 2;
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppTokens.space8,
            mainAxisSpacing: AppTokens.space8,
            childAspectRatio: 1.9,
            children: [
              _Metric(
                label: 'Pastores',
                value: '${report.totalPastors}',
                detail: '${report.activePastors} ativos',
                icon: Icons.people_outline_rounded,
                onTap: () => context.go('/pastors'),
              ),
              _Metric(
                label: 'Igrejas',
                value: '${report.totalChurches}',
                icon: Icons.church_outlined,
                onTap: () => context.go('/churches'),
              ),
              _Metric(
                label: 'Países',
                value: '${report.countries}',
                detail: '${report.regions} regiões',
                icon: Icons.public_rounded,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NetworkNumbers extends ConsumerWidget {
  const _NetworkNumbers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(leaderReportProvider),
      hideWhenForbidden: true,
      onRetry: () => ref.invalidate(leaderReportProvider),
      loading: const SkeletonCard(lines: 4),
      data: (report) => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Minha rede', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppTokens.space12),
            Wrap(
              spacing: AppTokens.space24,
              runSpacing: AppTokens.space12,
              children: [
                _Fact(label: 'Pastores na rede', value: '${report.totalInNetwork}'),
                _Fact(label: 'Supervisão direta', value: '${report.directReports}'),
                _Fact(label: 'Acompanhados hoje', value: '${report.careToday}'),
                _Fact(label: 'Acompanhados na semana', value: '${report.careThisWeek}'),
                _Fact(
                  label: 'Sem acompanhamento há mais de 30 dias',
                  value: '${report.withoutCareOver30Days}',
                  color: report.withoutCareOver30Days > 0 ? AppColors.accent : null,
                ),
                _Fact(
                  label: 'Nunca acompanhados',
                  value: '${report.neverCared}',
                  color: report.neverCared > 0 ? AppColors.accent : null,
                ),
                _Fact(label: 'Próximos 7 dias', value: '${report.upcomingCareNext7Days}'),
                _Fact(label: 'Solicitações abertas', value: '${report.openRequests}'),
              ],
            ),
            if (report.nextCare.isNotEmpty) ...[
              const Divider(height: AppTokens.space24),
              const Text(
                'Próximos acompanhamentos',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTokens.space8),
              for (final item in report.nextCare.take(5))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(item.pastoralName),
                  trailing: Text(
                    item.nextCareAt == null ? '—' : Formatters.date(item.nextCareAt!),
                    style: const TextStyle(color: AppColors.mutedInk),
                  ),
                  onTap: () => context.go('/pastors/${item.pastorId}'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Acompanhamentos por semana. Barras desenhadas com widgets:
/// nenhuma biblioteca de gráfico foi adicionada ao pacote.
class _CareActivity extends ConsumerWidget {
  const _CareActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weeks = ref.watch(careActivityWeeksProvider);

    return AsyncValueView(
      value: ref.watch(careActivityProvider),
      hideWhenForbidden: true,
      onRetry: () => ref.invalidate(careActivityProvider),
      loading: const SkeletonCard(lines: 4),
      data: (points) {
        if (points.isEmpty) return const SizedBox.shrink();
        final max = points.map((p) => p.count).reduce((a, b) => a > b ? a : b);
        final total = points.fold(0, (sum, p) => sum + p.count);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Acompanhamentos por semana',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  for (final option in const [8, 12, 26])
                    Padding(
                      padding: const EdgeInsets.only(left: AppTokens.space8),
                      child: ChoiceChip(
                        label: Text('$option sem.'),
                        selected: weeks == option,
                        onSelected: (_) =>
                            ref.read(careActivityWeeksProvider.notifier).set(option),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '$total registros no período',
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
              ),
              const SizedBox(height: AppTokens.space16),
              SizedBox(
                height: 140,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final point in points)
                      Expanded(
                        child: Tooltip(
                          message:
                              '${Formatters.date(point.weekStart)}: ${point.count} '
                              '${point.count == 1 ? 'registro' : 'registros'}',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  '${point.count}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.mutedInk,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  height: max == 0 ? 2 : 100 * point.count / max + 2,
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.dayMonth(point.weekStart),
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppColors.mutedInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CountryDistribution extends ConsumerWidget {
  const _CountryDistribution();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(countryDistributionProvider),
      hideWhenForbidden: true,
      onRetry: () => ref.invalidate(countryDistributionProvider),
      loading: const SkeletonCard(lines: 3),
      data: (countries) {
        if (countries.isEmpty) return const SizedBox.shrink();
        final max = countries.map((c) => c.pastors).reduce((a, b) => a > b ? a : b);

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pastores por país', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: AppTokens.space16),
              for (final country in countries)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTokens.space12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          country.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: max == 0 ? 0 : country.pastors / max,
                            minHeight: 10,
                            color: AppColors.secondary,
                            backgroundColor: AppColors.softPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTokens.space12),
                      Text(
                        '${country.pastors}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: AppTokens.space8),
                      Text(
                        '${country.churches} ${country.churches == 1 ? 'igreja' : 'igrejas'}',
                        style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          if (detail != null)
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.ink,
            ),
          ),
          Text(label, style: const TextStyle(color: AppColors.mutedInk, fontSize: 12)),
        ],
      ),
    );
  }
}
