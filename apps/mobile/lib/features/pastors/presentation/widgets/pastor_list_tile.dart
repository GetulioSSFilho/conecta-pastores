import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/contact_actions.dart';
import '../../../../core/utils/demo_pastor_photos.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/person_avatar.dart';
import '../../../network/domain/network_member.dart';
import '../../domain/pastor_status.dart';

/// Pastor em listas (Minha Rede, diretorio). Mostra apenas fatos de cuidado.
class PastorListTile extends StatelessWidget {
  const PastorListTile({
    super.key,
    required this.pastor,
    required this.onTap,
    this.onRegisterCare,
    this.showDepth = false,
  });

  final NetworkMember pastor;
  final VoidCallback onTap;
  final VoidCallback? onRegisterCare;
  final bool showDepth;

  Color get _careColor {
    final days = pastor.daysSinceLastCare;
    if (pastor.neverCared || days == null || days > 30) return AppColors.alert;
    if (days > 14) return AppColors.accent;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final status = PastorStatus.fromApi(pastor.status);
    final place = [
      pastor.churchName,
      pastor.city,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    final nextCare = pastor.nextCareAt;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space12,
        vertical: AppTokens.space12,
      ),
      child: Row(
        children: [
          PersonAvatar(
            name: pastor.pastoralName,
            photoUrl:
                pastor.photoUrl ??
                DemoPastorPhotos.forPastor(
                  id: pastor.id,
                  name: pastor.pastoralName,
                ),
            size: 46,
          ),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pastor.pastoralName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (status != PastorStatus.active) ...[
                      const SizedBox(width: AppTokens.space8),
                      Flexible(
                        child: _Pill(label: status.label, color: status.color),
                      ),
                    ],
                    if (showDepth && pastor.depth > 1) ...[
                      const SizedBox(width: AppTokens.space8),
                      Flexible(
                        child: _Pill(
                          label: 'Nível ${pastor.depth}',
                          color: AppColors.neutral,
                        ),
                      ),
                    ],
                  ],
                ),
                if (place.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedInk,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Fact(
                      icon: Icons.history_rounded,
                      text: Formatters.careSince(
                        days: pastor.daysSinceLastCare,
                        neverCared: pastor.neverCared,
                      ),
                      color: _careColor,
                    ),
                    if (nextCare != null)
                      _Fact(
                        icon: Icons.event_available_outlined,
                        text:
                            'Próximo: ${Formatters.relativeDateTime(nextCare)}',
                        color: AppColors.primary,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (pastor.whatsapp != null)
            IconButton(
              constraints: compact
                  ? const BoxConstraints.tightFor(width: 36, height: 36)
                  : null,
              padding: compact ? EdgeInsets.zero : null,
              visualDensity: compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              tooltip: 'Conversar no WhatsApp',
              onPressed: () =>
                  ContactActions.whatsApp(context, pastor.whatsapp!),
              icon: const Icon(Icons.chat_outlined, color: AppColors.success),
            ),
          if (onRegisterCare != null)
            IconButton(
              constraints: compact
                  ? const BoxConstraints.tightFor(width: 36, height: 36)
                  : null,
              padding: compact ? EdgeInsets.zero : null,
              visualDensity: compact
                  ? VisualDensity.compact
                  : VisualDensity.standard,
              tooltip: 'Registrar acompanhamento',
              onPressed: onRegisterCare,
              icon: const Icon(
                Icons.add_task_rounded,
                color: AppColors.primary,
              ),
            ),
          SizedBox(
            width: compact ? 24 : 48,
            child: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.mutedInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
