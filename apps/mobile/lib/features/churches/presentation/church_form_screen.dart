import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/searchable_select.dart';
import '../../pastors/data/pastor_form_providers.dart';
import '../data/church_form_providers.dart';
import '../domain/church_models.dart';

/// Cadastro de igreja.
///
/// Exige código, nome, país e cidade; o restante (contato, coordenadas, sede)
/// é opcional. A permissão `church.write` e o escopo são checados pela API.
class ChurchFormScreen extends ConsumerStatefulWidget {
  const ChurchFormScreen({super.key});

  @override
  ConsumerState<ChurchFormScreen> createState() => _ChurchFormScreenState();
}

class _ChurchFormScreenState extends ConsumerState<ChurchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _address = TextEditingController();
  final _postalCode = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _members = TextEditingController();

  String? _countryId;
  String? _regionId;
  String? _parentId;
  var _type = ChurchType.main;
  var _status = ChurchStatus.active;
  DateTime? _foundedAt;
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _code,
      _name,
      _city,
      _address,
      _postalCode,
      _phone,
      _email,
      _latitude,
      _longitude,
      _members,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_countryId == null) {
      setState(() => _error = 'Escolha o país da igreja.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref.read(createChurchProvider)(
        NewChurch(
          code: _code.text,
          name: _name.text,
          countryId: _countryId!,
          city: _city.text,
          type: _type.apiValue,
          status: _status.apiValue,
          regionId: _regionId,
          parentId: _type == ChurchType.main ? null : _parentId,
          address: _address.text,
          postalCode: _postalCode.text,
          phone: _phone.text,
          email: _email.text,
          latitude: double.tryParse(_latitude.text.trim().replaceAll(',', '.')),
          longitude: double.tryParse(
            _longitude.text.trim().replaceAll(',', '.'),
          ),
          foundedAt: _foundedAt,
          membersEstimate: int.tryParse(_members.text.trim()),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Igreja cadastrada.')));
      context.go(id.isEmpty ? '/churches' : '/churches/$id');
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
    final regions =
        ref.watch(regionOptionsProvider(_countryId)).value ?? const [];
    final parents =
        ref.watch(parentChurchOptionsProvider(_countryId)).value ?? const [];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
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
                      : context.go('/churches'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: AppTokens.space8),
                Text(
                  'Cadastrar igreja',
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
                    const _Title('Identificação'),
                    _TwoColumns(
                      first: TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome da igreja',
                        ),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Informe o nome.'
                            : null,
                      ),
                      second: TextFormField(
                        controller: _code,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Código',
                          hintText: 'Ex.: BR-031',
                        ),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Informe o código.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    const Text(
                      'Tipo',
                      style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppTokens.space8,
                      runSpacing: AppTokens.space8,
                      children: [
                        for (final type in ChurchType.values)
                          ChoiceChip(
                            avatar: Icon(type.icon, size: 18),
                            label: Text(type.label),
                            selected: _type == type,
                            onSelected: (_) => setState(() => _type = type),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                    const Text(
                      'Situação',
                      style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: AppTokens.space8,
                      runSpacing: AppTokens.space8,
                      children: [
                        for (final status in ChurchStatus.values)
                          ChoiceChip(
                            label: Text(status.label),
                            selected: _status == status,
                            onSelected: (_) => setState(() => _status = status),
                          ),
                      ],
                    ),
                    const Divider(height: AppTokens.space32),
                    const _Title('Onde fica'),
                    SearchableSelectFormField<String>(
                      initialValue: _countryId,
                      decoration: const InputDecoration(labelText: 'País'),
                      items: [
                        for (final country in countries)
                          DropdownMenuItem(
                            value: country.id,
                            child: Text(country.label),
                          ),
                      ],
                      onChanged: (value) => setState(() {
                        _countryId = value;
                        _regionId = null;
                        _parentId = null;
                      }),
                      validator: (value) =>
                          value == null ? 'Escolha o país.' : null,
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: SearchableSelectFormField<String>(
                        initialValue: _regionId,
                        decoration: InputDecoration(
                          labelText: 'Região',
                          helperText: _countryId == null
                              ? 'Escolha o país primeiro'
                              : null,
                        ),
                        items: [
                          for (final region in regions)
                            DropdownMenuItem(
                              value: region.id,
                              child: Text(region.label),
                            ),
                        ],
                        onChanged: regions.isEmpty
                            ? null
                            : (value) => setState(() => _regionId = value),
                      ),
                      second: TextFormField(
                        controller: _city,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Cidade'),
                        validator: (v) => (v ?? '').trim().length < 2
                            ? 'Informe a cidade.'
                            : null,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: TextFormField(
                        controller: _address,
                        decoration: const InputDecoration(
                          labelText: 'Endereço',
                        ),
                      ),
                      second: TextFormField(
                        controller: _postalCode,
                        decoration: const InputDecoration(
                          labelText: 'CEP / código postal',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: TextFormField(
                        controller: _latitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Latitude',
                          helperText: 'Necessária para aparecer no mapa',
                        ),
                      ),
                      second: TextFormField(
                        controller: _longitude,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Longitude',
                        ),
                      ),
                    ),
                    if (_type != ChurchType.main) ...[
                      const SizedBox(height: AppTokens.space16),
                      SearchableSelectFormField<String>(
                        initialValue: _parentId,
                        decoration: const InputDecoration(
                          labelText: 'Igreja sede',
                          helperText:
                              'A qual sede este campus/congregação pertence',
                        ),
                        items: [
                          for (final parent in parents)
                            DropdownMenuItem(
                              value: parent.id,
                              child: Text(
                                parent.label,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: parents.isEmpty
                            ? null
                            : (value) => setState(() => _parentId = value),
                      ),
                    ],
                    const Divider(height: AppTokens.space32),
                    const _Title('Contato e histórico'),
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
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'E-mail',
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
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _TwoColumns(
                      first: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _foundedAt ?? DateTime(2000),
                            firstDate: DateTime(1800),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _foundedAt = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fundação',
                            suffixIcon: Icon(Icons.event_outlined),
                          ),
                          child: Text(
                            _foundedAt == null
                                ? 'Não informada'
                                : Formatters.date(_foundedAt!),
                            style: TextStyle(
                              color: _foundedAt == null
                                  ? AppColors.mutedInk
                                  : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                      second: TextFormField(
                        controller: _members,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Membros estimados',
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Text(_saving ? 'Salvando...' : 'Cadastrar igreja'),
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

class _Title extends StatelessWidget {
  const _Title(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppTokens.space12),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
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
            children: [
              first,
              const SizedBox(height: AppTokens.space16),
              second,
            ],
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
