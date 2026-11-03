import 'package:flutter/material.dart';

enum FeedbackKind { error, success }

class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner.error({super.key, required this.message})
    : kind = FeedbackKind.error;

  const FeedbackBanner.success({super.key, required this.message})
    : kind = FeedbackKind.success;

  final String message;
  final FeedbackKind kind;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isError = kind == FeedbackKind.error;
    final background = isError
        ? colors.errorContainer
        : colors.primaryContainer;
    final foreground = isError
        ? colors.onErrorContainer
        : colors.onPrimaryContainer;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: foreground,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}
