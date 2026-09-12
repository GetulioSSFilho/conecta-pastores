import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_message.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/app_card.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';

/// Mesma regra do backend (ChangePasswordDto): >= 10, maiuscula, minuscula e numero.
String? validateNewPassword(String? value) {
  final v = value ?? '';
  if (v.length < 10) return 'Use pelo menos 10 caracteres.';
  if (!RegExp('[a-z]').hasMatch(v)) return 'Inclua uma letra minúscula.';
  if (!RegExp('[A-Z]').hasMatch(v)) return 'Inclua uma letra maiúscula.';
  if (!RegExp(r'\d').hasMatch(v)) return 'Inclua um número.';
  return null;
}

/// Troca de senha do usuario logado. Obrigatoria quando `mustChangePassword`.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Senha alterada. Suas outras sessões foram encerradas.',
          ),
        ),
      );
      await ref.read(authControllerProvider.notifier).retryRestore();
      if (mounted) context.go('/settings');
    } on AppFailure catch (f) {
      setState(
        () => _error = f.code == 'INVALID_CREDENTIALS'
            ? 'Senha atual incorreta.'
            : failureMessage(f),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final forced = ref.watch(currentUserProvider)?.mustChangePassword ?? false;
    return _PasswordLayout(
      title: 'Alterar senha',
      subtitle: forced
          ? 'Por segurança, defina uma nova senha antes de continuar.'
          : 'Ao alterar, as sessões em outros dispositivos serão encerradas.',
      error: _error,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PasswordField(
              controller: _current,
              label: 'Senha atual',
              validator: (v) =>
                  (v ?? '').isEmpty ? 'Informe a senha atual.' : null,
            ),
            const SizedBox(height: AppTokens.space16),
            _PasswordField(
              controller: _next,
              label: 'Nova senha',
              validator: validateNewPassword,
            ),
            const SizedBox(height: AppTokens.space16),
            _PasswordField(
              controller: _confirm,
              label: 'Confirmar nova senha',
              validator: (v) =>
                  v == _next.text ? null : 'As senhas não conferem.',
              onSubmit: _submit,
            ),
            const SizedBox(height: AppTokens.space8),
            const Text(
              'Mínimo de 10 caracteres, com letra maiúscula, minúscula e número.',
              style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
            ),
            const SizedBox(height: AppTokens.space24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Salvando...' : 'Salvar nova senha'),
            ),
            if (!forced)
              TextButton(
                onPressed: () => context.go('/settings'),
                child: const Text('Cancelar'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Redefinicao via token recebido por e-mail (rota publica).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  var _loading = false;
  var _done = false;
  String? _error;

  @override
  void dispose() {
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPassword(token: widget.token!, newPassword: _next.text);
      setState(() => _done = true);
    } on AppFailure catch (f) {
      setState(
        () => _error = f.code == 'TOKEN_INVALID'
            ? 'Este link de recuperação é inválido ou expirou. Solicite um novo.'
            : failureMessage(f),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    return Scaffold(
      body: _PasswordLayout(
        title: 'Criar nova senha',
        subtitle: _done
            ? 'Senha redefinida com sucesso.'
            : 'Escolha uma senha forte para sua conta.',
        error: token == null || token.isEmpty
            ? 'Link de recuperação incompleto.'
            : _error,
        showBrand: true,
        child: _done || token == null || token.isEmpty
            ? FilledButton(
                onPressed: () => context.go('/login'),
                child: const Text('Ir para o login'),
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PasswordField(
                      controller: _next,
                      label: 'Nova senha',
                      validator: validateNewPassword,
                    ),
                    const SizedBox(height: AppTokens.space16),
                    _PasswordField(
                      controller: _confirm,
                      label: 'Confirmar nova senha',
                      validator: (v) =>
                          v == _next.text ? null : 'As senhas não conferem.',
                      onSubmit: _submit,
                    ),
                    const SizedBox(height: AppTokens.space24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: Text(_loading ? 'Salvando...' : 'Redefinir senha'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Voltar ao login'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PasswordLayout extends StatelessWidget {
  const _PasswordLayout({
    required this.title,
    required this.subtitle,
    required this.child,
    this.error,
    this.showBrand = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? error;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: AppCard(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showBrand) ...[
                  const AppBrandLockup(markSize: 36),
                  const SizedBox(height: AppTokens.space16),
                ],
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppTokens.space4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.mutedInk),
                ),
                const SizedBox(height: AppTokens.space24),
                if (error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppTokens.space12),
                    decoration: BoxDecoration(
                      color: AppColors.alert.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTokens.radius12),
                    ),
                    child: Text(
                      error!,
                      style: const TextStyle(color: AppColors.ink),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.validator,
    this.onSubmit,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final VoidCallback? onSubmit;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  var _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmit == null
          ? null
          : (_) => widget.onSubmit!(),
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
