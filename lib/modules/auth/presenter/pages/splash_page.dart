import 'package:flutter/material.dart';

import '../controllers/session_controller.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({
    super.key,
    required this.session,
    required this.onResolved,
  });

  final SessionController session;

  final ValueChanged<bool> onResolved;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    await widget.session.restore();

    if (!mounted) {
      return;
    }
    widget.onResolved(widget.session.isAuthenticated);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
