import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularStateX;

import '../controllers/reset_password_controller.dart';
import '../utils/login_validators.dart';
import '../widgets/feedback_banner.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.onCancel,
    required this.onGoToLogin,
    required this.onRequestNewLink,
  });

  final VoidCallback onCancel;
  final VoidCallback onGoToLogin;
  final VoidCallback onRequestNewLink;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _confirmationFocus = FocusNode();

  late final ResetPasswordController _controller;

  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void initState() {
    super.initState();
    _controller = context.read<ResetPasswordController>();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    _confirmationFocus.dispose();
    super.dispose();
  }

  bool get _succeeded => _controller.status == ResetPasswordStatus.success;

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    await _controller.submit(password: _passwordController.text);
  }

  Future<void> _leave() async {
    if (_succeeded) {
      widget.onGoToLogin();
      return;
    }
    await _controller.cancel();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _leave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Voltar ao login',
            icon: const Icon(Icons.arrow_back),
            onPressed: _leave,
          ),
          title: const Text('Nova senha'),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: ListenableBuilder(
                  listenable: _controller,
                  builder: (context, _) =>
                      _succeeded ? _buildSuccess(context) : _buildForm(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String subtitle) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Defina sua nova senha',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context, 'Pronto! Sua senha foi alterada.'),
        const FeedbackBanner.success(
          message: 'Senha alterada com sucesso. Entre com a sua nova senha.',
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: widget.onGoToLogin,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Ir para o login'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final isLoading = _controller.isLoading;
    final errorMessage = _controller.errorMessage;

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(
              context,
              'Escolha uma senha com pelo menos '
              '${LoginValidators.minNewPasswordLength} caracteres. '
              'Depois, entre no app com ela.',
            ),
            if (errorMessage != null) ...[
              FeedbackBanner.error(message: errorMessage),
              const SizedBox(height: 16),
            ],
            if (_controller.isLinkInvalid) ...[
              FilledButton(
                onPressed: widget.onRequestNewLink,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Pedir novo link'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _leave,
                child: const Text('Voltar ao login'),
              ),
            ] else ...[
              TextFormField(
                controller: _passwordController,
                enabled: !isLoading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Nova senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Mostrar nova senha'
                        : 'Ocultar nova senha',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: LoginValidators.newPassword,
                onChanged: (_) => _controller.clearFeedback(),
                onFieldSubmitted: (_) => _confirmationFocus.requestFocus(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmationController,
                focusNode: _confirmationFocus,
                enabled: !isLoading,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Confirmar nova senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirmation
                        ? 'Mostrar confirmação'
                        : 'Ocultar confirmação',
                    icon: Icon(
                      _obscureConfirmation
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                    onPressed: () {
                      setState(
                        () => _obscureConfirmation = !_obscureConfirmation,
                      );
                    },
                  ),
                ),
                validator: (value) => LoginValidators.passwordConfirmation(
                  value,
                  _passwordController.text,
                ),
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
                      : const Text('Salvar nova senha'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isLoading ? null : _leave,
                child: const Text('Cancelar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
