import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../data/pastor_form_providers.dart';
import '../domain/new_pastor.dart';

/// Cadastro de pastor.
///
/// Apenas nome, sobrenome e país são exigidos — o resto do cadastro pode ser
/// completado depois, no Perfil 360. Quem decide se o cadastro é permitido é a
/// API (`pastor.write` + escopo); aqui o erro do servidor é mostrado como veio.
class PastorFormScreen extends ConsumerStatefulWidget {
  const PastorFormScreen({super.key});

  @override
  ConsumerState<PastorFormScreen> createState() => _PastorFormScreenState();
}

class _PastorFormScreenState extends ConsumerState<PastorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _pastoralName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _spouseName = TextEditingController();
  final _city = TextEditingController();
  final _ministryTitle = TextEditingController();

  String? _countryId;
  String? _regionId;
  String? _churchId;
  String? _ministryRoleId;
  String? _supervisorId;
  MaritalStatus? _maritalStatus;
  DateTime? _birthDate;
  DateTime? _joinedAt;
  DateTime? _ordainedAt;
  var _createUserAccount = false;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _firstName,
      _lastName,
      _pastoralName,
      _email,
      _phone,
      _whatsapp,
      _spouseName,
      _city,
      _ministryTitle,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_countryId == null) {
      setState(() => _error = 'Escolha o país do pastor.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(createPastorProvider)(
        NewPastor(
          firstName: _firstName.text,
          lastName: _lastName.text,
          countryId: _countryId!,
          pastoralName: _pastoralName.text,
          email: _email.text,
          phone: _phone.text,
          whatsapp: _whatsapp.text,
          birthDate: _birthDate,
          maritalStatus: _maritalStatus,
          spouseName: _spouseName.text,
          regionId: _regionId,
          city: _city.text,
          churchId: _churchId,
          ministryRoleId: _ministryRoleId,
          ministryTitle: _ministryTitle.text,
          joinedAt: _joinedAt,
          ordainedAt: _ordainedAt,
          supervisorId: _supervisorId,
          createUserAccount: _createUserAccount,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pastor cadastrado.')));
      context.go(id.isEmpty ? '/pastors' : '/pastors/$id');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final countries = ref.watch(pastorCountryOptionsProvider).value ?? const [];
    final regions = ref.watch(regionOptionsProvider(_countryId)).value ?? const [];
    final churches = ref.watch(churchOptionsProvider(_countryId)).value ?? const [];
    final roles = ref.watch(ministryRoleOptionsProvider).value ?? const [];
    final supervisors = ref.watch(supervisorOptionsProvider).value ?? const [];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: EdgeInsets.fromLTRB(padding, padding, padding, AppTokens.space32),
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Voltar',
                  onPressed: () => context.canPop() ? context.pop() : context.go('/pastors'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: AppTokens.space8),
                Text(
                  'Cadastrar pastor',
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
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
                          borderRadius: BorderRadius.circular(AppTokens.radius12),
                        ),
                        child: Text(_error!),
                      ),
                      const SizedBox(height: AppTokens.space16),
                    ],
                    const _SectionTitle('Identificação'),
                    _TwoColumns(
                      first: TextFormField(
                        controller: _firstName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome'),
                        validator: (v) =>
                            (v ?? '').trim().length < 2 ? 'Informe o nome.' : null,
                      ),
                      second: TextFormField(
                        controller: _lastName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Sobrenome'),
                        validator: (v) =>
                            (v ?? '').trim().length < 2 ? 'Informe o sobrenome.' : null,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextFormField(
                      controller: _pastoralName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Como é conhecido (opcional)',
                        hintText: 'Ex.: Pr. João Silva',
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: _DateField(
                        label: 'Nascimento',
                        value: _birthDate,
                        onPick: (date) => setState(() => _birthDate = date),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now(),
                      ),
                      second: DropdownButtonFormField<MaritalStatus>(
                        initialValue: _maritalStatus,
                        decoration: const InputDecoration(labelText: 'Estado civil'),
                        items: [
                          for (final status in MaritalStatus.values)
                            DropdownMenuItem(value: status, child: Text(status.label)),
                        ],
                        onChanged: (value) => setState(() => _maritalStatus = value),
                      ),
                    ),
                    if (_maritalStatus == MaritalStatus.married) ...[
                      const SizedBox(height: AppTokens.space16),
                      TextFormField(
                        controller: _spouseName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Nome do cônjuge'),
                      ),
                    ],
                    const Divider(height: AppTokens.space32),
                    const _SectionTitle('Contato'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail (opcional)',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        if (value.isEmpty) return null;
                        return value.contains('@') && value.contains('.')
                            ? null
                            : 'E-mail inválido.';
                      },
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Telefone',
                          prefixIcon: Icon(Icons.call_outlined),
                        ),
                      ),
                      second: TextFormField(
                        controller: _whatsapp,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'WhatsApp',
                          prefixIcon: Icon(Icons.chat_outlined),
                        ),
                      ),
                    ),
                    const Divider(height: AppTokens.space32),
                    const _SectionTitle('Onde atua'),
                    DropdownButtonFormField<String>(
                      initialValue: _countryId,
                      decoration: const InputDecoration(labelText: 'País'),
                      items: [
                        for (final country in countries)
                          DropdownMenuItem(value: country.id, child: Text(country.label)),
                      ],
                      onChanged: (value) => setState(() {
                        _countryId = value;
                        // Região e igreja dependem do país escolhido.
                        _regionId = null;
                        _churchId = null;
                      }),
                      validator: (value) => value == null ? 'Escolha o país.' : null,
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: DropdownButtonFormField<String>(
                        initialValue: _regionId,
                        decoration: InputDecoration(
                          labelText: 'Região',
                          helperText: _countryId == null ? 'Escolha o país primeiro' : null,
                        ),
                        items: [
                          for (final region in regions)
                            DropdownMenuItem(value: region.id, child: Text(region.label)),
                        ],
                        onChanged: regions.isEmpty
                            ? null
                            : (value) => setState(() => _regionId = value),
                      ),
                      second: TextFormField(
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Cidade'),
                      ),
                    ),
                    const Divider(height: AppTokens.space32),
                    const _SectionTitle('Ministério'),
                    DropdownButtonFormField<String>(
                      initialValue: _churchId,
                      decoration: const InputDecoration(labelText: 'Igreja'),
                      items: [
                        for (final church in churches)
                          DropdownMenuItem(
                            value: church.id,
                            child: Text(
                              church.detail == null
                                  ? church.label
                                  : '${church.label} · ${church.detail}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: churches.isEmpty
                          ? null
                          : (value) => setState(() => _churchId = value),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: DropdownButtonFormField<String>(
                        initialValue: _ministryRoleId,
                        decoration: const InputDecoration(labelText: 'Cargo ministerial'),
                        items: [
                          for (final role in roles)
                            DropdownMenuItem(value: role.id, child: Text(role.label)),
                        ],
                        onChanged: roles.isEmpty
                            ? null
                            : (value) => setState(() => _ministryRoleId = value),
                      ),
                      second: TextFormField(
                        controller: _ministryTitle,
                        decoration: const InputDecoration(
                          labelText: 'Título usado',
                          hintText: 'Ex.: Pastor de jovens',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: _DateField(
                        label: 'Entrada no ministério',
                        value: _joinedAt,
                        onPick: (date) => setState(() => _joinedAt = date),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      ),
                      second: _DateField(
                        label: 'Ordenação',
                        value: _ordainedAt,
                        onPick: (date) => setState(() => _ordainedAt = date),
                        firstDate: DateTime(1950),
                        lastDate: DateTime.now(),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    DropdownButtonFormField<String>(
                      initialValue: _supervisorId,
                      decoration: const InputDecoration(
                        labelText: 'Supervisor',
                        helperText: 'Define a posição na hierarquia pastoral',
                      ),
                      items: [
                        for (final supervisor in supervisors)
                          DropdownMenuItem(
                            value: supervisor.id,
                            child: Text(supervisor.label, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: supervisors.isEmpty
                          ? null
                          : (value) => setState(() => _supervisorId = value),
                    ),
                    const Divider(height: AppTokens.space32),
                    const _SectionTitle('Acesso à plataforma'),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _createUserAccount,
                      onChanged: (value) => setState(() => _createUserAccount = value),
                      title: const Text('Criar conta de acesso'),
                      subtitle: const Text(
                        'A API gera uma senha temporária e exige a troca no primeiro acesso. '
                        'Requer e-mail preenchido.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving ? 'Salvando...' : 'Cadastrar pastor'),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.space12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

/// Dois campos lado a lado no desktop, empilhados no celular.
class _TwoColumns extends StatelessWidget {
  const _TwoColumns({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [first, const SizedBox(height: AppTokens.space16), second],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: first),
            const SizedBox(width: AppTokens.space16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.firstDate,
    required this.lastDate,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime(lastDate.year - 30),
          firstDate: firstDate,
          lastDate: lastDate,
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.event_outlined),
        ),
        child: Text(
          value == null ? 'Não informado' : Formatters.date(value!),
          style: TextStyle(color: value == null ? AppColors.mutedInk : AppColors.ink),
        ),
      ),
    );
  }
}
