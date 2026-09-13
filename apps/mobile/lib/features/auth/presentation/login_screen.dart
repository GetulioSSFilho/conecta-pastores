import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_message.dart';
import '../../../core/responsive/breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_brand.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../application/auth_controller.dart';
import '../data/auth_repository.dart';
import 'landing_screen.dart';

const _rememberedEmailKey = 'login.rememberedEmail';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _remember = true;
  var _obscure = true;
  var _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_rememberedEmailKey);
    if (saved != null && mounted && _email.text.isEmpty) {
      setState(() => _email.text = saved);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            email: _email.text,
            password: _password.text,
            remember: _remember,
          );
      final prefs = await SharedPreferences.getInstance();
      _remember
          ? await prefs.setString(_rememberedEmailKey, _email.text.trim())
          : await prefs.remove(_rememberedEmailKey);
      // O roteador redireciona sozinho ao detectar AuthSignedIn.
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _error = failureMessage(failure));
    } catch (_) {
      if (mounted) setState(() => _error = 'Algo deu errado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final expiredNotice = auth is AuthSignedOut && auth.reason == 'expired'
        ? 'Sua sessão terminou. Entre novamente.'
        : null;

    final form = _LoginCard(
      formKey: _formKey,
      email: _email,
      password: _password,
      remember: _remember,
      obscure: _obscure,
      loading: _loading,
      error: _error ?? expiredNotice,
      onRemember: (v) => setState(() => _remember = v),
      onToggleObscure: () => setState(() => _obscure = !_obscure),
      onSubmit: _submit,
      onForgot: () => showDialog<void>(
        context: context,
        builder: (_) => ForgotPasswordDialog(initialEmail: _email.text),
      ),
      onNoAccount: () => showDialog<void>(
        context: context,
        builder: (_) => const _NoAccountDialog(),
      ),
    );

    return Scaffold(
      body: ResponsiveBuilder(
        compact: (_) => form,
        medium: (_) => Row(
          children: [
            const Expanded(child: _BrandPanel()),
            Expanded(child: form),
          ],
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: const AssetImage('assets/images/mountain_sunrise.png'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            AppColors.primary.withValues(alpha: 0.72),
            BlendMode.srcOver,
          ),
        ),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTokens.space32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBrandMark(size: 72, color: Colors.white),
              SizedBox(height: AppTokens.space16),
              Text(
                'Conecta\nPastores',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: AppTokens.space16),
              Text(
                'Mais que uma rede.\nUma missão.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.email,
    required this.password,
    required this.remember,
    required this.obscure,
    required this.loading,
    required this.error,
    required this.onRemember,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onForgot,
    required this.onNoAccount,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController email;
  final TextEditingController password;
  final bool remember;
  final bool obscure;
  final bool loading;
  final String? error;
  final ValueChanged<bool> onRemember;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onForgot;
  final VoidCallback onNoAccount;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(context.windowSize.pagePadding),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: AppCard(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: Form(
              key: formKey,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppBrandLockup(
                      markSize: 42,
                      textStyle: TextStyle(
                        color: AppColors.primary,
                        fontSize: 20,
                        height: 1.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    Text(
                      'Bem-vindo de volta',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppTokens.space4),
                    const Text('Acesse sua conta para continuar.'),
                    const SizedBox(height: AppTokens.space24),
                    if (error != null) ...[
                      _ErrorBanner(message: error!),
                      const SizedBox(height: AppTokens.space16),
                    ],
                    TextFormField(
                      key: const Key('login-email'),
                      controller: email,
                      enabled: !loading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.email,
                        AutofillHints.username,
                      ],
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) {
                        final value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Informe seu e-mail.';
                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value)) {
                          return 'E-mail inválido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextFormField(
                      key: const Key('login-password'),
                      controller: password,
                      enabled: !loading,
                      obscureText: obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => onSubmit(),
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: obscure ? 'Mostrar senha' : 'Ocultar senha',
                          onPressed: onToggleObscure,
                          icon: Icon(
                            obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Informe sua senha.' : null,
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          onTap: loading ? null : () => onRemember(!remember),
                          borderRadius: BorderRadius.circular(
                            AppTokens.radius8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: remember,
                                onChanged: loading
                                    ? null
                                    : (v) => onRemember(v ?? false),
                                visualDensity: VisualDensity.compact,
                              ),
                              const Text('Lembrar de mim'),
                              const SizedBox(width: AppTokens.space8),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: loading ? null : onForgot,
                          child: const Text('Esqueci a senha'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                    loading
                        ? const SizedBox(
                            height: 48,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : Hero(
                            tag: loginHeroTag,
                            child: AppButton(
                              label: 'Entrar',
                              onPressed: onSubmit,
                              icon: Icons.arrow_forward_rounded,
                            ),
                          ),
                    const SizedBox(height: AppTokens.space24),
                    Center(
                      child: TextButton(
                        key: const Key('contact-leadership'),
                        onPressed: onNoAccount,
                        child: const Text.rich(
                          TextSpan(
                            text: 'Ainda não tem conta? ',
                            style: TextStyle(
                              color: AppColors.mutedInk,
                              fontWeight: FontWeight.w400,
                            ),
                            children: [
                              TextSpan(
                                text: 'Fale com sua liderança',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppTokens.space12),
        decoration: BoxDecoration(
          color: AppColors.alert.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTokens.radius12),
          border: Border.all(color: AppColors.alert.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.alert,
              size: 20,
            ),
            const SizedBox(width: AppTokens.space8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recuperacao de senha real. A resposta e sempre a mesma para nao revelar
/// se o e-mail existe. Em DEV a API devolve o token para testar sem e-mail.
class ForgotPasswordDialog extends ConsumerStatefulWidget {
  const ForgotPasswordDialog({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  ConsumerState<ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);
  final _formKey = GlobalKey<FormState>();
  var _loading = false;
  var _sent = false;
  String? _devToken;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await ref
          .read(authRepositoryProvider)
          .forgotPassword(_email.text);
      setState(() {
        _sent = true;
        _devToken = token;
      });
    } on AppFailure catch (f) {
      setState(() => _error = failureMessage(f));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDev = ref.watch(appConfigProvider).isDev;
    return AlertDialog(
      title: const Text('Recuperar senha'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: _sent
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Se este e-mail estiver cadastrado, você receberá as instruções para criar uma nova senha.',
                  ),
                  if (isDev && _devToken != null) ...[
                    const SizedBox(height: AppTokens.space16),
                    const Text(
                      'Ambiente de desenvolvimento: e-mail não é enviado.',
                      style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
                    ),
                  ],
                ],
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Informe o e-mail da sua conta.'),
                    const SizedBox(height: AppTokens.space16),
                    if (_error != null) ...[
                      _ErrorBanner(message: _error!),
                      const SizedBox(height: AppTokens.space12),
                    ],
                    TextFormField(
                      controller: _email,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                      ),
                      validator: (v) => (v?.contains('@') ?? false)
                          ? null
                          : 'Informe um e-mail válido.',
                      onFieldSubmitted: (_) => _send(),
                    ),
                  ],
                ),
              ),
      ),
      actions: _sent
          ? [
              if (isDev && _devToken != null)
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(
                      Uri(
                        path: '/reset-password',
                        queryParameters: {'token': _devToken},
                      ).toString(),
                    );
                  },
                  child: const Text('Redefinir agora'),
                ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Entendi'),
              ),
            ]
          : [
              TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: _loading ? null : _send,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar'),
              ),
            ],
    );
  }
}

class _NoAccountDialog extends StatelessWidget {
  const _NoAccountDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.groups_2_outlined, color: AppColors.primary),
      title: const Text('Como obter acesso'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: const Text(
          'As contas são criadas pela sua liderança ou pela secretaria da igreja, '
          'para garantir que cada pastor veja somente as informações da sua rede.\n\n'
          'Peça ao seu supervisor para cadastrar seu e-mail. Você receberá um convite para definir sua senha.',
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}
