import 'package:flutter/material.dart';

import '../../../../app/theme/app_text_styles.dart';

class TabPlaceholderPage extends StatelessWidget {
  const TabPlaceholderPage({
    super.key,
    required this.title,
    this.subtitle,
    this.children = const [],
  });

  final String title;
  final String? subtitle;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Semantics(
              header: true,
              child: Text(title, style: AppTextStyles.screenTitle),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: AppTextStyles.metadata),
            ],
            const SizedBox(height: 32),
            if (children.isEmpty)
              const Text(
                'Em construção',
                textAlign: TextAlign.center,
                style: AppTextStyles.metadata,
              )
            else
              ...children,
          ],
        ),
      ),
    );
  }
}
