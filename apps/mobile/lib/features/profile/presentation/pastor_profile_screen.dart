import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../pastors/domain/pastor_status.dart';
import '../../pastors/presentation/widgets/pastor_list_tile.dart';
import '../data/pastor_profile_providers.dart';
import '../domain/pastor_profile_models.dart';

/// Aba do Perfil 360, visivel conforme permissao (a API continua decidindo o acesso).
class _ProfileTab {
  const _ProfileTab(this.label, this.icon, this.builder);

  final String label;
  final IconData icon;
  final Widget Function(String pastorId) builder;
}

/// Perfil 360 do pastor: cabecalho com acoes e secoes carregadas sob demanda.
class PastorProfileScreen extends ConsumerWidget {
  const PastorProfileScreen({super.key, required this.pastorId});

  final String pastorId;

  List<_ProfileTab> _tabsFor(AuthUser user) => [
    _ProfileTab(
      'Resumo',
      Icons.person_outline_rounded,
      (id) => _SummaryTab(pastorId: id),
    ),
    _ProfileTab(
      'Ministério',
      Icons.church_outlined,
      (id) => _MinistryTab(pastorId: id),
    ),
    if (user.can('network.read'))
      _ProfileTab(
        'Liderança',
        Icons.supervisor_account_outlined,
        (id) => _LeadershipTab(pastorId: id),
      ),
    if (user.can('network.read'))
      _ProfileTab(
        'Rede',
        Icons.account_tree_outlined,
        (id) => _NetworkTab(pastorId: id),
      ),
    if (user.can('care.read'))
      _ProfileTab(
        'Acompanhamentos',
        Icons.volunteer_activism_outlined,
        (id) => _CareTab(pastorId: id),
      ),
    if (user.can('event.read'))
      _ProfileTab(
        'Agenda',
        Icons.calendar_month_outlined,
        (id) => _EventsTab(pastorId: id),
      ),
    if (user.can('training.read'))
      _ProfileTab(
        'Formação',
        Icons.school_outlined,
        (id) => _TrainingTab(pastorId: id),
      ),
    if (user.can('document.read'))
      _ProfileTab(
        'Documentos',
        Icons.folder_outlined,
        (id) => _DocumentsTab(pastorId: id),
      ),
    if (user.can('credential.read'))
      _ProfileTab(
        'Credenciais',
        Icons.badge_outlined,
        (id) => _CredentialsTab(pastorId: id),
      ),
    if (user.can('request.read'))
      _ProfileTab(
        'Solicitações',
        Icons.support_agent_outlined,
        (id) => _RequestsTab(pastorId: id),
      ),
    if (user.can('audit.read'))
      _ProfileTab(
        'Histórico',
        Icons.history_rounded,
        (id) => _HistoryTab(pastorId: id),
      ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final summary = ref.watch(pastorSummaryProvider(pastorId));

    // Sem acesso ao resumo nao ha perfil: 403/404 viram estado de pagina inteira.
    if (summary.hasError) {
      final error = summary.error;
      return _ProfileUnavailable(
        error: error,
        onRetry: () => ref.invalidate(pastorSummaryProvider(pastorId)),
      );
    }

    final tabs = _tabsFor(user);
    return DefaultTabController(
      length: tabs.length,
      child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverToBoxAdapter(
            child: summary.when(
              skipLoadingOnRefresh: true,
              data: (s) => _ProfileHeader(summary: s, user: user),
              loading: () => const _HeaderSkeleton(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.mutedInk,
                indicatorColor: AppColors.primary,
                tabs: [
                  for (final t in tabs)
                    Tab(
                      icon: Icon(t.icon, size: 18),
                      text: t.label,
                      iconMargin: const EdgeInsets.only(bottom: 2),
                    ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(children: [for (final t in tabs) t.builder(pastorId)]),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height + 1;
  @override
  double get maxExtent => tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: tabBar,
  );

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

// -----------------------------------------------------------------------------
// Cabecalho
// -----------------------------------------------------------------------------

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.summary, required this.user});

  final PastorSummary summary;
  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final status = PastorStatus.fromApi(summary.status);
    final wide = context.windowSize.isAtLeastMedium;
    final isSelf = user.pastorId == summary.id;
    final nextCare = summary.nextCareAt;

    final identity = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Text(
          summary.pastoralName,
          textAlign: wide ? TextAlign.start : TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        if (summary.location.isNotEmpty)
          Text(summary.location, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: AppTokens.space8),
        Wrap(
          spacing: AppTokens.space8,
          runSpacing: AppTokens.space8,
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _HeaderPill(label: status.label),
            if (!isSelf && user.can('care.read'))
              _HeaderPill(
                icon: Icons.history_rounded,
                label: Formatters.careSince(
                  days: summary.daysSinceLastCare,
                  neverCared: summary.neverCared,
                ),
              ),
            if (!isSelf && nextCare != null)
              _HeaderPill(
                icon: Icons.event_available_outlined,
                label: 'Próximo: ${Formatters.relativeDateTime(nextCare)}',
              ),
          ],
        ),
      ],
    );

    final actions = Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      children: [
        if (summary.whatsapp != null && !isSelf)
          _HeaderAction(
            icon: Icons.chat_outlined,
            label: 'WhatsApp',
            onTap: () => ContactActions.whatsApp(context, summary.whatsapp!),
          ),
        if (summary.phone != null && !isSelf)
          _HeaderAction(
            icon: Icons.call_outlined,
            label: 'Ligar',
            onTap: () => ContactActions.call(context, summary.phone!),
          ),
        if (summary.email != null && !isSelf)
          _HeaderAction(
            icon: Icons.mail_outline_rounded,
            label: 'E-mail',
            onTap: () => ContactActions.email(context, summary.email!),
          ),
        if (user.can('care.write') && !isSelf)
          _HeaderAction(
            icon: Icons.add_task_rounded,
            label: 'Registrar acompanhamento',
            primary: true,
            onTap: () => context.go('/care/new?pastorId=${summary.id}'),
          ),
      ],
    );

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        image: DecorationImage(
          image: AssetImage('assets/images/mountain_sunrise.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Color(0xC80F4C5C), BlendMode.srcOver),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        context.windowSize.pagePadding,
        AppTokens.space16,
        context.windowSize.pagePadding,
        AppTokens.space24,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Voltar',
                  color: Colors.white,
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(user.isLeader ? '/network' : '/dashboard'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _Avatar(summary: summary, size: 104),
                    const SizedBox(width: AppTokens.space24),
                    Expanded(child: identity),
                  ],
                )
              else ...[
                Center(child: _Avatar(summary: summary, size: 88)),
                const SizedBox(height: AppTokens.space12),
                identity,
              ],
              if (actions.children.isNotEmpty) ...[
                const SizedBox(height: AppTokens.space16),
                Padding(
                  padding: EdgeInsets.only(left: wide ? 128 : 0),
                  child: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.summary, required this.size});

  final PastorSummary summary;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: PersonAvatar(
        name: summary.pastoralName,
        photoUrl: summary.photoUrl,
        size: size,
      ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  const _HeaderPill({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppTokens.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final style = primary
        ? FilledButton.styleFrom(
            backgroundColor: AppColors.secondary,
            foregroundColor: Colors.white,
          )
        : FilledButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            foregroundColor: Colors.white,
          );
    return FilledButton.icon(
      style: style,
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      color: AppColors.primary,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 44, backgroundColor: Colors.white24),
          SizedBox(height: 12),
          SizedBox(
            width: 200,
            height: 18,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is AppFailure ? error as AppFailure : null;
    final (icon, title) = switch (failure?.kind) {
      FailureKind.forbidden => (
        Icons.lock_outline_rounded,
        'Perfil fora da sua área',
      ),
      FailureKind.notFound => (
        Icons.person_off_outlined,
        'Pastor não encontrado',
      ),
      _ => (Icons.cloud_off_rounded, 'Não foi possível carregar o perfil'),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.mutedInk),
            const SizedBox(height: AppTokens.space16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTokens.space8),
            Text(
              errorMessage(error ?? Object()),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedInk),
            ),
            const SizedBox(height: AppTokens.space24),
            Wrap(
              spacing: AppTokens.space8,
              children: [
                if (failure?.isRetryable ?? true)
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Tentar novamente'),
                  ),
                FilledButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Ir para o início'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Abas
// -----------------------------------------------------------------------------

/// Conteudo rolavel padrao de uma aba, centralizado e com largura maxima.
class _TabBody extends StatelessWidget {
  const _TabBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        padding,
        AppTokens.space16,
        padding,
        AppTokens.space32,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.trailing});

  final String title;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppTokens.space8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.icon, this.onTap});

  final String label;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radius8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTokens.space8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: AppTokens.space12),
            ],
            SizedBox(
              width: 150,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.mutedInk),
              ),
            ),
            Expanded(
              child: Text(
                value!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: onTap != null ? AppColors.primary : AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTokens.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

Widget _confidentialityBadge(String level) => switch (level) {
  'RESTRICTED' => const _Badge('Restrito', AppColors.accent),
  'CONFIDENTIAL' => const _Badge('Confidencial', AppColors.alert),
  _ => const SizedBox.shrink(),
};

Widget _loadingTab() => const _TabBody(children: [SkeletonCard(lines: 4)]);

/// Estado de aba com as tres variacoes padronizadas.
Widget _asyncTab<T>(
  WidgetRef ref,
  AsyncValue<T> value,
  VoidCallback retry,
  List<Widget> Function(T data) build,
) {
  return value.when(
    skipLoadingOnRefresh: true,
    loading: _loadingTab,
    error: (e, _) => _TabBody(
      children: [InlineError(message: errorMessage(e), onRetry: retry)],
    ),
    data: (data) => _TabBody(children: build(data)),
  );
}

class _SummaryTab extends ConsumerWidget {
  const _SummaryTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorSummaryProvider(pastorId)),
      () => ref.invalidate(pastorSummaryProvider(pastorId)),
      (s) => [
        if (s.biography != null)
          _Section(
            title: 'Sobre',
            children: [Text(s.biography!, style: const TextStyle(height: 1.5))],
          ),
        _Section(
          title: 'Contato',
          children: [
            _Field(
              'E-mail',
              s.email,
              icon: Icons.mail_outline_rounded,
              onTap: s.email == null
                  ? null
                  : () => ContactActions.email(context, s.email!),
            ),
            _Field(
              'Telefone',
              s.phone == null ? null : ContactActions.formatPhone(s.phone!),
              icon: Icons.call_outlined,
              onTap: s.phone == null
                  ? null
                  : () => ContactActions.call(context, s.phone!),
            ),
            _Field(
              'WhatsApp',
              s.whatsapp == null
                  ? null
                  : ContactActions.formatPhone(s.whatsapp!),
              icon: Icons.chat_outlined,
              onTap: s.whatsapp == null
                  ? null
                  : () => ContactActions.whatsApp(context, s.whatsapp!),
            ),
            if (s.email == null && s.phone == null && s.whatsapp == null)
              const Text(
                'Nenhum contato cadastrado.',
                style: TextStyle(color: AppColors.mutedInk),
              ),
          ],
        ),
        _Section(
          title: 'Dados pessoais',
          children: [
            _Field(
              'Nascimento',
              s.birthDate == null ? null : Formatters.date(s.birthDate!),
              icon: Icons.cake_outlined,
            ),
            _Field(
              'Estado civil',
              s.maritalLabel,
              icon: Icons.favorite_border_rounded,
            ),
            _Field('Cônjuge', s.spouseName, icon: Icons.people_outline_rounded),
            _Field('Endereço', s.address, icon: Icons.home_outlined),
            _Field('Localização', s.location, icon: Icons.place_outlined),
          ],
        ),
        if (s.userEmail != null)
          _Section(
            title: 'Acesso à plataforma',
            children: [
              _Field('Login', s.userEmail, icon: Icons.account_circle_outlined),
              _Field(
                'Último acesso',
                s.userLastLoginAt == null
                    ? 'Nunca acessou'
                    : Formatters.relativeDateTime(s.userLastLoginAt!),
                icon: Icons.login_rounded,
              ),
            ],
          ),
        if (s.adminNotes != null)
          _Section(
            title: 'Observações administrativas',
            trailing: const _Badge('Confidencial', AppColors.alert),
            children: [
              Text(s.adminNotes!, style: const TextStyle(height: 1.5)),
            ],
          ),
      ],
    );
  }
}

