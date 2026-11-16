import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

class QrScannerPlaceholderPage extends StatelessWidget {
  const QrScannerPlaceholderPage({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.darkText,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: onBack,
        ),
        title: Text(
          'Leitor de QR Code',
          style: AppTextStyles.sectionTitle.copyWith(color: AppColors.darkText),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Aponte a câmera para o QR Code\nda loja ou do equipamento',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.darkText),
            ),
          ),
        ),
      ),
    );
  }
}
