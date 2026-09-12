import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/churches_providers.dart';
import '../domain/church_models.dart';

/// Ficha da igreja: identificação, contato, responsável e vínculos.
class ChurchDetailScreen extends ConsumerWidget {
  const ChurchDetailScreen({super.key, required this.churchId});

  final String churchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final padding = context.windowSize.pagePadding;
    final detail = ref.watch(churchDetailProvider(churchId));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, AppTokens.space32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => context.go('/churches'),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Igrejas'),
              ),
            ),
            const SizedBox(height: AppTokens.space8),
            AsyncValueView(
              value: detail,
              onRetry: () => ref.invalidate(churchDetailProvider(churchId)),
              loading: const SkeletonCard(lines: 6),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(detail: data),
                  const SizedBox(height: AppTokens.space16),
                  _Contact(detail: data),
                  const SizedBox(height: AppTokens.space16),
                  _Pastors(churchId: churchId),
                  if (data.children.isNotEmpty) ...[
                    const SizedBox(height: AppTokens.space16),
                    _Children(children: data.children),
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

class _Header extends StatelessWidget {
  const _Header({required this.detail});

  final ChurchDetail detail;

  @override
  Widget build(BuildContext context) {
    final church = detail.church;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(AppTokens.radius12),
                ),
                child: Icon(church.type.icon, color: AppColors.primary),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      church.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${church.code} · ${church.type.label}',
                      style: const TextStyle(color: AppColors.mutedInk),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTokens.space12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: church.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  church.status.label,
                  style: TextStyle(color: church.status.color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Divider(height: AppTokens.space24),
          _Line(label: 'Local', value: church.placeText),
          if (detail.address != null)
            _Line(
              label: 'Endereço',
              value: [detail.address!, ?detail.postalCode].join(' · '),
            ),
          if (detail.parentName != null) _Line(label: 'Igreja sede', value: detail.parentName!),
          if (detail.foundedAt != null)
            _Line(label: 'Fundação', value: Formatters.date(detail.foundedAt!)),
          if (detail.membersEstimate != null)
            _Line(label: 'Membros estimados', value: '${detail.membersEstimate}'),
          _Line(label: 'Pastores vinculados', value: church.countsText),
          if (detail.hasCoordinates)
            _Line(
              label: 'Coordenadas',
              value: '${detail.latitude!.toStringAsFixed(4)}, '
                  '${detail.longitude!.toStringAsFixed(4)}',
            ),
        ],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact({required this.detail});

  final ChurchDetail detail;

  @override
  Widget build(BuildContext context) {
    final church = detail.church;
    final hasChurchContact = detail.phone != null || detail.email != null;
    final hasLead = church.leadPastorName != null;
    if (!hasChurchContact && !hasLead) return const SizedBox.shrink();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contato', style: TextStyle(fontWeight: FontWeight.w800)),
          if (hasLead) ...[
            const SizedBox(height: AppTokens.space12),
            Row(
              children: [
                PersonAvatar(name: church.leadPastorName!, size: 40),
                const SizedBox(width: AppTokens.space12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        church.leadPastorName!,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        'Pastor responsável',
                        style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (church.leadPastorId != null)
                  TextButton(
                    onPressed: () => context.go('/pastors/${church.leadPastorId}'),
                    child: const Text('Ver perfil'),
                  ),
              ],
            ),
          ],
          if (hasChurchContact) ...[
            const SizedBox(height: AppTokens.space12),
            Wrap(
              spacing: AppTokens.space8,
              runSpacing: AppTokens.space8,
              children: [
                if (detail.phone != null)
                  OutlinedButton.icon(
                    onPressed: () => ContactActions.whatsApp(context, detail.phone!),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: Text(ContactActions.formatPhone(detail.phone!)),
                  ),
                if (detail.phone != null)
                  OutlinedButton.icon(
                    onPressed: () => ContactActions.call(context, detail.phone!),
                    icon: const Icon(Icons.call_rounded, size: 18),
                    label: const Text('Ligar'),
                  ),
                if (detail.email != null)
                  OutlinedButton.icon(
                    onPressed: () => ContactActions.email(context, detail.email!),
                    icon: const Icon(Icons.mail_outline_rounded, size: 18),
                    label: Text(detail.email!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Pastors extends ConsumerWidget {
  const _Pastors({required this.churchId});

  final String churchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(churchPastorsProvider(churchId)),
      hideWhenForbidden: true,
      onRetry: () => ref.invalidate(churchPastorsProvider(churchId)),
      loading: const SkeletonCard(lines: 3),
      data: (pastors) => pastors.isEmpty
          ? const SizedBox.shrink()
          : AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pastores (${pastors.length})',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  for (final pastor in pastors)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: PersonAvatar(
                        name: pastor.pastoralName,
                        photoUrl: pastor.photoUrl,
                        size: 40,
                      ),
                      title: Text(pastor.pastoralName),
                      subtitle: Text(pastor.roleText),
                      onTap: () => context.go('/pastors/${pastor.id}'),
                    ),
                ],
              ),
            ),
    );
  }
}

class _Children extends StatelessWidget {
  const _Children({required this.children});

  final List<Church> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Congregações vinculadas (${children.length})',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: AppTokens.space8),
          for (final child in children)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(child.type.icon, color: AppColors.primary),
              title: Text(child.name),
              subtitle: Text('${child.code} · ${child.status.label}'),
              onTap: () => context.go('/churches/${child.id}'),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(color: AppColors.mutedInk)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
