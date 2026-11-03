import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularStateX;

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/presenter/widgets/kym_banner.dart';
import '../../../../shared/presenter/widgets/kym_brand_logo.dart';
import '../../../../shared/presenter/widgets/kym_button.dart';
import '../../../../shared/presenter/widgets/kym_text_field.dart';
import '../../domain/entities/authenticated_user.dart';
import '../controllers/login_controller.dart';
import '../utils/login_validators.dart';
import '../widgets/google_logo.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onAuthenticated,
  });

  final ValueChanged<AuthenticatedUser> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  // Fornecido pela rota (escopo da página) e descartado pelo Modular.
  late final LoginController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<LoginController>();
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final user = _controller.user;
    if (_controller.status == LoginStatus.success && user != null) {
      widget.onAuthenticated(user);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await _controller.submit(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: ListenableBuilder(
                      listenable: _controller,
                      builder: (context, _) => _buildContent(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isLoading = _controller.isLoading;
    final errorMessage = _controller.errorMessage;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const KymBrandLogo(),
          const SizedBox(height: 36),
          const Text('Entrar', style: AppTextStyles.screenTitle),
          const SizedBox(height: 4),
          Text(
            'Acesse com sua conta para continuar',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (errorMessage != null) ...[
            KymBanner(message: errorMessage),
            const SizedBox(height: 16),
          ],
          AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  KymTextField(
                    label: 'E-mail',
                    controller: _emailController,
                    hintText: 'seu.email@empresa.com.br',
                    enabled: !isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    validator: LoginValidators.email,
                    onChanged: (_) => _controller.clearError(),
                    onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  ),
                  const SizedBox(height: 16),
                  KymTextField(
                    label: 'Senha',
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    hintText: 'Sua senha de acesso',
                    enabled: !isLoading,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    suffixIcon: IconButton(
                      tooltip:
                          _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    validator: LoginValidators.password,
                    onChanged: (_) => _controller.clearError(),
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: isLoading
                          ? null
                          : () => _showComingSoon(
                                'Recuperação de senha em breve.',
                              ),
                      child: const Text('Esqueci minha senha'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  KymButton(
                    label: 'Entrar',
                    onPressed: _submit,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          ),
          const _OrDivider(),
          KymButton(
            label: 'Continuar com Google',
            variant: KymButtonVariant.secondary,
            leading: const GoogleLogo(),
            onPressed: isLoading
                ? null
                : () => _showComingSoon('Login com Google em breve.'),
          ),
          const Spacer(),
          const _OfflineNote(),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text('ou', style: AppTextStyles.metadata),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.doneFg,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Funciona offline · seus dados ficam sincronizados',
              textAlign: TextAlign.center,
              style: AppTextStyles.metadata.copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
