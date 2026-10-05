import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/softix-logo.png', height: 72),
          const SizedBox(height: 16),
          Text(
            AppConfig.companyName,
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 24),
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ],
      ),
    ),
  );
}
