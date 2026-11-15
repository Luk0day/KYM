import 'package:flutter/material.dart';

import '../../../auth/presenter/controllers/session_controller.dart';

// Tela provisória até a home real existir.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.onSignedOut,
    this.onOpenStores,
  });

  final SessionController session;
  final VoidCallback onSignedOut;
  final VoidCallback? onOpenStores;

  Future<void> _signOut() async {
    await session.signOut();
    onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final user = session.user;

        return Scaffold(
          appBar: AppBar(
            title: const Text('KYM'),
            actions: [
              IconButton(
                tooltip: 'Sair',
                icon: const Icon(Icons.logout),
                onPressed: _signOut,
              ),
            ],
          ),
          body: Center(
            child: user == null
                ? const SizedBox.shrink()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Olá, ${user.displayName ?? user.email}\n'
                        '(${user.role.name})',
                        textAlign: TextAlign.center,
                      ),
                      if (onOpenStores != null)
                        TextButton(
                          onPressed: onOpenStores,
                          child: const Text('Ver lojas'),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
