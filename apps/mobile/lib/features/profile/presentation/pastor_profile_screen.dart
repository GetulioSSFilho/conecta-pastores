import 'dart:math' as math;

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
import '../../../core/utils/demo_pastor_photos.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/skeleton.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_user.dart';
import '../../pastors/domain/pastor_status.dart';
import '../../pastors/presentation/widgets/pastor_list_tile.dart';
import '../../network/presentation/my_network_screen.dart';
import '../data/pastor_profile_providers.dart';
import '../domain/pastor_profile_models.dart';

/// Aba do Perfil 360, visivel conforme permissao (a API continua decidindo o acesso).
class _ProfileTab {
  const _ProfileTab(this.label, this.builder);

  final String label;
  final Widget Function(String pastorId) builder;
}

/// Perfil 360 do pastor: cabecalho com acoes e secoes carregadas sob demanda.
class PastorProfileScreen extends ConsumerStatefulWidget {
  const PastorProfileScreen({super.key, required this.pastorId});

  final String pastorId;

  /// Tres abas, como no desenho: Resumo, Ministerio e Acompanhamentos.
  ///
  /// Cada aba reune as secoes que antes eram abas separadas. A consulta
  /// continua por secao: uma secao lenta ou negada (403) nao derruba a aba,
  /// e o que aparece depende do que a API autoriza.
  List<_ProfileTab> _tabsFor(AuthUser user) => [
    _ProfileTab(
      'Resumo',
      (id) => _TabBody(
        children: [
          _SummaryTab(pastorId: id),
          if (user.can('network.read')) ...[
            const _GroupHeading('Liderança'),
            _LeadershipTab(pastorId: id),
          ],
        ],
      ),
    ),
    _ProfileTab(
      'Ministério',
      (id) => _TabBody(
        children: [
          _MinistryTab(pastorId: id),
          if (user.can('network.read')) ...[
            const _GroupHeading('Rede sob supervisão'),
            _NetworkTab(pastorId: id),
          ],
          if (user.can('training.read')) ...[
            const _GroupHeading('Formação'),
            _TrainingTab(pastorId: id),
          ],
          if (user.can('document.read')) ...[
            const _GroupHeading('Documentos'),
            _DocumentsTab(pastorId: id),
          ],
          if (user.can('credential.read')) ...[
            const _GroupHeading('Credenciais'),
            _CredentialsTab(pastorId: id),
          ],
        ],
      ),
    ),
    _ProfileTab(
      'Acompanhamentos',
      (id) => _TabBody(
        children: [
          if (user.can('care.read')) _CareTab(pastorId: id),
          if (user.can('request.read')) ...[
            const _GroupHeading('Solicitações'),
            _RequestsTab(pastorId: id),
          ],
          if (user.can('event.read')) ...[
            const _GroupHeading('Agenda'),
            _EventsTab(pastorId: id),
          ],
          if (user.can('audit.read')) _HistoryTab(pastorId: id),
        ],
      ),
    ),
  ];

  @override
  ConsumerState<PastorProfileScreen> createState() =>
      _PastorProfileScreenState();
}

class _PastorProfileScreenState extends ConsumerState<PastorProfileScreen> {
  final _scrollLock = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _scrollLock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final user = ref.watch(currentUserProvider);
    if (user == null) return const SizedBox.shrink();
    final summary = ref.watch(pastorSummaryProvider(widget.pastorId));

    // Sem acesso ao resumo nao ha perfil: 403/404 viram estado de pagina inteira.
    if (summary.hasError) {
      final error = summary.error;
      return _ProfileUnavailable(
        error: error,
        onRetry: () => ref.invalidate(pastorSummaryProvider(widget.pastorId)),
      );
    }

