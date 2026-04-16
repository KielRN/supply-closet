import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Logo / wordmark
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      SupplyClosetColors.tealLight,
                      SupplyClosetColors.tealDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: SupplyClosetColors.teal.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'SupplyCloset',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: SupplyClosetColors.charcoal,
                  letterSpacing: -1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Never hunt for supplies again.',
                style: TextStyle(
                  fontSize: 17,
                  color: SupplyClosetColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),

              // Three teaser features
              _Feature(
                icon: Icons.center_focus_strong_rounded,
                title: 'Find with your camera',
                subtitle: 'Point and tap. We show you exactly where it is.',
              ),
              const SizedBox(height: 16),
              _Feature(
                icon: Icons.bolt_rounded,
                title: 'Earn XP every shift',
                subtitle: 'Tag supplies, climb levels, unlock badges.',
              ),
              const SizedBox(height: 16),
              _Feature(
                icon: Icons.groups_rounded,
                title: 'Built by nurses, for nurses',
                subtitle: 'Your unit gets smarter with every tag.',
              ),
              const Spacer(),

              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  return Column(
                    children: [
                      if (auth.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            auth.error!,
                            style: const TextStyle(
                                color: SupplyClosetColors.error, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: auth.isLoading
                            ? null
                            : () => auth.signInWithGoogle(),
                        icon: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.login_rounded),
                        label:
                            Text(auth.isLoading ? 'Signing in...' : 'Continue with Google'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No PHI is collected. Your data stays yours.',
                        style: TextStyle(
                          fontSize: 12,
                          color: SupplyClosetColors.textTertiary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: SupplyClosetColors.teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: SupplyClosetColors.teal),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: SupplyClosetColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
