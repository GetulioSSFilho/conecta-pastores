import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/person_avatar.dart';
import '../../network/data/network_providers.dart';
import '../../network/domain/network_member.dart';
import '../data/care_providers.dart';
import '../domain/care_models.dart';

/// Registro de acompanhamento pastoral.
///
/// O nível de confidencialidade é explicado em texto: quem registra precisa
/// entender quem vai poder ler aquela anotação.
class CareFormScreen extends ConsumerStatefulWidget {
  const CareFormScreen({super.key, this.initialPastorId});

  final String? initialPastorId;

  @override
  ConsumerState<CareFormScreen> createState() => _CareFormScreenState();
}

class _CareFormScreenState extends ConsumerState<CareFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _summary = TextEditingController();
  final _notes = TextEditingController();
  final _nextAction = TextEditingController();
  final _location = TextEditingController();

  String? _pastorId;
  String? _typeId;
  var _confidentiality = CareConfidentiality.normal;
  late DateTime _occurredAt = DateTime.now();
  DateTime? _nextCareAt;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _pastorId = widget.initialPastorId;
  }

  @override
  void dispose() {
    _summary.dispose();
    _notes.dispose();
    _nextAction.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pastorId == null || _typeId == null) {
      setState(() => _error = 'Escolha o pastor e o tipo de acompanhamento.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(createCareProvider)(
        NewCare(
          pastorId: _pastorId!,
          typeId: _typeId!,
          occurredAt: _occurredAt,
          summary: _summary.text,
          notes: _notes.text,
          nextAction: _nextAction.text,
          nextCareAt: _nextCareAt,
          confidentiality: _confidentiality,
          location: _location.text,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Acompanhamento registrado.')),
      );
      context.go('/care');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final network = ref.watch(networkListProvider);
    final types = ref.watch(careTypesProvider);

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
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/care'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: AppTokens.space8),
                Text(
                  'Registrar acompanhamento',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTokens.space16),
            AppCard(
              child: Form(
                key: _formKey,
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
                    const Text(
                      'Pastor acompanhado',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    AsyncValueView(
                      value: network,
                      onRetry: () => ref.invalidate(networkListProvider),
                      loading: const LinearProgressIndicator(),
                      data: (page) => page.items.isEmpty
                          ? const Text(
                              'Nenhum pastor na sua rede.',
                              style: TextStyle(color: AppColors.mutedInk),
                            )
                          : _PastorPicker(
                              members: page.items,
                              selectedId: _pastorId,
                              onSelected: (id) =>
                                  setState(() => _pastorId = id),
                            ),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    const Text(
                      'Tipo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    AsyncValueView(
                      value: types,
                      onRetry: () => ref.invalidate(careTypesProvider),
                      loading: const LinearProgressIndicator(),
                      data: (list) => Wrap(
                        spacing: AppTokens.space8,
                        runSpacing: AppTokens.space8,
                        children: [
                          for (final type in list)
                            ChoiceChip(
                              avatar: Icon(
                                type.icon,
                                size: 18,
                                color: type.color,
                              ),
                              label: Text(type.name),
                              selected: _typeId == type.id,
                              onSelected: (_) =>
                                  setState(() => _typeId = type.id),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    _DateTimeField(
                      label: 'Quando aconteceu',
                      value: Formatters.relativeDateTime(_occurredAt),
                      onTap: () async {
                        final picked = await _pickDateTime(
                          context,
                          _occurredAt,
                        );
                        if (picked != null) {
                          setState(() => _occurredAt = picked);
                        }
                      },
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextFormField(
                      controller: _summary,
                      decoration: const InputDecoration(
                        labelText: 'Resumo',
                        hintText:
                            'Ex.: Conversa sobre rotina ministerial e família',
                      ),
                      validator: (v) => (v ?? '').trim().length < 3
                          ? 'Escreva um resumo.'
                          : null,
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextFormField(
                      controller: _notes,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Anotações',
                        hintText:
                            'O que foi conversado, pedidos de oração, encaminhamentos...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(
                        labelText: 'Local',
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    const Text(
                      'Próximo passo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    TextFormField(
                      controller: _nextAction,
                      decoration: const InputDecoration(
                        labelText: 'Próxima ação (opcional)',
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    _DateTimeField(
                      label: 'Próximo acompanhamento',
                      value: _nextCareAt == null
                          ? 'Não agendado'
                          : Formatters.relativeDateTime(_nextCareAt!),
                      onTap: () async {
                        final picked = await _pickDateTime(
                          context,
                          _nextCareAt ??
                              DateTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null) {
                          setState(() => _nextCareAt = picked);
                        }
                      },
                      onClear: _nextCareAt == null
                          ? null
                          : () => setState(() => _nextCareAt = null),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    const Text(
                      'Quem pode ler',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    for (final level in CareConfidentiality.values)
                      RadioListTile<CareConfidentiality>(
                        contentPadding: EdgeInsets.zero,
                        value: level,
                        // ignore: deprecated_member_use
                        groupValue: _confidentiality,
                        // ignore: deprecated_member_use
                        onChanged: (v) => setState(
                          () => _confidentiality = v ?? _confidentiality,
                        ),
                        title: Text(level.label),
                        subtitle: Text(
                          level.description,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: AppTokens.space24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(
                        _saving ? 'Salvando...' : 'Registrar acompanhamento',
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

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime.now().subtract(const Duration(days: 730)),
    lastDate: DateTime.now().add(const Duration(days: 730)),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) {
    return DateTime(
      date.year,
      date.month,
      date.day,
      initial.hour,
      initial.minute,
    );
  }
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

class _PastorPicker extends StatelessWidget {
  const _PastorPicker({
    required this.members,
    required this.selectedId,
    required this.onSelected,
  });

  final List<NetworkMember> members;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.space8,
      runSpacing: AppTokens.space8,
      children: [
        for (final member in members)
          ChoiceChip(
            avatar: PersonAvatar(
              name: member.pastoralName,
              photoUrl: member.photoUrl,
              size: 24,
            ),
            label: Text(member.pastoralName),
            selected: selectedId == member.id,
            onSelected: (_) => onSelected(member.id),
          ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radius12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event_outlined),
          suffixIcon: onClear == null
              ? null
              : IconButton(
                  tooltip: 'Limpar',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(value),
      ),
    );
  }
}
