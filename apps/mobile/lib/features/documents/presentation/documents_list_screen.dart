import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/contact_actions.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/paged_list_view.dart';
import '../data/documents_providers.dart';
import '../domain/document_models.dart';

/// Acervo de documentos pastorais.
///
/// O arquivo nunca e servido por URL publica: o download usa URL assinada de
/// curta duracao, emitida pela API apos checar a permissao.
class DocumentsListScreen extends ConsumerStatefulWidget {
  const DocumentsListScreen({super.key});

  @override
  ConsumerState<DocumentsListScreen> createState() =>
      _DocumentsListScreenState();
}

class _DocumentsListScreenState extends ConsumerState<DocumentsListScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String? _openingId;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref
          .read(documentQueryProvider.notifier)
          .update((q) => q.copyWith(search: value.trim()));
    });
  }

  Future<void> _open(PastoralDocument document) async {
    setState(() => _openingId = document.id);
    try {
      final url = await ref.read(documentDownloadUrlProvider)(document.id);
      if (url != null && mounted) await ContactActions.openLink(context, url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _openingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = context.windowSize.pagePadding;
    final query = ref.watch(documentQueryProvider);
    final notifier = ref.read(documentQueryProvider.notifier);
    final total = ref.watch(documentsProvider).value?.total;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Documentos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    total == null
                        ? 'Certificados, credenciais e registros'
                        : '$total ${total == 1 ? 'documento' : 'documentos'}',
                    style: const TextStyle(color: AppColors.mutedInk),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                padding,
                AppTokens.space16,
                padding,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _search,
                    onChanged: _onSearch,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Buscar documento',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          avatar: const Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: AppColors.accent,
                          ),
                          label: const Text('Vencendo em 60 dias'),
                          selected: query.expiringInDays != null,
                          onSelected: (v) => notifier.update(
                            (q) =>
                                q.copyWith(expiringInDays: () => v ? 60 : null),
                          ),
                        ),
                        const SizedBox(width: AppTokens.space12),
                        ChoiceChip(
                          label: const Text('Todas as categorias'),
                          selected: query.category == null,
                          onSelected: (_) => notifier.update(
                            (q) => q.copyWith(category: () => null),
                          ),
                        ),
                        for (final category in DocumentCategory.values) ...[
                          const SizedBox(width: AppTokens.space8),
                          ChoiceChip(
                            avatar: Icon(category.icon, size: 18),
                            label: Text(category.label),
                            selected: query.category == category,
                            onSelected: (_) => notifier.update(
                              (q) => q.copyWith(category: () => category),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PagedListView(
                value: ref.watch(documentsProvider),
                padding: EdgeInsets.fromLTRB(
                  padding,
                  AppTokens.space16,
                  padding,
                  AppTokens.space32,
                ),
                onLoadMore: () =>
                    ref.read(documentsProvider.notifier).loadMore(),
                onRetry: () => ref.invalidate(documentsProvider),
                onRefresh: () async => ref.invalidate(documentsProvider),
                empty: InlineEmpty(
                  icon: query.hasFilters
                      ? Icons.filter_alt_off_outlined
                      : Icons.folder_off_outlined,
                  message: query.hasFilters
                      ? 'Nenhum documento com esses filtros.'
                      : 'Nenhum documento disponível para você.',
                  action: query.hasFilters
                      ? TextButton(
                          onPressed: () {
                            _search.clear();
                            notifier.set(const DocumentQuery());
                          },
                          child: const Text('Limpar filtros'),
                        )
                      : null,
                ),
                itemBuilder: (context, document) => _DocumentCard(
                  document: document,
                  opening: _openingId == document.id,
                  onOpen: () => _open(document),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.document,
    required this.opening,
    required this.onOpen,
  });

  final PastoralDocument document;
  final bool opening;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: opening ? null : onOpen,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(AppTokens.radius12),
            ),
            child: Icon(document.fileIcon, color: AppColors.primary),
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
                        document.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (document.confidentiality != 'NORMAL') ...[
                      const SizedBox(width: AppTokens.space8),
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 14,
                        color: AppColors.accent,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    document.category.label,
                    ?document.pastoralName,
                    if (document.issuedAt != null)
                      'Emitido em ${Formatters.date(document.issuedAt!)}',
                    document.sizeText,
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
          const SizedBox(width: AppTokens.space8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                document.validityText,
                style: TextStyle(
                  color: document.validity.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              opening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