class _MinistryTab extends ConsumerWidget {
  const _MinistryTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorMinistryProvider(pastorId)),
      () => ref.invalidate(pastorMinistryProvider(pastorId)),
      (m) => [
        _Section(
          title: 'Ministério',
          children: [
            _Field(
              'Título',
              m.ministryTitle,
              icon: Icons.workspace_premium_outlined,
            ),
            _Field('Função', m.roleName, icon: Icons.work_outline_rounded),
            _Field(
              'Ingresso',
              m.joinedAt == null ? null : Formatters.date(m.joinedAt!),
              icon: Icons.event_outlined,
            ),
            _Field(
              'Ordenação',
              m.ordainedAt == null ? null : Formatters.date(m.ordainedAt!),
              icon: Icons.verified_outlined,
            ),
            _Field(
              'Responsável por',
              m.leadsChurchName,
              icon: Icons.stars_outlined,
            ),
          ],
        ),
        _Section(
          title: 'Igreja',
          children: m.churchName == null
              ? const [
                  Text(
                    'Sem igreja vinculada.',
                    style: TextStyle(color: AppColors.mutedInk),
                  ),
                ]
              : [
                  _Field('Nome', m.churchName, icon: Icons.church_outlined),
                  _Field(
                    'Tipo',
                    m.churchTypeLabel,
                    icon: Icons.category_outlined,
                  ),
                  _Field(
                    'Local',
                    [
                      m.churchCity,
                      m.churchRegion,
                      m.churchCountry,
                    ].whereType<String>().join(' · '),
                    icon: Icons.place_outlined,
                  ),
                ],
        ),
      ],
    );
  }
}

