import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../network/data/network_providers.dart';
import '../data/schedule_providers.dart';
import '../domain/calendar_event.dart';

/// Cria um compromisso e convida pastores da rede.
class EventFormScreen extends ConsumerStatefulWidget {
  const EventFormScreen({super.key, this.initialPastorId});

  final String? initialPastorId;

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _meetingUrl = TextEditingController();

  var _type = CalendarEventType.careMeeting;
  var _isOnline = false;
  var _saving = false;
  String? _error;
  late DateTime _day = DateTime.now().add(const Duration(days: 1));
  var _start = const TimeOfDay(hour: 19, minute: 0);
  var _end = const TimeOfDay(hour: 20, minute: 0);
  final _selectedPastors = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.initialPastorId != null) {
      _selectedPastors.add(widget.initialPastorId!);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _meetingUrl.dispose();
    super.dispose();
  }

  DateTime get _startsAt =>
      DateTime(_day.year, _day.month, _day.day, _start.hour, _start.minute);
  DateTime get _endsAt =>
      DateTime(_day.year, _day.month, _day.day, _end.hour, _end.minute);

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_endsAt.isAfter(_startsAt)) {
      setState(() => _error = 'O término precisa ser depois do início.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(createEventProvider)(
        NewEvent(
          type: _type,
          title: _title.text,
          description: _description.text,
          startsAt: _startsAt,
          endsAt: _endsAt,
          isOnline: _isOnline,
          location: _location.text,
          meetingUrl: _meetingUrl.text,
          pastorIds: _selectedPastors.toList(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Compromisso criado.')));
      context.go('/calendar');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final network = ref.watch(networkListProvider).value;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
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
                IconButton(
                  tooltip: 'Voltar',
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go('/calendar'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: AppTokens.space8),
                Text(
                  'Novo compromisso',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),
            Form(
              key: _formKey,
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppTokens.space12),
                        decoration: BoxDecoration(
                          color: AppColors.alert.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radius12,
                          ),
                        ),
                        child: Text(_error!),
                      ),
                      const SizedBox(height: AppTokens.space16),
                    ],
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ex.: Acompanhamento com Pr. João',
                      ),
                      validator: (v) => (v ?? '').trim().length < 3
                          ? 'Informe um título.'
                          : null,
                    ),
                    const SizedBox(height: AppTokens.space16),
                    DropdownButtonFormField<CalendarEventType>(
                      initialValue: _type,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: [
                        for (final t in CalendarEventType.values)
                          DropdownMenuItem(
                            value: t,
                            child: Row(
                              children: [
                                Icon(t.icon, size: 18, color: t.color),
                                const SizedBox(width: 8),
                                Text(t.label),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => _type = v ?? _type),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    Row(
                      children: [
                        Expanded(
                          child: _PickerField(
                            label: 'Data',
                            value: Formatters.date(_day),
                            icon: Icons.calendar_month_outlined,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _day,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 730),
                                ),
                              );
                              if (picked != null) setState(() => _day = picked);
                            },
                          ),
                        ),
                        const SizedBox(width: AppTokens.space12),
                        Expanded(
                          child: _PickerField(
                            label: 'Início',
                            value: _start.format(context),
                            icon: Icons.schedule_rounded,
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _start,
                              );
                              if (picked != null) {
                                setState(() {
                                  _start = picked;
                                  if (_end.hour * 60 + _end.minute <=
                                      picked.hour * 60 + picked.minute) {
                                    _end = TimeOfDay(
                                      hour: (picked.hour + 1) % 24,
                                      minute: picked.minute,
                                    );
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppTokens.space12),
                        Expanded(
                          child: _PickerField(
                            label: 'Término',
                            value: _end.format(context),
                            icon: Icons.schedule_outlined,
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _end,
                              );
                              if (picked != null) setState(() => _end = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Encontro online'),
                      subtitle: const Text(
                        'Informe o link da reunião (Meet, Teams, Zoom...)',
                      ),
                      value: _isOnline,
                      onChanged: (v) => setState(() => _isOnline = v),
                    ),
                    if (_isOnline)
                      TextFormField(
                        controller: _meetingUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Link da reunião',
                          prefixIcon: Icon(Icons.videocam_outlined),
                        ),
                        validator: (v) =>
                            _isOnline && !(v ?? '').startsWith('http')
                            ? 'Informe um link válido.'
                            : null,
                      )
                    else
                      TextFormField(
                        controller: _location,
                        decoration: const InputDecoration(
                          labelText: 'Local',
                          prefixIcon: Icon(Icons.place_outlined),
                        ),
                      ),
                    const SizedBox(height: AppTokens.space16),
                    TextFormField(
                      controller: _description,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    const Text(
                      'Participantes da sua rede',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    if (network == null || network.items.isEmpty)
                      const Text(
                        'Nenhum pastor disponível na sua rede.',
                        style: TextStyle(color: AppColors.mutedInk),
                      )
                    else
                      Wrap(
                        spacing: AppTokens.space8,
                        runSpacing: AppTokens.space8,
                        children: [
                          for (final member in network.items)
                            FilterChip(
                              label: Text(member.pastoralName),
                              selected: _selectedPastors.contains(member.id),
                              onSelected: (v) => setState(() {
                                v
                                    ? _selectedPastors.add(member.id)
                                    : _selectedPastors.remove(member.id);
                              }),
                            ),
                        ],
                      ),
                    const SizedBox(height: AppTokens.space24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(
                        _saving ? 'Salvando...' : 'Criar compromisso',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        child: Text(value),
      ),
    );
  }
}
