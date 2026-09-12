import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/searchable_select.dart';
import '../../../core/widgets/async_value_view.dart';
import '../data/requests_providers.dart';
import '../domain/request_models.dart';

/// Abertura de solicitacao: o pastor pede apoio a lideranca.
class RequestFormScreen extends ConsumerStatefulWidget {
  const RequestFormScreen({super.key, this.initialCategoryId});

  final String? initialCategoryId;

  @override
  ConsumerState<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends ConsumerState<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  String? _categoryId;
  var _priority = RequestPriorityKind.normal;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
  }

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = await ref
          .read(requestActionsProvider)
          .create(
            categoryId: _categoryId!,
            subject: _subject.text,
            description: _description.text,
            priority: _priority,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitação enviada. Sua liderança foi avisada.'),
        ),
      );
      context.go(id.isEmpty ? '/requests' : '/requests/$id');
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final categories = ref.watch(requestCategoriesProvider);

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
                      : context.go('/requests'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: AppTokens.space8),
                Text(
                  'Nova solicitação',
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
                      'Sobre o que você precisa falar?',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    AsyncValueView(
                      value: categories,
                      onRetry: () => ref.invalidate(requestCategoriesProvider),
                      loading: const LinearProgressIndicator(),
                      data: (list) => Wrap(
                        spacing: AppTokens.space8,
                        runSpacing: AppTokens.space8,
                        children: [
                          for (final category in list)
                            ChoiceChip(
                              label: Text(category.name),
                              selected: _categoryId == category.id,
                              onSelected: (_) =>
                                  setState(() => _categoryId = category.id),
                            ),
                        ],
                      ),
                    ),
                    if (_categoryId == null)
                      const Padding(
                        padding: EdgeInsets.only(top: AppTokens.space8),
                        child: Text(
                          'Escolha um assunto.',
                          style: TextStyle(
                            color: AppColors.mutedInk,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppTokens.space24),
                    TextFormField(
                      controller: _subject,
                      decoration: const InputDecoration(
                        labelText: 'Assunto',
                        hintText: 'Resuma em poucas palavras',
                      ),
                      validator: (v) => (v ?? '').trim().length < 3
                          ? 'Informe o assunto.'
                          : null,
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextFormField(
                      controller: _description,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Descrição',
                        hintText:
                            'Conte o que está acontecendo e como podemos ajudar.',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v ?? '').trim().length < 5
                          ? 'Descreva sua solicitação.'
                          : null,
                    ),
                    const SizedBox(height: AppTokens.space16),
                    SearchableSelectFormField<RequestPriorityKind>(
                      initialValue: _priority,
                      decoration: const InputDecoration(
                        labelText: 'Prioridade',
                      ),
                      items: [
                        for (final p in RequestPriorityKind.values)
                          DropdownMenuItem(
                            value: p,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 16,
                                  color: p.color,
                                ),
                                const SizedBox(width: 8),
                                Text(p.label),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _priority = v ?? _priority),
                    ),
                    const SizedBox(height: AppTokens.space24),
                    FilledButton(
                      onPressed: _saving || _categoryId == null
                          ? null
                          : _submit,
                      child: Text(
                        _saving ? 'Enviando...' : 'Enviar solicitação',
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