    final tabs = widget._tabsFor(user);
    return ValueListenableBuilder<bool>(
      valueListenable: _scrollLock,
      builder: (context, locked, _) => TreeScrollLockScope(
        lock: _scrollLock,
        child: DefaultTabController(
          length: tabs.length,
          child: NestedScrollView(
            physics: locked ? const NeverScrollableScrollPhysics() : null,
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
                  // Três abas cabem sem rolagem lateral, inclusive no celular.
                  TabBar(
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.mutedInk,
                    indicatorColor: AppColors.primary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    tabs: [for (final t in tabs) Tab(text: t.label)],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [for (final t in tabs) t.builder(widget.pastorId)],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

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
        Row(
          mainAxisAlignment: wide
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                summary.pastoralName,
                textAlign: wide ? TextAlign.start : TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            // Selo do desenho: marca apenas quem esta com cadastro ativo.
            if (status == PastorStatus.active) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.verified_rounded,
                color: AppColors.secondary,
                size: 20,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (summary.location.isNotEmpty)
          Text(summary.location, style: const TextStyle(color: Colors.white70)),
        if (summary.ministryTitle != null || summary.ministryRoleName != null)
          Text(
            summary.ministryTitle ?? summary.ministryRoleName!,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
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
      spacing: AppTokens.space12,
      runSpacing: AppTokens.space12,
      alignment: wide ? WrapAlignment.start : WrapAlignment.center,
      children: [
        if (summary.whatsapp != null && !isSelf)
          _HeaderAction(
            icon: Icons.chat_rounded,
            label: 'WhatsApp',
            tint: AppColors.success,
            onTap: () => ContactActions.whatsApp(context, summary.whatsapp!),
          ),
        if (summary.phone != null && !isSelf)
          _HeaderAction(
            icon: Icons.call_rounded,
            label: 'Ligar',
            tint: AppColors.primary,
            onTap: () => ContactActions.call(context, summary.phone!),
          ),
        if (user.can('event.write'))
          _HeaderAction(
            icon: Icons.event_available_rounded,
            label: 'Agendar',
            tint: AppColors.secondary,
            onTap: () => context.go('/calendar/new?pastorId=${summary.id}'),
          ),
        if (summary.email != null && !isSelf)
          _HeaderAction(
            icon: Icons.mail_outline_rounded,
            label: 'E-mail',
            tint: AppColors.neutral,
            onTap: () => ContactActions.email(context, summary.email!),
          ),
        if (user.can('care.write') && !isSelf)
          _HeaderAction(
            icon: Icons.add_task_rounded,
            label: 'Acompanhar',
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
        photoUrl:
            summary.photoUrl ??
            DemoPastorPhotos.forPastor(
              id: summary.id,
              name: summary.pastoralName,
            ),
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
    this.tint,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  /// Cor do icone quando a acao nao e a principal.
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    // Formato do desenho: quadrado claro com icone colorido e rotulo abaixo.
    // IconButton ja expoe papel de botao e rotulo para leitores de tela.
    final iconColor = primary ? Colors.white : (tint ?? AppColors.primary);
    return SizedBox(
      width: 78,
      child: Column(
        children: [
          IconButton(
            tooltip: label,
            onPressed: onTap,
            icon: Icon(icon, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: primary ? AppColors.secondary : Colors.white,
              foregroundColor: iconColor,
              minimumSize: const Size(52, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTokens.radius16),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
    Widget list(bool locked) => ListView(
      physics: locked ? const NeverScrollableScrollPhysics() : null,
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
    final lock = TreeScrollLockScope.maybeOf(context);
    if (lock == null) return list(false);
    return ValueListenableBuilder<bool>(
      valueListenable: lock,
      builder: (context, locked, _) => list(locked),
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

/// Titulo de um grupo dentro da aba: as abas do desenho reunem varias secoes,
/// e cada uma precisa se anunciar.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.mutedInk,
          fontSize: 11,
          letterSpacing: 1,
          fontWeight: FontWeight.w700,
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

/// Estado de uma secao do perfil, com as tres variacoes padronizadas.
///
/// Devolve uma coluna (nao um ListView): varias secoes convivem na mesma aba
/// e quem rola e o `_TabBody`. Um 403 em uma secao mostra o aviso de acesso
/// e deixa as outras de pe.
Widget _asyncTab<T>(
  WidgetRef ref,
  AsyncValue<T> value,
  VoidCallback retry,
  List<Widget> Function(T data) build,
) {
  return value.when(
    skipLoadingOnRefresh: true,
    loading: () => const SkeletonCard(lines: 4),
    error: (e, _) => isForbidden(e)
        ? const NoAccessNotice()
        : InlineError(message: errorMessage(e), onRetry: retry),
    data: (data) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: build(data),
    ),
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
        _Section(
          title: 'Sobre',
          children: [
            Text(
              s.biography ??
                  'Este pastor ainda não adicionou uma apresentação ao seu perfil.',
              style: const TextStyle(height: 1.5),
            ),
            if (s.joinedAt != null) ...[
              const SizedBox(height: AppTokens.space12),
              _Field(
                'Na rede desde',
                Formatters.date(s.joinedAt!),
                icon: Icons.groups_outlined,
              ),
            ],
          ],
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
      ref.watch(pastorHierarchyProvider(pastorId)),
      () => ref.invalidate(pastorHierarchyProvider(pastorId)),
      (hierarchy) => [
        _Section(
          title: 'Organograma do pastor',
          children: hierarchy.descendants == null && hierarchy.ancestors.isEmpty
              ? const [
                  InlineEmpty(
                    icon: Icons.supervisor_account_outlined,
                    message: 'Nenhuma relação de liderança encontrada.',
                  ),
                ]
              : [
                  PastorHierarchyOrganogram(
                    hierarchy: hierarchy,
                    currentId: pastorId,
                  ),
                ],
        ),
      ],
    );
  }
}

class PastorHierarchyOrganogram extends StatefulWidget {
  const PastorHierarchyOrganogram({
    super.key,
    required this.hierarchy,
    required this.currentId,
  });

  final PastorHierarchy hierarchy;
  final String currentId;

  @override
  State<PastorHierarchyOrganogram> createState() =>
      _ProfileHierarchyGraphState();
}

class _ProfileHierarchyGraphState extends State<PastorHierarchyOrganogram> {
  late final Set<String> _expanded;
  final _transform = TransformationController();
  var _didInitialize = false;
  var _initialOffset = Offset.zero;
  var _activePointers = 0;

  @override
  void initState() {
    super.initState();
    _expanded = {
      widget.currentId,
      ...widget.hierarchy.ancestors.map((link) => link.pastorId),
    };
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent _) {
    _activePointers++;
    TreeScrollLockScope.maybeOf(context)?.value = true;
  }

  void _pointerUp(PointerEvent _) {
    _activePointers = math.max(0, _activePointers - 1);
    if (_activePointers == 0) {
      TreeScrollLockScope.maybeOf(context)?.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = _ProfileTreeLayout.build(_composeTree(), _expanded);
    const graphPadding = 24.0;
    final width = math.max(
      layout.width + graphPadding * 2,
      MediaQuery.sizeOf(context).width - 80,
    );
    if (!_didInitialize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didInitialize) return;
        final renderBox = context.findRenderObject();
        final viewportWidth = renderBox is RenderBox
            ? renderBox.size.width
            : MediaQuery.sizeOf(context).width - 80;
        _initialOffset = Offset((viewportWidth - width) / 2, 0);
        _transform.value = Matrix4.translationValues(
          _initialOffset.dx,
          _initialOffset.dy,
          0,
        );
        _didInitialize = true;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: context.windowSize.isCompact ? 360 : 420,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTokens.radius12),
            child: Stack(
              children: [
                Listener(
                  onPointerDown: _pointerDown,
                  onPointerUp: _pointerUp,
                  onPointerCancel: _pointerUp,
                  child: InteractiveViewer(
                    transformationController: _transform,
                    constrained: false,
                    minScale: .45,
                    maxScale: 1.8,
                    boundaryMargin: const EdgeInsets.all(140),
                    clipBehavior: Clip.hardEdge,
                    onInteractionUpdate: (_) => _clampScale(),
                    onInteractionEnd: (_) => _clampScale(),
                    child: SizedBox(
                      width: width,
                      height: layout.height + graphPadding * 2,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ProfileTreeConnectorPainter(
                                edges: layout.edges,
                                offset: const Offset(
                                  graphPadding,
                                  graphPadding,
                                ),
                              ),
                            ),
                          ),
                          for (final item in layout.nodes)
                            Positioned(
                              left: item.position.dx + graphPadding,
                              top: item.position.dy + graphPadding,
                              child: _ProfileTreeCard(
                                node: item.node,
                                expanded: _expanded.contains(item.node.id),
                                current: item.node.id == widget.currentId,
                                onTap: () =>
                                    context.go('/pastors/${item.node.id}'),
                                onToggle: () => setState(() {
                                  if (!_expanded.add(item.node.id)) {
                                    _expanded.remove(item.node.id);
                                  }
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Material(
                    color: AppColors.surface.withValues(alpha: .96),
                    borderRadius: BorderRadius.circular(AppTokens.radius12),
                    elevation: 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Diminuir zoom',
                          onPressed: () => _scale(.8),
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        IconButton(
                          tooltip: 'Aumentar zoom',
                          onPressed: () => _scale(1.25),
                          icon: const Icon(Icons.add_rounded),
                        ),
                        IconButton(
                          tooltip: 'Redefinir zoom',
                          onPressed: () =>
                              _transform.value = Matrix4.translationValues(
                                _initialOffset.dx,
                                _initialOffset.dy,
                                0,
                              ),
                          icon: const Icon(Icons.center_focus_strong_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  bottom: 10,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: .72),
                      borderRadius: BorderRadius.circular(AppTokens.pill),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        'Pinça para ampliar · arraste para navegar',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space8),
        const Text(
          'Ascendentes acima e lideranças diretas abaixo. Toque em uma pessoa para abrir o perfil.',
          style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
        ),
      ],
    );
  }

  void _scale(double factor) {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(.45, 1.8).toDouble();
    final matrix = Matrix4.copy(_transform.value)
      ..setEntry(0, 0, next)
      ..setEntry(1, 1, next)
      ..setEntry(2, 2, next);
    _transform.value = matrix;
  }

  void _clampScale() {
    final current = _transform.value.getMaxScaleOnAxis();
    final next = current.clamp(.45, 1.8).toDouble();
    if (current == 0 || (current - next).abs() < .0001) return;
    final matrix = Matrix4.copy(_transform.value)
      ..scaleByDouble(next / current, next / current, next / current, 1);
    _transform.value = matrix;
  }

  PastorHierarchyNode _composeTree() {
    var root =
        widget.hierarchy.descendants ??
        const PastorHierarchyNode(id: 'profile', pastoralName: 'Pastor');
    for (final link in widget.hierarchy.ancestors) {
      root = PastorHierarchyNode(
        id: link.pastorId,
        pastoralName: link.pastoralName,
        photoUrl: link.photoUrl,
        churchName: link.churchName,
        children: [root],
      );
    }
    return root;
  }
}

class _ProfileTreeLayoutNode {
  const _ProfileTreeLayoutNode(this.position, this.node);

  final Offset position;
  final PastorHierarchyNode node;
}

class _ProfileTreeEdge {
  const _ProfileTreeEdge(this.from, this.to);

  final Offset from;
  final Offset to;
}

class _ProfileTreeLayoutData {
  const _ProfileTreeLayoutData({
    required this.width,
    required this.height,
    required this.nodes,
    required this.edges,
  });

  final double width;
  final double height;
  final List<_ProfileTreeLayoutNode> nodes;
  final List<_ProfileTreeEdge> edges;
}

class _ProfileTreeLayout {
  static const nodeWidth = 156.0;
  static const nodeHeight = 142.0;
  static const horizontalGap = 24.0;
  static const verticalGap = 36.0;

  static _ProfileTreeLayoutData build(
    PastorHierarchyNode root,
    Set<String> expanded,
  ) {
    final nodes = <_ProfileTreeLayoutNode>[];
    final edges = <_ProfileTreeEdge>[];
    final size = _measure(root, expanded, nodes, edges);
    return _ProfileTreeLayoutData(
      width: size.width,
      height: size.height,
      nodes: nodes,
      edges: edges,
    );
  }

  static ({double width, double height}) _measure(
    PastorHierarchyNode node,
    Set<String> expanded,
    List<_ProfileTreeLayoutNode> nodes,
    List<_ProfileTreeEdge> edges, {
    double left = 0,
    double top = 0,
  }) {
    final children = expanded.contains(node.id)
        ? node.children
        : const <PastorHierarchyNode>[];
    if (children.isEmpty) {
      nodes.add(_ProfileTreeLayoutNode(Offset(left, top), node));
      return (width: nodeWidth, height: nodeHeight);
    }
    final childSizes = [
      for (final child in children) _subtreeSize(child, expanded),
    ];
    final childrenWidth =
        childSizes.fold<double>(0, (sum, size) => sum + size.width) +
        horizontalGap * (children.length - 1);
    final width = math.max(nodeWidth, childrenWidth);
    final nodeLeft = left + (width - nodeWidth) / 2;
    nodes.add(_ProfileTreeLayoutNode(Offset(nodeLeft, top), node));
    var childLeft = left + (width - childrenWidth) / 2;
    final childTop = top + nodeHeight + verticalGap;
    var maxChildHeight = 0.0;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final childSize = _measure(
        child,
        expanded,
        nodes,
        edges,
        left: childLeft,
        top: childTop,
      );
      edges.add(
        _ProfileTreeEdge(
          Offset(nodeLeft + nodeWidth / 2, top + nodeHeight),
          Offset(childLeft + childSizes[i].width / 2, childTop),
        ),
      );
      childLeft += childSizes[i].width + horizontalGap;
      maxChildHeight = math.max(maxChildHeight, childSize.height);
    }
    return (width: width, height: nodeHeight + verticalGap + maxChildHeight);
  }

  static ({double width, double height}) _subtreeSize(
    PastorHierarchyNode node,
    Set<String> expanded,
  ) {
    final nodes = <_ProfileTreeLayoutNode>[];
    final edges = <_ProfileTreeEdge>[];
    return _measure(node, expanded, nodes, edges);
  }
}

class _ProfileTreeCard extends StatelessWidget {
  const _ProfileTreeCard({
    required this.node,
    required this.expanded,
    required this.current,
    required this.onTap,
    required this.onToggle,
  });

  final PastorHierarchyNode node;
  final bool expanded;
  final bool current;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _ProfileTreeLayout.nodeWidth,
      height: _ProfileTreeLayout.nodeHeight,
      child: Stack(
        children: [
          Material(
            color: current ? AppColors.softPrimary : AppColors.surface,
            elevation: 2,
            shadowColor: AppColors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppTokens.radius16),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppTokens.radius16),
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.space12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PersonAvatar(
                      name: node.pastoralName,
                      photoUrl:
                          node.photoUrl ??
                          DemoPastorPhotos.forPastor(
                            id: node.id,
                            name: node.pastoralName,
                          ),
                      size: current ? 56 : 48,
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Text(
                      node.pastoralName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: current ? FontWeight.w800 : FontWeight.w700,
                        fontSize: current ? 14 : 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      node.detail.isEmpty ? 'Pastor' : node.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (node.children.isNotEmpty)
            Positioned(
              top: 6,
              right: 6,
              child: Semantics(
                button: true,
                label: expanded
                    ? 'Recolher ${node.pastoralName}'
                    : 'Expandir ${node.pastoralName}',
                child: Material(
                  color: AppColors.softPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onToggle,
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: Icon(
                        expanded ? Icons.remove_rounded : Icons.add_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileTreeConnectorPainter extends CustomPainter {
  const _ProfileTreeConnectorPainter({
    required this.edges,
    required this.offset,
  });

  final List<_ProfileTreeEdge> edges;
  final Offset offset;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: .5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    for (final edge in edges) {
      final from = edge.from + offset;
      final to = edge.to + offset;
      final middleY = from.dy + (to.dy - from.dy) / 2;
      canvas.drawPath(
        Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(from.dx, middleY)
          ..lineTo(to.dx, middleY)
          ..lineTo(to.dx, to.dy),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProfileTreeConnectorPainter oldDelegate) =>
      oldDelegate.edges != edges || oldDelegate.offset != offset;
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
