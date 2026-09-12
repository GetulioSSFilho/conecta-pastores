import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

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
import '../data/schedule_providers.dart';
import '../domain/calendar_event.dart';

/// Agenda: calendario do mes + compromissos do dia + proximos.
///
/// Horarios vem em UTC da API e sao exibidos no horario local do dispositivo.
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = context.windowSize;
    final padding = size.pagePadding;
    final canCreate =
        ref.watch(currentUserProvider)?.can('event.write') ?? false;

    final calendar = _MonthCalendar(
      onRefresh: () => ref.invalidate(monthEventsProvider),
    );
    final dayList = _DayEvents();
    final upcoming = _UpcomingEvents();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            padding,
            padding,
            padding,
            AppTokens.space32,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agenda',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Seus compromissos e da sua rede',
                        style: TextStyle(color: AppColors.mutedInk),
                      ),
                    ],
                  ),
                ),
                if (canCreate)
                  FilledButton.icon(
                    onPressed: () => context.go('/calendar/new'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Novo compromisso'),
                  ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),
            if (size.isAtLeastMedium)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: calendar),
                  const SizedBox(width: AppTokens.space16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        dayList,
                        const SizedBox(height: AppTokens.space16),
                        upcoming,
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              calendar,
              const SizedBox(height: AppTokens.space16),
              dayList,
              const SizedBox(height: AppTokens.space16),
              upcoming,
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthCalendar extends ConsumerWidget {
  const _MonthCalendar({required this.onRefresh});

  final VoidCallback onRefresh;

  static const _weekDays = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(visibleMonthProvider);
    final selected = ref.watch(selectedDayProvider);
    final events = ref.watch(monthEventsProvider);
    final monthLabel = DateFormat("MMMM 'de' y", 'pt_BR').format(month);

    // Segunda-feira como primeiro dia da grade.
    final firstWeekday = (DateTime(month.year, month.month).weekday + 6) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mês anterior',
                onPressed: () =>
                    ref.read(visibleMonthProvider.notifier).previous(),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  '${monthLabel[0].toUpperCase()}${monthLabel.substring(1)}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: 'Próximo mês',
                onPressed: () => ref.read(visibleMonthProvider.notifier).next(),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                ref.read(visibleMonthProvider.notifier).today();
                ref.read(selectedDayProvider.notifier).select(DateTime.now());
              },
              child: const Text('Hoje'),
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Row(
            children: [
              for (final d in _weekDays)
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: events,
            onRetry: onRefresh,
            loading: const Skeleton(height: 240),
            data: (list) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday) return const SizedBox.shrink();
                final day = DateTime(
                  month.year,
                  month.month,
                  index - firstWeekday + 1,
                );
                final dayEvents = list.where((e) => e.occursOn(day)).toList();
                final isSelected =
                    day.year == selected.year &&
                    day.month == selected.month &&
                    day.day == selected.day;
                final isToday =
                    day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;

                return InkWell(
                  borderRadius: BorderRadius.circular(AppTokens.radius12),
                  onTap: () =>
                      ref.read(selectedDayProvider.notifier).select(day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : (isToday ? AppColors.softPrimary : null),
                      borderRadius: BorderRadius.circular(AppTokens.radius12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontWeight: isSelected || isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final event in dayEvents.take(3))
                              Container(
                                width: 5,
                                height: 5,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : event.type.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DayEvents extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final events = ref.watch(monthEventsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            Formatters.fullDate(day),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: events,
            onRetry: () => ref.invalidate(monthEventsProvider),
            loading: const _EventSkeleton(),
            data: (list) {
              final dayEvents = list.where((e) => e.occursOn(day)).toList()
                ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
              if (dayEvents.isEmpty) {
                return const InlineEmpty(
                  icon: Icons.event_available_outlined,
                  message: 'Nenhum compromisso neste dia.',
                );
              }
              return Column(
                children: [for (final e in dayEvents) _EventTile(event: e)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpcomingEvents extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Próximos compromissos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppTokens.space8),
          AsyncValueView(
            value: ref.watch(upcomingEventsProvider),
            onRetry: () => ref.invalidate(upcomingEventsProvider),
            loading: const _EventSkeleton(),
            data: (list) => list.isEmpty
                ? const InlineEmpty(
                    icon: Icons.event_busy_outlined,
                    message: 'Nada agendado por enquanto.',
                  )
                : Column(
                    children: [
                      for (final e in list.take(6))
                        _EventTile(event: e, showDate: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, this.showDate = false});

  final CalendarEvent event;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _EventSheet(event: event),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTokens.space8,
          horizontal: AppTokens.space4,
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                color: event.type.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      event.type.label,
                      showDate
                          ? Formatters.relativeDateTime(event.startsAt)
                          : Formatters.time(event.startsAt),
                      ?event.place,
                    ].join(' · '),
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
            if (event.meetingUrl != null)
              const Icon(
                Icons.videocam_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.mutedInk),
          ],
        ),
      ),
    );
  }
}

class _EventSheet extends StatelessWidget {
  const _EventSheet({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
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
                Icon(event.type.icon, color: event.type.color),
                const SizedBox(width: AppTokens.space8),
                Text(
                  event.type.label,
                  style: TextStyle(
                    color: event.type.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space8),
            Text(event.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTokens.space8),
            Text(
              '${Formatters.relativeDateTime(event.startsAt)} — ${Formatters.time(event.endsAt)}',
              style: const TextStyle(color: AppColors.mutedInk),
            ),
            if (event.place != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: AppColors.mutedInk,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        event.place!,
                        style: const TextStyle(color: AppColors.mutedInk),
                      ),
                    ),
                  ],
                ),
              ),
            if (event.description != null) ...[
              const SizedBox(height: AppTokens.space16),
              Text(event.description!, style: const TextStyle(height: 1.5)),
            ],
            if (event.participants.isNotEmpty) ...[
              const SizedBox(height: AppTokens.space16),
              const Text(
                'Participantes',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppTokens.space8),
              Wrap(
                spacing: AppTokens.space8,
                runSpacing: AppTokens.space8,
                children: [
                  for (final p in event.participants)
                    Chip(
                      avatar: PersonAvatar(name: p.name, size: 24),
                      label: Text(p.name),
                      side: const BorderSide(color: AppColors.border),
                      backgroundColor: AppColors.surface,
                    ),
                ],
              ),
            ],
            if (event.meetingUrl != null) ...[
              const SizedBox(height: AppTokens.space24),
              FilledButton.icon(
                onPressed: () =>
                    ContactActions.openLink(context, event.meetingUrl!),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('Entrar na reunião'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventSkeleton extends StatelessWidget {
  const _EventSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTokens.space8),
            child: Row(
              children: [
                Skeleton(width: 4, height: 40),
                SizedBox(width: AppTokens.space12),
                Expanded(child: Skeleton(height: 12)),
              ],
            ),
          ),
      ],
    );
  }
}
