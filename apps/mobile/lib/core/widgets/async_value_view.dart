import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';
import '../errors/failure_message.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'skeleton.dart';

/// Renderiza um AsyncValue com os tres estados padronizados.
///
/// Cada secao de tela usa seu proprio provider: uma falha isolada nao derruba a pagina.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.onRetry,
    this.hideWhenForbidden = false,
    this.forbidden,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;

  /// Secoes opcionais somem quando o servidor nega acesso (403),
  /// em vez de mostrar erro para algo que o usuario nao deveria ver.
  final bool hideWhenForbidden;

  /// O que mostrar no 403 quando a secao nao deve simplesmente desaparecer.
  final Widget? forbidden;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: data,
      loading: () => loading ?? const SkeletonCard(),
      error: (error, _) {
        // 403 nao e falha temporaria: repetir a chamada nao muda a resposta.
        if (isForbidden(error)) {
          if (forbidden != null) return forbidden!;
          return hideWhenForbidden
              ? const SizedBox.shrink()
              : const NoAccessNotice();
        }
        return InlineError(message: errorMessage(error), onRetry: onRetry);
      },
    );
  }
}

/// O servidor negou o acesso (403).
bool isForbidden(Object? error) =>
    error is AppFailure && error.kind == FailureKind.forbidden;

/// Aviso de acesso negado: explica e **nao** oferece "tentar novamente",
/// porque repetir um 403 devolve 403. Quem decide o acesso e a API.
class NoAccessNotice extends StatelessWidget {
  const NoAccessNotice({
    super.key,
    this.message = 'Você não tem acesso a esta informação.',
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.mutedInk),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(message, style: const TextStyle(color: AppColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Erro compacto dentro de um card, com acao de tentar novamente.
class InlineError extends StatelessWidget {
  const InlineError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTokens.radius16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.mutedInk),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.ink),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: const Text('Tentar novamente'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Estado vazio compacto para secoes.
class InlineEmpty extends StatelessWidget {
  const InlineEmpty({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space16),
      child: Column(
        children: [
          Icon(icon, color: AppColors.mutedInk, size: 32),
          const SizedBox(height: AppTokens.space8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.mutedInk),
          ),
          if (action != null) ...[
            const SizedBox(height: AppTokens.space8),
            action!,
          ],
        ],
      ),
    );
  }
}