class _LeadershipTab extends ConsumerWidget {
  const _LeadershipTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorLeadershipProvider(pastorId)),
      () => ref.invalidate(pastorLeadershipProvider(pastorId)),
      (chain) => [
        _Section(
          title: 'Cadeia de liderança',
          children: chain.isEmpty
              ? const [
                  InlineEmpty(
                    icon: Icons.supervisor_account_outlined,
                    message: 'Sem supervisor definido.',
                  ),
                ]
              : [
                  for (final link in chain)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: PersonAvatar(
                        name: link.pastoralName,
                        photoUrl: link.photoUrl,
                      ),
                      title: Text(
                        link.pastoralName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          link.depth == 1
                              ? 'Supervisor direto'
                              : 'Nível ${link.depth} acima',
                          ?link.churchName,
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/pastors/${link.pastorId}'),
                    ),
                ],
        ),
      ],
    );
  }
}

class _NetworkTab extends ConsumerWidget {
  const _NetworkTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canCare = ref.watch(currentUserProvider)?.can('care.write') ?? false;
    return _asyncTab(
      ref,
      ref.watch(pastorNetworkProvider(pastorId)),
      () => ref.invalidate(pastorNetworkProvider(pastorId)),
      (n) => [
        Row(
          children: [
            Expanded(
              child: _Stat(value: '${n.total}', label: 'na rede'),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: _Stat(
                value: '${n.direct}',
                label: n.direct == 1 ? 'direto' : 'diretos',
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: _Stat(
                value: '${n.maxDepth}',
                label: n.maxDepth == 1 ? 'nível' : 'níveis',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.space16),
        if (n.directReports.isEmpty)
          const InlineEmpty(
            icon: Icons.groups_2_outlined,
            message: 'Nenhum pastor sob a supervisão direta deste pastor.',
          )
        else
          for (final member in n.directReports)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: PastorListTile(
                pastor: member,
                onTap: () => context.go('/pastors/${member.id}'),
                onRegisterCare: canCare
                    ? () => context.go('/care/new?pastorId=${member.id}')
                    : null,
              ),
            ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.softPrimary,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          Text(label, style: const TextStyle(color: AppColors.mutedInk)),
        ],
      ),
    );
  }
}

class _CareTab extends ConsumerWidget {
  const _CareTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canWrite = ref.watch(currentUserProvider)?.can('care.write') ?? false;
    return _asyncTab(
      ref,
      ref.watch(pastorCareTimelineProvider(pastorId)),
      () => ref.invalidate(pastorCareTimelineProvider(pastorId)),
      (entries) => [
        if (canWrite)
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => context.go('/care/new?pastorId=$pastorId'),
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Registrar acompanhamento'),
            ),
          ),
        const SizedBox(height: AppTokens.space12),
        if (entries.isEmpty)
          const InlineEmpty(
            icon: Icons.volunteer_activism_outlined,
            message: 'Nenhum acompanhamento registrado que você possa ver.',
          )
        else
          for (final e in entries) _CareEntryCard(entry: e),
      ],
    );
  }
}

