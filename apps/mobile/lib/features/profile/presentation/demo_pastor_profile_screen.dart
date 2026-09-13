import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../network/presentation/my_network_screen.dart';
import '../domain/pastor_profile_models.dart';
import 'pastor_profile_screen.dart';

/// Perfil local usado pelos nós do organograma de apresentação.
///
/// A árvore ainda é mockada, portanto esses perfis não consultam a API. O
/// mesmo caminho `/pastors/:id` continua sendo usado para que a experiência
/// seja idêntica quando os nós passarem a ter IDs persistidos.
class DemoPastorProfileScreen extends ConsumerStatefulWidget {
  const DemoPastorProfileScreen({
    super.key,
    this.pastorId,
    required this.name,
    required this.detail,
    this.image,
  });

  final String? pastorId;
  final String name;
  final String detail;
  final String? image;

  @override
  ConsumerState<DemoPastorProfileScreen> createState() =>
      _DemoPastorProfileScreenState();
}

class _DemoPastorProfileScreenState
    extends ConsumerState<DemoPastorProfileScreen> {
  final _scrollLock = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _scrollLock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = widget.detail.split(' · ');
    final role = parts.first;
    final organization = parts.length > 1
        ? parts.sublist(1).join(' · ')
        : 'Rede Lagoinha';
    final padding = context.windowSize.pagePadding;
    final hierarchy = widget.pastorId == null
        ? null
        : demoHierarchyFor(ref.watch(currentUserProvider), widget.pastorId!);

    return ValueListenableBuilder<bool>(
      valueListenable: _scrollLock,
      builder: (context, locked, _) => TreeScrollLockScope(
        lock: _scrollLock,
        child: SingleChildScrollView(
          physics: locked ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.fromLTRB(padding, padding, padding, padding * 2),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppTokens.radius24),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/mountain_sunrise.png'),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(
                          Color(0xD60F4C5C),
                          BlendMode.srcOver,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space16,
                      AppTokens.space8,
                      AppTokens.space16,
                      AppTokens.space24,
                    ),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            tooltip: 'Voltar ao organograma',
                            color: Colors.white,
                            onPressed: () => context.canPop()
                                ? context.pop()
                                : context.go('/network?view=tree'),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: PersonAvatar(
                            name: widget.name,
                            photoUrl: widget.image,
                            size: 112,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space12),
                        Text(
                          widget.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          organization,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  if (hierarchy != null) ...[
                    _InfoCard(
                      title: 'Organograma do pastor',
                      icon: Icons.account_tree_outlined,
                      child: PastorHierarchyOrganogram(
                        hierarchy: _toPastorHierarchy(hierarchy),
                        currentId: hierarchy.subject.id,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  _InfoCard(
                    title: 'Sobre',
                    icon: Icons.person_outline_rounded,
                    child: Text(
                      '${widget.name} atua na rede da Igreja Batista da Lagoinha, '
                      'servindo pessoas, igrejas e líderes dentro de sua área de '
                      'responsabilidade.',
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  _InfoCard(
                    title: 'Informações',
                    icon: Icons.badge_outlined,
                    child: Column(
                      children: [
                        _InfoRow(label: 'Função', value: role),
                        _InfoRow(label: 'Localidade', value: organization),
                        const _InfoRow(
                          label: 'Origem dos dados',
                          value: 'Demonstração do organograma',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

PastorHierarchy _toPastorHierarchy(DemoHierarchyContext context) =>
    PastorHierarchy(
      ancestors: [
        for (var index = 0; index < context.ancestors.length; index++)
          LeadershipLink(
            depth: index + 1,
            pastorId: context.ancestors[index].id,
            pastoralName: context.ancestors[index].name,
            photoUrl: context.ancestors[index].image,
            churchName: context.ancestors[index].detail,
          ),
      ],
      descendants: _toPastorHierarchyNode(context.subject),
    );

PastorHierarchyNode _toPastorHierarchyNode(DemoHierarchyPerson person) =>
    PastorHierarchyNode(
      id: person.id,
      pastoralName: person.name,
      photoUrl: person.image,
      ministryTitle: person.detail,
      children: [
        for (final child in person.children) _toPastorHierarchyNode(child),
      ],
    );

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTokens.radius16),
      side: const BorderSide(color: AppColors.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(AppTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: AppTokens.space8),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space12),
          child,
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppTokens.space12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
