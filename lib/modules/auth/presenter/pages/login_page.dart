import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularStateX;

import '../../domain/entities/authenticated_user.dart';
import '../controllers/login_controller.dart';
import '../utils/login_validators.dart';
import '../widgets/feedback_banner.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onAuthenticated,
    required this.onForgotPassword,
  });

  final ValueChanged<AuthenticatedUser> onAuthenticated;
  final VoidCallback onForgotPassword;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) => _buildForm(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = _controller.isLoading;
    final errorMessage = _controller.errorMessage;

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'KYM',
              textAlign: TextAlign.center,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entre com seu e-mail e senha',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            if (errorMessage != null) ...[
              FeedbackBanner.error(message: errorMessage),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: LoginValidators.email,
              onChanged: (_) => _controller.clearError(),
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              enabled: !isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: LoginValidators.password,
              onChanged: (_) => _controller.clearError(),
              onFieldSubmitted: (_) => _submit(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : widget.onForgotPassword,
                child: const Text('Esqueci minha senha'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: isLoading ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
