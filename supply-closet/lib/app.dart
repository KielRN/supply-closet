import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'providers/auth_provider.dart';

class SupplyClosetApp extends StatelessWidget {
  const SupplyClosetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return MaterialApp.router(
          title: 'SupplyCloset',
          theme: SupplyClosetTheme.lightTheme,
          routerConfig: AppRouter.router(auth),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
