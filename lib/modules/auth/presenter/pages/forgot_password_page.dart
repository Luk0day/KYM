import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularStateX;

import '../controllers/forgot_password_controller.dart';
import '../utils/login_validators.dart';
import '../widgets/feedback_banner.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.onBackToLogin});

  final VoidCallback onBackToLogin;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  late final ForgotPasswordController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ForgotPasswordController>();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await _controller.submit(email: _emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          widget.onBackToLogin();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Voltar ao login',
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onBackToLogin,
          ),
          title: const Text('Recuperar senha'),
        ),
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
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = _controller.isLoading;
    final errorMessage = _controller.errorMessage;
    final requestedEmail = _controller.requestedEmail;
    final succeeded = _controller.status == ForgotPasswordStatus.success;

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Esqueceu sua senha?',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Informe o e-mail da sua conta. Se ele estiver cadastrado, '
              'enviaremos um link para você redefinir a senha.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),
            if (succeeded && requestedEmail != null) ...[
              FeedbackBanner.success(
                message:
                    'Se existir uma conta com o e-mail $requestedEmail, '
                    'enviamos um link para redefinir a senha. '
                    'Confira também a caixa de spam.',
              ),
              const SizedBox(height: 16),
            ],
            if (errorMessage != null) ...[
              FeedbackBanner.error(message: errorMessage),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              validator: LoginValidators.email,
              onChanged: (_) => _controller.clearFeedback(),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
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
                    : Text(succeeded ? 'Reenviar link' : 'Enviar link'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isLoading ? null : widget.onBackToLogin,
              child: const Text('Voltar ao login'),
            ),
          ],
        ),
      ),
    );
  }
}
