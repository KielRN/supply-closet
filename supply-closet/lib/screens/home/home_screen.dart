import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/gamification_provider.dart';
import '../../widgets/celebration_overlay.dart';

/// Root shell with bottom navigation.
/// Wraps every authenticated screen with the celebration overlay system.
class HomeScreen extends StatelessWidget {
  final Widget child;
  const HomeScreen({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/find')) return 1;
    if (location.startsWith('/tag')) return 2;
    if (location.startsWith('/leaderboard')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/find');
        break;
      case 2:
        context.go('/tag');
        break;
      case 3:
        context.go('/leaderboard');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: child,
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex(context),
            onTap: (i) => _onTap(context, i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.checklist_rounded),
                label: 'Procedures',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.center_focus_strong_rounded),
                label: 'Find',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_rounded, size: 32),
                label: 'Tag',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_rounded),
                label: 'Ranks',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
        // Global celebration overlay
        Consumer<GamificationProvider>(
          builder: (context, gamification, _) {
            final event = gamification.nextCelebration;
            if (event == null) return const SizedBox.shrink();
            return CelebrationOverlay(
              key: ValueKey(event.hashCode),
              event: event,
              onDismiss: gamification.dismissCurrentCelebration,
            );
          },
        ),
      ],
    );
  }
}