class _CareEntryCard extends StatelessWidget {
  const _CareEntryCard({required this.entry});

  final CareEntry entry;

  Color get _typeColor {
    final hex = entry.typeColor;
    if (hex == null || hex.length != 7) return AppColors.primary;
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: AppCard(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _CareDetailSheet(entry: entry),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: BoxDecoration(
                color: _typeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        entry.typeName,
                        style: TextStyle(
                          color: _typeColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: AppTokens.space8),
                      _confidentialityBadge(entry.confidentiality),
                      const Spacer(),
                      Text(
                        Formatters.date(entry.occurredAt),
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.summary,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (entry.performedByName != null)
                    Text(
                      'Por ${entry.performedByName}',
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                      ),
                    ),
                  if (entry.nextAction != null || entry.nextCareAt != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        if (entry.nextAction != null)
                          'Próxima ação: ${entry.nextAction}',
                        if (entry.nextCareAt != null)
                          Formatters.relativeDateTime(entry.nextCareAt!),
                      ].join(' · '),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detalhe com anotacoes completas. A leitura de registro restrito/confidencial
/// e auditada pela API.
class _CareDetailSheet extends ConsumerWidget {
  const _CareDetailSheet({required this.entry});

  final CareEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(careDetailProvider(entry.id));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space24,
          0,
          AppTokens.space24,
          AppTokens.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.summary,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                _confidentialityBadge(entry.confidentiality),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${entry.typeName} · ${Formatters.relativeDateTime(entry.occurredAt)}${entry.performedByName != null ? ' · ${entry.performedByName}' : ''}',
              style: const TextStyle(color: AppColors.mutedInk),
            ),
            const SizedBox(height: AppTokens.space16),
            AsyncValueView(
              value: detail,
              onRetry: () => ref.invalidate(careDetailProvider(entry.id)),
              loading: const Skeleton(height: 80),
              data: (json) {
                final notes = json['notes'] as String?;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      notes == null || notes.isEmpty ? 'Sem anotações.' : notes,
                      style: const TextStyle(height: 1.5),
                    ),
                    if (json['location'] != null) ...[
                      const SizedBox(height: AppTokens.space12),
                      Text(
                        'Local: ${json['location']}',
                        style: const TextStyle(color: AppColors.mutedInk),
                      ),
                    ],
                    if (json['durationMinutes'] != null)
                      Text(
                        'Duração: ${json['durationMinutes']} min',
                        style: const TextStyle(color: AppColors.mutedInk),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EventsTab extends ConsumerWidget {
  const _EventsTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorEventsProvider(pastorId)),
      () => ref.invalidate(pastorEventsProvider(pastorId)),
      (events) => [
        if (events.isEmpty)
          const InlineEmpty(
            icon: Icons.event_busy_outlined,
            message: 'Nenhum compromisso nos últimos 30 dias ou agendado.',
          )
        else
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: e.startsAt.isBefore(DateTime.now())
                            ? AppColors.border
                            : AppColors.softPrimary,
                        borderRadius: BorderRadius.circular(AppTokens.radius12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            Formatters.day(e.startsAt),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            Formatters.monthShort(e.startsAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedInk,
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
                            e.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              Formatters.relativeDateTime(e.startsAt),
                              ?e.location,
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (e.meetingUrl != null)
                      TextButton.icon(
                        onPressed: () =>
                            ContactActions.openLink(context, e.meetingUrl!),
                        icon: const Icon(Icons.videocam_outlined),
                        label: const Text('Entrar'),
                      ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _TrainingTab extends ConsumerWidget {
  const _TrainingTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorEnrollmentsProvider(pastorId)),
      () => ref.invalidate(pastorEnrollmentsProvider(pastorId)),
      (items) {
        if (items.isEmpty) {
          return const [
            InlineEmpty(
              icon: Icons.school_outlined,
              message: 'Nenhuma matrícula em treinamentos.',
            ),
          ];
        }
        final done = items.where((i) => i.status == 'COMPLETED').length;
        return [
          Text(
            '$done de ${items.length} concluídos',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppTokens.space12),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            i.trainingTitle,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${i.progressPct}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.pill),
                      child: LinearProgressIndicator(
                        value: i.progressPct / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.border,
                        color: i.status == 'COMPLETED'
                            ? AppColors.success
                            : AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      i.completedAt != null
                          ? 'Concluído em ${Formatters.date(i.completedAt!)}'
                          : i.dueAt != null
                          ? (i.dueAt!.isBefore(DateTime.now())
                                ? 'Prazo encerrado em ${Formatters.date(i.dueAt!)}'
                                : 'Prazo: ${Formatters.date(i.dueAt!)}')
                          : 'Sem prazo definido',
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ];
      },
    );
  }
}

class _DocumentsTab extends ConsumerWidget {
  const _DocumentsTab({required this.pastorId});

  final String pastorId;

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    DocumentItem doc,
  ) async {
    try {
      final json = await ref
          .read(apiClientProvider)
          .getJson('/documents/${doc.id}/download');
      final url = json['url'] as String?;
      if (url != null && context.mounted) {
        await ContactActions.openLink(context, url);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorDocumentsProvider(pastorId)),
      () => ref.invalidate(pastorDocumentsProvider(pastorId)),
      (docs) => [
        if (docs.isEmpty)
          const InlineEmpty(
            icon: Icons.folder_off_outlined,
            message: 'Nenhum documento disponível para você.',
          )
        else
          for (final d in docs)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: AppCard(
                onTap: () => _open(context, ref, d),
                child: Row(
                  children: [
                    const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.alert,
                    ),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  d.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppTokens.space8),
                              _confidentialityBadge(d.confidentiality),
                            ],
                          ),
                          Text(
                            d.categoryLabel,
                            style: const TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (d.expiresAt != null) _ExpiryLabel(date: d.expiresAt!),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: AppColors.mutedInk,
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _ExpiryLabel extends StatelessWidget {
  const _ExpiryLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final days = date.difference(DateTime.now()).inDays;
    final (text, color) = days < 0
        ? ('Vencido', AppColors.alert)
        : days <= 60
        ? ('Vence em $days ${days == 1 ? 'dia' : 'dias'}', AppColors.accent)
        : ('Válido até ${Formatters.date(date)}', AppColors.mutedInk);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTokens.space8),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CredentialsTab extends ConsumerWidget {
  const _CredentialsTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorCredentialsProvider(pastorId)),
      () => ref.invalidate(pastorCredentialsProvider(pastorId)),
      (items) => [
        if (items.isEmpty)
          const InlineEmpty(
            icon: Icons.badge_outlined,
            message: 'Nenhuma credencial emitida.',
          )
        else
          for (final c in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: AppCard(
                child: Row(
                  children: [
                    const Icon(Icons.badge_outlined, color: AppColors.primary),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${c.typeLabel} · ${c.number}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Emitida em ${Formatters.date(c.issuedAt)}${c.expiresAt != null ? ' · validade ${Formatters.date(c.expiresAt!)}' : ''}',
                            style: const TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Badge(c.statusLabel, switch (c.status) {
                      'ACTIVE' => AppColors.success,
                      'PENDING' => AppColors.accent,
                      _ => AppColors.alert,
                    }),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _RequestsTab extends ConsumerWidget {
  const _RequestsTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorRequestsProvider(pastorId)),
      () => ref.invalidate(pastorRequestsProvider(pastorId)),
      (items) => [
        if (items.isEmpty)
          const InlineEmpty(
            icon: Icons.support_agent_outlined,
            message: 'Nenhuma solicitação relacionada.',
          )
        else
          for (final r in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTokens.space8),
              child: AppCard(
                onTap: () => context.go('/requests/${r.id}'),
                child: Row(
                  children: [
                    Text(
                      '#${r.number}',
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.subject,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              ?r.categoryName,
                              Formatters.date(r.createdAt),
                            ].join(' · '),
                            style: const TextStyle(
                              color: AppColors.mutedInk,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Badge(r.statusLabel, switch (r.status) {
                      'OPEN' => AppColors.accent,
                      'IN_PROGRESS' || 'WAITING' => AppColors.primary,
                      _ => AppColors.success,
                    }),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  const _HistoryTab({required this.pastorId});

  final String pastorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _asyncTab(
      ref,
      ref.watch(pastorHistoryProvider(pastorId)),
      () => ref.invalidate(pastorHistoryProvider(pastorId)),
      (items) => [
        _Section(
          title: 'Histórico de alterações',
          children: items.isEmpty
              ? const [
                  Text(
                    'Sem registros.',
                    style: TextStyle(color: AppColors.mutedInk),
                  ),
                ]
              : [
                  for (final h in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.history_rounded,
                        color: AppColors.primary,
                      ),
                      title: Text(h.actionLabel),
                      subtitle: Text(
                        [
                          Formatters.relativeDateTime(h.createdAt),
                          ?h.userName,
                        ].join(' · '),
                      ),
                    ),
                ],
        ),
      ],
    );
  }
}
